package com.doyadi.doyadi

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "Navilastro.DoYaDi/volume_keys"
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
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
