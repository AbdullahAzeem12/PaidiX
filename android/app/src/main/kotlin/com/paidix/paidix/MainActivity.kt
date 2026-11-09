package com.paidix.paidix

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode

class MainActivity : FlutterActivity() {
    /** Returns the native surface render mode to ensure proper surface recreation on resume. */
    override fun getRenderMode(): RenderMode {
        // Use SurfaceView (RenderMode.surface) which gives Android WindowManager direct control over
        // the surface layer lifecycle, automatically restoring graphics context on resume from external apps.
        return RenderMode.surface
    }
}

