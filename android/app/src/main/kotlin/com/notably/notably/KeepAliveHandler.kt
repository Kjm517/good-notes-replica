package com.notably.notably

import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class KeepAliveHandler(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    init {
        MethodChannel(messenger, "notably/keep_alive").setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val intent = Intent(context, SyncForegroundService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                result.success(null)
            }
            "stop" -> {
                context.stopService(Intent(context, SyncForegroundService::class.java))
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
