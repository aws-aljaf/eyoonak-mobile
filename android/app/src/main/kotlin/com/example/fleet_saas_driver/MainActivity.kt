package com.example.fleet_saas_driver
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.eyoonak.app/device_settings")
            .setMethodCallHandler { call, result ->
                if (call.method != "openBatterySettings") { result.notImplemented(); return@setMethodCallHandler }
                try {
                    val direct = Intent("android.settings.APP_BATTERY_SETTINGS", Uri.parse("package:$packageName"))
                    if (direct.resolveActivity(packageManager) != null) startActivity(direct)
                    else startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                    result.success(true)
                } catch (e: Exception) { result.success(false) }
            }
    }
}
