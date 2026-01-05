package com.neartransfer.app

import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Install splash screen BEFORE super.onCreate() - this is critical!
        val splashScreen = installSplashScreen()
        
        // Exit splash immediately when ready (don't keep waiting)
        splashScreen.setKeepOnScreenCondition { false }
        
        super.onCreate(savedInstanceState)
    }
}
