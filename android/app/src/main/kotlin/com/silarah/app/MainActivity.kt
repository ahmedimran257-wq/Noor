package com.silarah.app

import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val lifecycleChannel = "com.silarah.app/app_lifecycle"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12 otherwise inserts its own icon fade between the
            // native surface and Flutter's reveal. Remove the system layer
            // atomically when Flutter reports its first composed frame.
            splashScreen.setOnExitAnimationListener { splashView ->
                splashView.remove()
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            lifecycleChannel,
        ).setMethodCallHandler { call, result ->
            if (call.method != "restartApp") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent == null) {
                result.error(
                    "restart_unavailable",
                    "Silarah's launcher activity could not be resolved.",
                    null,
                )
                return@setMethodCallHandler
            }

            result.success(true)
            launchIntent.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TASK or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION,
            )
            startActivity(launchIntent)
            overridePendingTransition(0, 0)
            finishAffinity()
        }
    }
}
