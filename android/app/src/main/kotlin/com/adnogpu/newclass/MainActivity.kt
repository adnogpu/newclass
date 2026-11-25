package com.adnogpu.newclass

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "newclass/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ocrCaptcha" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null) {
                            result.error("bad_args", "missing bytes", null)
                        } else {
                            CaptchaOcrEngine.recognize(
                                bytes,
                                onSuccess = { result.success(it) },
                                onError = { error ->
                                    result.error("ocr_failed", error.message, null)
                                },
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        CaptchaOcrEngine.close()
        super.onDestroy()
    }
}
