package com.a1chimney.a1tools

import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Handle edge-to-edge before calling super.onCreate()
        // This opts out of the automatic edge-to-edge enforcement on Android 15+
        // while still allowing Flutter to manage the system bars
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            // For Android 15+ (SDK 35+), let Flutter handle the insets
            // by telling the system we'll manage edge-to-edge ourselves
            WindowCompat.setDecorFitsSystemWindows(window, false)
        }

        super.onCreate(savedInstanceState)
    }
}
