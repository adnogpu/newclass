package com.adnogpu.newclass

import android.app.AlarmManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.ArrayDeque

class MainActivity : FlutterActivity() {
    private val permissionIntents = ArrayDeque<Intent>()
    private val permissionRequestCode = 2001
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
                                applicationContext,
                                bytes,
                                onSuccess = { result.success(it) },
                                onError = { error ->
                                    result.error("ocr_failed", error.message, null)
                                },
                            )
                        }
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("bad_args", "missing path", null)
                        } else {
                            installApk(path, result)
                        }
                    }
                    "appVersion" -> {
                        try {
                            val info = packageManager.getPackageInfo(packageName, 0)
                            val code = if (Build.VERSION.SDK_INT >= 28) {
                                info.longVersionCode.toInt()
                            } else {
                                @Suppress("DEPRECATION")
                                info.versionCode
                            }
                            result.success(
                                mapOf(
                                    "code" to code,
                                    "name" to (info.versionName ?: ""),
                                ),
                            )
                        } catch (error: Exception) {
                            result.error("version_failed", error.message, null)
                        }
                    }
                    "openAppSettings" -> {
                        try {
                            val intent = Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName"),
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("settings_failed", error.message, null)
                        }
                    }
                    "requestStartupPermissions" -> {
                        requestStartupPermissions()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestStartupPermissions() {
        permissionIntents.clear()
        val powerManager = getSystemService(PowerManager::class.java)
        if (powerManager != null &&
            !powerManager.isIgnoringBatteryOptimizations(packageName)
        ) {
            permissionIntents.add(
                Intent(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                    Uri.parse("package:$packageName"),
                ),
            )
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(AlarmManager::class.java)
            if (alarmManager != null && !alarmManager.canScheduleExactAlarms()) {
                permissionIntents.add(
                    Intent(
                        Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                        Uri.parse("package:$packageName"),
                    ),
                )
            }
        }
        launchNextPermission()
    }

    private fun launchNextPermission() {
        val intent = permissionIntents.pollFirst() ?: return
        try {
            startActivityForResult(intent, permissionRequestCode)
        } catch (_: Exception) {
            launchNextPermission()
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == permissionRequestCode) {
            launchNextPermission()
        }
    }

    private fun installApk(path: String, result: MethodChannel.Result) {
        try {
            val file = File(path).canonicalFile
            val cacheRoot = cacheDir.canonicalFile
            if (!file.path.startsWith(cacheRoot.path + File.separator)) {
                throw IllegalArgumentException("invalid path")
            }
            if (!file.exists()) {
                throw IllegalArgumentException("file missing")
            }
            val uri = FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                file,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_ACTIVITY_NEW_TASK,
                )
            }
            startActivity(intent)
            result.success(true)
        } catch (error: Exception) {
            result.error("install_failed", error.message, null)
        }
    }

    // The OCR session is process-scoped. Closing it from onDestroy can race an
    // in-flight inference when the activity is recreated; let the process own it.
}
