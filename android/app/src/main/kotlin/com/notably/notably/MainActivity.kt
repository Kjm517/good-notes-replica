package com.notably.notably

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PdfTextHandler.register(this, flutterEngine.dartExecutor.binaryMessenger)
        KeepAliveHandler(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
