package com.watch2gether.watch2gether

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    companion object {
        init {
            try {
                System.loadLibrary("go_backend")
            } catch (e: UnsatisfiedLinkError) {
                // Fallback gracefully if libgo_backend.so is not bundled
            }
        }
    }
}
