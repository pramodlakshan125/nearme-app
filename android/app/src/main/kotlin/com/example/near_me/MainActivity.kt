package com.example.near_me

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.ParcelUuid
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val channelName = "nearme/ble_advertising"
    private var activeAdvertiseCallback: AdvertiseCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAndroidSdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "startAdvertising" -> {
                        val serviceUuid = call.argument<String>("serviceUuid")
                        if (serviceUuid == null) {
                            result.error("invalid_token", "Missing service UUID", null)
                        } else {
                            startAdvertising(serviceUuid, result)
                        }
                    }
                    "stopAdvertising" -> {
                        stopAdvertising()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startAdvertising(serviceUuid: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            checkSelfPermission(Manifest.permission.BLUETOOTH_ADVERTISE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error("permission_denied", "Bluetooth advertising permission is required", null)
            return
        }

        val manager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter: BluetoothAdapter = manager.adapter
        val advertiser = adapter.bluetoothLeAdvertiser
        if (!adapter.isEnabled || advertiser == null) {
            result.error("bluetooth_unavailable", "Bluetooth advertising is unavailable", null)
            return
        }

        stopAdvertising()
        val callback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                result.success(null)
            }

            override fun onStartFailure(errorCode: Int) {
                activeAdvertiseCallback = null
                result.error("advertising_failed", "BLE advertising failed: $errorCode", null)
            }
        }
        activeAdvertiseCallback = callback

        try {
            val service = ParcelUuid(UUID.fromString(serviceUuid))
            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
                .setConnectable(false)
                .build()
            val data = AdvertiseData.Builder()
                .addServiceUuid(service)
                .setIncludeDeviceName(false)
                .build()
            advertiser.startAdvertising(settings, data, callback)
        } catch (error: IllegalArgumentException) {
            activeAdvertiseCallback = null
            result.error("invalid_token", error.message, null)
        }
    }

    private fun stopAdvertising() {
        val callback = activeAdvertiseCallback ?: return
        val manager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        manager.adapter.bluetoothLeAdvertiser?.stopAdvertising(callback)
        activeAdvertiseCallback = null
    }
}
