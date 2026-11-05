// Hosts the Flutter app and selects texture rendering for reliable camera/gallery returns.
package com.paidix.paidix

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode

class MainActivity : FlutterActivity() {
    /** Returns the texture-backed render mode used to avoid activity-resume freezes. */
    override fun getRenderMode(): RenderMode {
        // Force TextureView instead of SurfaceView to completely prevent black/blank screen freezes
        // when returning from external Gallery/Camera activities on Huawei EMUI and HarmonyOS devices.
        return RenderMode.texture
    }
}

