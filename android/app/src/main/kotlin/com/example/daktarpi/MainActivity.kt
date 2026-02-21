package com.example.daktarpi

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val integrityChannel = "com.daktarpi/device_integrity"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            integrityChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDeviceCompromised" -> result.success(isDeviceRooted())
                else -> result.notImplemented()
            }
        }
    }

    private fun isDeviceRooted(): Boolean {
        val buildTags = Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) {
            return true
        }

        val knownRootPaths =
            arrayOf(
                "/system/app/Superuser.apk",
                "/sbin/su",
                "/system/bin/su",
                "/system/xbin/su",
                "/data/local/xbin/su",
                "/data/local/bin/su",
                "/system/sd/xbin/su",
                "/system/bin/failsafe/su",
                "/data/local/su",
            )
        if (knownRootPaths.any { File(it).exists() }) {
            return true
        }

        return try {
            val process = Runtime.getRuntime().exec(arrayOf("/system/xbin/which", "su"))
            process.inputStream.bufferedReader().use { it.readLine() != null }
        } catch (_: Exception) {
            false
        }
    }
}
