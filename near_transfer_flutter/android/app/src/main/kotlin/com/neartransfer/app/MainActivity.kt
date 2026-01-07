package com.neartransfer.app

import android.os.Bundle
import android.content.pm.PackageManager
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.neartransfer.app/apk_info"

    override fun onCreate(savedInstanceState: Bundle?) {
        // Install splash screen BEFORE super.onCreate() - this is critical!
        val splashScreen = installSplashScreen()
        
        // Exit splash immediately when ready (don't keep waiting)
        splashScreen.setKeepOnScreenCondition { false }
        
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getApkInfo" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        try {
                            val pm = packageManager
                            val appInfo = pm.getApplicationInfo(packageName, 0)
                            val apkPath = appInfo.sourceDir
                            val apkFile = File(apkPath)
                            val size = if (apkFile.exists()) apkFile.length() else 0L
                            
                            result.success(mapOf(
                                "path" to apkPath,
                                "size" to size
                            ))
                        } catch (e: PackageManager.NameNotFoundException) {
                            result.error("NOT_FOUND", "Package not found: $packageName", null)
                        } catch (e: Exception) {
                            result.error("ERROR", "Failed to get APK info: ${e.message}", null)
                        }
                    } else {
                        result.error("BAD_ARGS", "packageName is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
