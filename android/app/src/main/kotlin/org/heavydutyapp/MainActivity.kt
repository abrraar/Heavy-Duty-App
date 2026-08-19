package org.heavydutyapp

import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        Log.d("SplashDebug", "MainActivity onCreate started")

        // Install the splash screen via the compat library
        val splashScreen = installSplashScreen()

        // Handle Android 12+ Splash Screen Exit instantly
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { splashScreenView ->
                Log.d("SplashDebug", "Exit Animation Listener TRIGGERED - Removing splash immediately")
                splashScreenView.remove()
            }
        }

        super.onCreate(savedInstanceState)
        
        // Allow activity to show over lock screen and turn screen on
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
    }
}
