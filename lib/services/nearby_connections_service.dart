import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/user_model.dart';
import 'app_notification_service.dart';
import 'local_profile_store.dart';

class NearbyConnectionsService extends ChangeNotifier {
  NearbyConnectionsService(this._store, this._notifications);

  static const _serviceId = 'com.nearme.offline';
  final LocalProfileStore _store;
  final AppNotificationService _notifications;
  final Nearby _nearby = Nearby();
  final Map<String, UserModel> _peers = {};
  final Map<String, String> _endpointNames = {};
  final Map<String, IncomingRequest> _incomingRequests = {};
  final Set<String> _connecting = {};
  final Set<String> _connected = {};
  final Set<String> _pendingOutgoing = {};
  final Set<String> _requestPayloadSent = {};
  late UserModel _profile;
  bool _scanning = false;
  bool? _notificationPermissionGranted;
  String? _error;

  bool get isScanning => _scanning;
  bool? get notificationPermissionGranted => _notificationPermissionGranted;
  String? get error => _error;
  List<UserModel> get peers => List.unmodifiable(_peers.values);
  List<IncomingRequest> get incomingRequests =>
      List.unmodifiable(_incomingRequests.values);
  List<UserModel> get acceptedContacts => _store.readContacts();
  bool isRequestPending(String endpointId) =>
      _pendingOutgoing.contains(endpointId);

  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return false;

    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    final permissions = <Permission>[
      if (sdk <= 30) Permission.locationWhenInUse,
      if (sdk <= 30) Permission.bluetooth,
      if (sdk >= 31) ...[
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
      ],
      if (sdk >= 32) Permission.nearbyWifiDevices,
    ];
    final statuses = await permissions.request();
    return statuses.values.every((status) => status.isGranted);
  }

  Future<void> start(UserModel profile) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Nearby Connections is currently supported on Android only.',
      );
    }
    if (_scanning) return;
    _profile = profile;
    _error = null;
    final granted = await requestPermissions();
    if (!granted) {
      throw StateError('Nearby-device permissions were not granted.');
    }
    _notificationPermissionGranted = await _notifications.requestPermission();
    try {
      final name = _endpointName(profile);
      final results = await Future.wait([
        if (profile.isVisible)
          _nearby.startAdvertising(
            name,
            Strategy.P2P_CLUSTER,
            onConnectionInitiated: _onConnectionInitiated,
            onConnectionResult: _onConnectionResult,
            onDisconnected: _onDisconnected,
            serviceId: _serviceId,
          ),
        _nearby.startDiscovery(
          name,
          Strategy.P2P_CLUSTER,
          onEndpointFound: _onEndpointFound,
          onEndpointLost: _onEndpointLost,
          serviceId: _serviceId,
        ),
      ]);
      if (results.any((started) => !started)) {
        await _nearby.stopAdvertising();
        await _nearby.stopDiscovery();
        throw StateError(
          'Nearby Connections could not start advertising or discovery.',
        );
      }
      _scanning = true;
      notifyListeners();
    } catch (_) {
      await _nearby.stopAdvertising();
      await _nearby.stopDiscovery();
      rethrow;
    }
  }

  Future<void> stop() async {
    await _nearby.stopAdvertising();
    await _nearby.stopDiscovery();
    _scanning = false;
    _peers.clear();
    _endpointNames.clear();
    _connecting.clear();
    _connected.clear();
    _pendingOutgoing.clear();
    _requestPayloadSent.clear();
    _incomingRequests.clear();
    notifyListeners();
  }

  Future<void> updateProfile(UserModel profile) async {
    final wasScanning = _scanning;
    if (wasScanning) await stop();
    _profile = profile;
    if (wasScanning) await start(profile);
  }

  Future<void> sendConnectionRequest(String endpointId) async {
    if (_store.readContacts().any((contact) => contact.uid == endpointId)) {
      return;
    }
    if (_pendingOutgoing.contains(endpointId)) return;
    _pendingOutgoing.add(endpointId);
    notifyListeners();

    if (_connected.contains(endpointId)) {
      await _sendPendingRequest(endpointId);
      return;
    }

    final endpointName = _endpointNames[endpointId];
    if (endpointName == null) {
      _pendingOutgoing.remove(endpointId);
      notifyListeners();
      throw StateError('This nearby device is no longer available. Try again.');
    }
    if (_shouldInitiateConnection(endpointName)) {
      await _requestConnection(endpointId, endpointName);
    }
  }

  Future<void> _sendPendingRequest(String endpointId) async {
    if (!_pendingOutgoing.contains(endpointId) ||
        _requestPayloadSent.contains(endpointId) ||
        !_connected.contains(endpointId)) {
      return;
    }
    _requestPayloadSent.add(endpointId);
    try {
      await _send(endpointId, {'type': 'request'});
    } catch (_) {
      _requestPayloadSent.remove(endpointId);
      _pendingOutgoing.remove(endpointId);
      notifyListeners();
      rethrow;
    }
    notifyListeners();
  }

  Future<void> acceptRequest(String endpointId) async {
    final request = _incomingRequests[endpointId];
    if (request == null) {
      throw StateError('This request is no longer available.');
    }
    await _send(endpointId, {
      'type': 'accepted',
      'facebookUrl': _profile.facebookUrl,
      'phoneNumber': _profile.sharePhone ? _profile.phoneNumber : '',
    });
    _incomingRequests.remove(endpointId);
    await _notifications.dismissConnectionRequest(endpointId);
    await _store.saveContact(request.toUser().copyWith(facebookUrl: ''));
    notifyListeners();
  }

  Future<void> rejectRequest(String endpointId) async {
    await _send(endpointId, {'type': 'rejected'});
    _incomingRequests.remove(endpointId);
    await _notifications.dismissConnectionRequest(endpointId);
    notifyListeners();
  }

  Future<void> _onEndpointFound(
    String endpointId,
    String endpointName,
    String serviceId,
  ) async {
    if (serviceId != _serviceId) return;
    _endpointNames[endpointId] = endpointName;
    final displayName = _displayNameFromEndpoint(endpointName);
    _peers.putIfAbsent(
      endpointId,
      () => UserModel(uid: endpointId, displayName: displayName),
    );
    notifyListeners();
    if (_connected.contains(endpointId) ||
        _connecting.contains(endpointId) ||
        !_shouldInitiateConnection(endpointName)) {
      return;
    }
    await _requestConnection(endpointId, endpointName);
  }

  String _displayNameFromEndpoint(String endpointName) {
    final separator = endpointName.indexOf('|');
    return separator < 0 ? endpointName : endpointName.substring(separator + 1);
  }

  String? _uidFromEndpoint(String endpointName) {
    final separator = endpointName.indexOf('|');
    return separator < 0 ? null : endpointName.substring(0, separator);
  }

  bool _shouldInitiateConnection(String endpointName) {
    if (!_profile.isVisible) return true;
    final remoteUid = _uidFromEndpoint(endpointName);
    if (remoteUid == null || remoteUid.isEmpty) return true;
    return _profile.uid.compareTo(remoteUid) < 0;
  }

  Future<void> _requestConnection(
    String endpointId,
    String endpointName,
  ) async {
    if (_connected.contains(endpointId) || !_connecting.add(endpointId)) return;
    try {
      final started = await _nearby.requestConnection(
        _endpointName(_profile),
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      if (!started) {
        _connecting.remove(endpointId);
        _pendingOutgoing.remove(endpointId);
        _error =
            'Could not connect to ${_displayNameFromEndpoint(endpointName)}.';
        notifyListeners();
      }
    } catch (error) {
      _connecting.remove(endpointId);
      _pendingOutgoing.remove(endpointId);
      _error =
          'Connection to ${_displayNameFromEndpoint(endpointName)} failed: $error';
      notifyListeners();
    }
  }

  String _endpointName(UserModel profile) {
    final uid = profile.uid.length > 16
        ? profile.uid.substring(0, 16)
        : profile.uid;
    final name = StringBuffer();
    var nameBytes = 0;
    for (final rune in profile.displayName.runes) {
      final character = String.fromCharCode(rune);
      final characterBytes = utf8.encode(character).length;
      if (nameBytes + characterBytes > 15) break;
      name.write(character);
      nameBytes += characterBytes;
    }
    return '$uid|$name';
  }

  void _onEndpointLost(String? endpointId) {
    if (endpointId == null || _connected.contains(endpointId)) return;
    _peers.remove(endpointId);
    _endpointNames.remove(endpointId);
    _connecting.remove(endpointId);
    _pendingOutgoing.remove(endpointId);
    _requestPayloadSent.remove(endpointId);
    notifyListeners();
  }

  Future<void> _onConnectionInitiated(
    String endpointId,
    ConnectionInfo info,
  ) async {
    try {
      await _nearby.acceptConnection(
        endpointId,
        onPayLoadRecieved: _onPayloadReceived,
      );
    } catch (error) {
      _error = 'Could not establish a nearby connection: $error';
      notifyListeners();
    }
  }

  Future<void> _onConnectionResult(String endpointId, Status status) async {
    _connecting.remove(endpointId);
    if (status != Status.CONNECTED) {
      _peers.remove(endpointId);
      _pendingOutgoing.remove(endpointId);
      _requestPayloadSent.remove(endpointId);
      _error = 'The nearby connection was rejected or failed.';
      notifyListeners();
      return;
    }
    _connected.add(endpointId);
    try {
      if (_profile.isVisible) {
        await _send(endpointId, await _presenceMessage());
      }
      await _sendPendingRequest(endpointId);
    } catch (error) {
      _error = 'Could not send nearby connection data: $error';
    }
    notifyListeners();
  }

  void _onDisconnected(String endpointId) {
    _connected.remove(endpointId);
    _connecting.remove(endpointId);
    _peers.remove(endpointId);
    _endpointNames.remove(endpointId);
    _pendingOutgoing.remove(endpointId);
    _requestPayloadSent.remove(endpointId);
    _incomingRequests.remove(endpointId);
    notifyListeners();
  }

  Future<Map<String, dynamic>> _presenceMessage() async {
    var photo = '';
    if (_profile.photoPath.isNotEmpty) {
      final bytes = await File(_profile.photoPath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        final thumbnail = img.copyResize(decoded, width: 128, height: 128);
        photo = base64Encode(img.encodeJpg(thumbnail, quality: 45));
      }
    }
    return {'type': 'profile', 'name': _profile.displayName, 'photo': photo};
  }

  Future<void> _onPayloadReceived(String endpointId, Payload payload) async {
    final bytes = payload.bytes;
    if (bytes == null) return;
    try {
      final message = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      switch (message['type']) {
        case 'profile':
          _peers[endpointId] = UserModel.fromPresence(message, endpointId);
          break;
        case 'request':
          if (_store.readContacts().any(
            (contact) => contact.uid == endpointId,
          )) {
            break;
          }
          if (_incomingRequests.containsKey(endpointId)) break;
          final peer = _peers[endpointId];
          _incomingRequests[endpointId] = IncomingRequest(
            endpointId: endpointId,
            displayName: peer?.displayName ?? 'Nearby user',
            photoData: peer?.photoData ?? '',
          );
          await _notifications.showConnectionRequest(
            endpointId: endpointId,
            displayName: peer?.displayName ?? 'Nearby user',
          );
          break;
        case 'accepted':
          _pendingOutgoing.remove(endpointId);
          _requestPayloadSent.remove(endpointId);
          final peer = _peers[endpointId];
          if (peer != null) {
            final contact = peer.copyWith(
              facebookUrl: message['facebookUrl'] as String? ?? '',
              phoneNumber: message['phoneNumber'] as String? ?? '',
            );
            await _store.saveContact(contact);
            await _send(endpointId, {
              'type': 'profile_reveal',
              'facebookUrl': _profile.facebookUrl,
              'phoneNumber': _profile.sharePhone ? _profile.phoneNumber : '',
            });
          }
          break;
        case 'profile_reveal':
          final peer = _peers[endpointId];
          final contact = _store.readContacts().where(
            (item) => item.uid == endpointId,
          );
          if (peer != null && contact.isNotEmpty) {
            await _store.saveContact(
              peer.copyWith(
                facebookUrl: message['facebookUrl'] as String? ?? '',
                phoneNumber: message['phoneNumber'] as String? ?? '',
              ),
            );
          }
          break;
        case 'rejected':
          _pendingOutgoing.remove(endpointId);
          _requestPayloadSent.remove(endpointId);
          break;
      }
      notifyListeners();
    } on FormatException catch (error) {
      _error = 'Received an invalid nearby message: $error';
      notifyListeners();
    } on TypeError catch (error) {
      _error = 'Received an invalid nearby message: $error';
      notifyListeners();
    } catch (error) {
      _error = 'Could not process the nearby message: $error';
      notifyListeners();
    }
  }

  Future<void> _send(String endpointId, Map<String, dynamic> message) async {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(message)));
    await _nearby.sendBytesPayload(endpointId, bytes);
  }
}
