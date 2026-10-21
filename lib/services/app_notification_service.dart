import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AppNotificationService extends WidgetsBindingObserver {
  static const _channelId = 'connection_requests_v1';
  static const _channelName = 'Connection requests';
  static const _channelDescription =
      'Alerts when someone nearby sends you a connection request.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _isForeground = true;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    _isForeground =
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused;
    if (!Platform.isAndroid) return;

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await androidPlugin?.requestNotificationsPermission() ?? true;
  }

  Future<void> showConnectionRequest({
    required String endpointId,
    required String displayName,
  }) async {
    if (!Platform.isAndroid || !_initialized || _isForeground) return;

    await _plugin.show(
      id: endpointId.hashCode & 0x7fffffff,
      title: 'New connection request',
      body: '$displayName wants to connect with you. Tap to review.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.social,
        ),
      ),
      payload: endpointId,
    );
  }

  Future<void> dismissConnectionRequest(String endpointId) async {
    if (!_initialized) return;
    await _plugin.cancel(id: endpointId.hashCode & 0x7fffffff);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
