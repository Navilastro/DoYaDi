package com.doyadi.doyadi

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "Navilastro.DoYaDi/volume_keys"
    private var channel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "check_overlay_permission" -> {
                        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Settings.canDrawOverlays(this)
                        } else {
                            true
                        }
                        result.success(granted)
                    }
                    "request_overlay_permission" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                                !Settings.canDrawOverlays(this)
                            ) {
                                try {
                                    val intent = Intent(
                                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                        Uri.parse("package:$packageName")
                                    )
                                    startActivity(intent)
                                } catch (e1: Exception) {
                                    val fallback = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                                    startActivity(fallback)
                                }
                            }
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    "start_mod8_bg" -> {
                        applyMod8Config(call.arguments as? Map<*, *>)
                        Mod8BackgroundService.isArmedForMod8 = true
                        // Uygulama ön plandayken servisi bir kez ön plan servisi olarak başlat.
                        val svc = Mod8BackgroundService.instance
                        if (svc != null) {
                            svc.applyConfigUpdate()
                        } else {
                            sendServiceAction(Mod8BackgroundService.ACTION_START_ARMED)
                        }
                        result.success(true)
                    }
                    "update_mod8_bg" -> {
                        applyMod8Config(call.arguments as? Map<*, *>)
                        if (Mod8BackgroundService.isArmedForMod8) {
                            val svc = Mod8BackgroundService.instance
                            if (svc != null) {
                                svc.applyConfigUpdate()
                            } else if (isActivityVisible) {
                                sendServiceAction(Mod8BackgroundService.ACTION_START_ARMED)
                            }
                        }
                        result.success(true)
                    }
                    "enter_mod8_bg" -> {
                        applyMod8Config(call.arguments as? Map<*, *>)
                        if (Mod8BackgroundService.isArmedForMod8) {
                            enterMod8Background()
                        }
                        result.success(true)
                    }
                    "exit_mod8_bg" -> {
                        Mod8BackgroundService.instance?.requestExitBackground()
                        result.success(true)
                    }
                    "stop_mod8_bg" -> {
                        Mod8BackgroundService.isArmedForMod8 = false
                        Mod8BackgroundService.isInBackgroundMode = false
                        stopMod8BgService()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        Mod8BackgroundService.onRecalibrateCallback = { baseP, baseR ->
            mainHandler.post {
                channel?.invokeMethod(
                    "mod8_bg_recalibrated",
                    mapOf("basePitch" to baseP, "baseRoll" to baseR)
                )
            }
        }

        Mod8BackgroundService.onBluetoothPacketCallback = { bytes ->
            mainHandler.post {
                val intList = bytes.map { it.toInt() and 0xFF }
                channel?.invokeMethod("mod8_bg_packet", intList)
            }
        }

        Mod8BackgroundService.onOverlayClosedByUserCallback = {
            mainHandler.post {
                channel?.invokeMethod("mod8_bg_closed", null)
            }
        }
    }

    private fun applyMod8Config(args: Map<*, *>?) {
        if (args == null) return
        (args["ip"] as? String)?.let { Mod8BackgroundService.targetIp = it }
        (args["steerSens"] as? Number)?.let { Mod8BackgroundService.steerSens = it.toDouble() }
        (args["gasBrakeSens"] as? Number)?.let { Mod8BackgroundService.gasBrakeSens = it.toDouble() }
        (args["steeringAngle"] as? Number)?.let { Mod8BackgroundService.steeringAngleDeg = it.toDouble() }
        (args["steeringAxis"] as? Number)?.let { Mod8BackgroundService.steeringAxis = it.toInt() }
        (args["showGearButtons"] as? Boolean)?.let { Mod8BackgroundService.showGearButtons = it }
        (args["overlayStyle"] as? Number)?.let { Mod8BackgroundService.overlayStyle = it.toInt() }
        (args["basePitch"] as? Number)?.let {
            Mod8BackgroundService.basePitch = it.toDouble()
            Mod8BackgroundService.hasCustomBase = true
        }
        (args["baseRoll"] as? Number)?.let {
            Mod8BackgroundService.baseRoll = it.toDouble()
            Mod8BackgroundService.hasCustomBase = true
        }
        (args["cruiseLocked"] as? Boolean)?.let { Mod8BackgroundService.cruiseLocked = it }
        (args["cruiseGasValue"] as? Number)?.let { Mod8BackgroundService.cruiseGasValue = it.toDouble() }
    }

    private fun sendServiceAction(action: String) {
        try {
            val intent = Intent(this, Mod8BackgroundService::class.java).apply {
                this.action = action
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            android.util.Log.e("DoYaDiMod8Bg", "Servis başlatılamadı ($action): $e")
        }
    }

    private fun stopMod8BgService() {
        try {
            val intent = Intent(this, Mod8BackgroundService::class.java)
            stopService(intent)
        } catch (_: Exception) {
        }
    }

    private var isActivityVisible = false

    /**
     * Arka plana geçişte servis zaten çalışıyorsa doğrudan çağrılır.
     * (Android 12+ arka plandan startForegroundService çağrısını engelleyebildiği için
     * intent yalnızca servis henüz yoksa son çare olarak denenir.)
     */
    private fun enterMod8Background() {
        val svc = Mod8BackgroundService.instance
        if (svc != null) {
            svc.requestEnterBackground()
        } else {
            sendServiceAction(Mod8BackgroundService.ACTION_ENTER_BACKGROUND)
        }
    }

    override fun onStart() {
        super.onStart()
        isActivityVisible = true
    }

    override fun onResume() {
        super.onResume()
        isActivityVisible = true
        if (Mod8BackgroundService.isArmedForMod8) {
            Mod8BackgroundService.instance?.requestExitBackground()
        }
    }

    override fun onStop() {
        isActivityVisible = false
        if (Mod8BackgroundService.isArmedForMod8) {
            enterMod8Background()
        }
        super.onStop()
    }

    override fun onDestroy() {
        Mod8BackgroundService.onRecalibrateCallback = null
        Mod8BackgroundService.onBluetoothPacketCallback = null
        Mod8BackgroundService.onOverlayClosedByUserCallback = null
        stopMod8BgService()
        super.onDestroy()
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        return when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> {
                channel?.invokeMethod("key_event", "volume_up")
                true // consume event — ses değişmez
            }
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                channel?.invokeMethod("key_event", "volume_down")
                true // consume event — ses değişmez
            }
            else -> super.onKeyDown(keyCode, event)
        }
    }
}
