package com.paidix.paidix

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.SurfaceView
import android.view.TextureView
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var lifecycleChannel: MethodChannel? = null
    private var isResumedState = false
    private var wasStoppedInBackground = false
    private var returnedFromActivityResult = false
    private var isUiDisplayed = false
    private var hasDisplayedFlutterUi = false
    private var watchdogGeneration = 0
    private var pendingWatchdog: Runnable? = null

    /**
     * Uses SurfaceView (RenderMode.surface) which gives Android WindowManager direct control over
     * the hardware surface layer lifecycle, bypassing Gralloc3 / ion allocator issues on Huawei EMUI /
     * Kirin / Mali devices while maintaining fast rendering and zero-black-screen restarts.
     */
    override fun getRenderMode(): RenderMode {
        return RenderMode.surface
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        lifecycleChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LIFECYCLE_CHANNEL
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        isUiDisplayed = false
        wasStoppedInBackground = false
        returnedFromActivityResult = false
    }

    override fun onStart() {
        super.onStart()
        ensureFlutterViewVisible()
    }

    override fun onResume() {
        super.onResume()
        isResumedState = true
        ensureFlutterViewVisible()
    }

    override fun onPostResume() {
        super.onPostResume()
        ensureFlutterViewVisible()
        verifyRenderStateOnResume()
    }

    override fun onPause() {
        isResumedState = false
        cancelRenderWatchdog()
        super.onPause()
    }

    override fun onStop() {
        wasStoppedInBackground = true
        cancelRenderWatchdog()
        super.onStop()
    }

    override fun onDestroy() {
        cancelRenderWatchdog()
        lifecycleChannel = null
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (isResumedState) {
            ensureFlutterViewVisible()
            verifyRenderStateOnResume()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        returnedFromActivityResult = true
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && isResumedState) {
            ensureFlutterViewVisible()
        }
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        isUiDisplayed = true
        hasDisplayedFlutterUi = true
        if (!wasStoppedInBackground) {
            cancelRenderWatchdog()
        }
    }

    override fun onFlutterUiNoLongerDisplayed() {
        super.onFlutterUiNoLongerDisplayed()
        isUiDisplayed = false
        if (isResumedState && !isFinishing && !isDestroyed) {
            scheduleResumeVerification(RESUME_RENDER_GRACE_MS)
        }
    }

    private fun verifyRenderStateOnResume() {
        val engine = flutterEngine
        if (engine == null || !engine.dartExecutor.isExecutingDart) {
            // Flutter IDE debug launches can intentionally pause Dart before main().
            // Restarting here prevents the debugger from resuming the first frame.
            if (isDebuggableBuild() && !hasDisplayedFlutterUi) {
                cancelRenderWatchdog()
                return
            }
            restartActivityImmediately()
            return
        }

        if (!wasStoppedInBackground) {
            returnedFromActivityResult = false
            if (!isUiDisplayed && !engine.renderer.isDisplayingFlutterUi) {
                armColdStartWatchdog()
            }
            return
        }

        wasStoppedInBackground = false
        val graceMs = if (returnedFromActivityResult) {
            PICKER_RETURN_RENDER_GRACE_MS
        } else {
            RESUME_RENDER_GRACE_MS
        }
        returnedFromActivityResult = false
        scheduleResumeVerification(graceMs)
    }

    private fun armColdStartWatchdog() {
        // `flutter run --start-paused` has no Dart frame until the IDE resumes it.
        // Leave cold-start recovery to the debugger during that initial debug launch.
        if (isDebuggableBuild() && !hasDisplayedFlutterUi) {
            return
        }
        cancelRenderWatchdog()
        val generation = ++watchdogGeneration
        val runnable = Runnable {
            if (generation != watchdogGeneration || !isResumedState || isFinishing || isDestroyed) {
                return@Runnable
            }
            val renderer = flutterEngine?.renderer
            val uiReady = isUiDisplayed || (renderer?.isDisplayingFlutterUi == true)
            if (!uiReady || !isSurfaceTreeHealthy()) {
                restartActivityImmediately()
            }
        }
        pendingWatchdog = runnable
        mainHandler.postDelayed(runnable, COLD_START_RENDER_GRACE_MS)
    }

    private fun scheduleResumeVerification(graceMs: Long) {
        cancelRenderWatchdog()
        val generation = ++watchdogGeneration
        var dartFrameConfirmed = false

        val deadlineRunnable = Runnable {
            if (generation != watchdogGeneration || !isResumedState || isFinishing || isDestroyed) {
                return@Runnable
            }
            val engine = flutterEngine
            val engineAlive = engine != null && engine.dartExecutor.isExecutingDart
            val rendererDisplaying = engine?.renderer?.isDisplayingFlutterUi == true
            if (!engineAlive || !rendererDisplaying || !isSurfaceTreeHealthy() || !dartFrameConfirmed) {
                restartActivityImmediately()
            }
        }
        pendingWatchdog = deadlineRunnable
        mainHandler.postDelayed(deadlineRunnable, graceMs)

        val channel = lifecycleChannel ?: return
        try {
            channel.invokeMethod(
                "verifyFrameRendered",
                null,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        if (generation != watchdogGeneration || !isResumedState || isFinishing || isDestroyed) {
                            return
                        }
                        if (result == true) {
                            dartFrameConfirmed = true
                            if (flutterEngine?.renderer?.isDisplayingFlutterUi == true &&
                                isSurfaceTreeHealthy()
                            ) {
                                cancelRenderWatchdog()
                            }
                        }
                    }

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        // Watchdog deadline will evaluate surface health and restart if needed.
                    }

                    override fun notImplemented() {
                        // Keep deadline active so stuck boots still recover cleanly.
                    }
                }
            )
        } catch (_: Exception) {
            // Watchdog deadline will restart cleanly if the channel cannot dispatch.
        }
    }

    private fun ensureFlutterViewVisible() {
        val fv = findFlutterView() ?: return
        if (fv.visibility != View.VISIBLE) {
            fv.visibility = View.VISIBLE
        }
        fv.requestLayout()
        fv.invalidate()
        findTextureView(fv)?.invalidate()
        val sv = findSurfaceView(fv)
        if (sv != null) {
            if (sv.visibility != View.VISIBLE) {
                sv.visibility = View.VISIBLE
            }
            val holder = sv.holder
            if (holder != null && !holder.surface.isValid) {
                // Re-arm SurfaceView attachment if detached by Huawei EMUI backgrounding
                sv.visibility = View.GONE
                sv.visibility = View.VISIBLE
            }
            sv.requestLayout()
            sv.invalidate()
        }
    }

    private fun isDebuggableBuild(): Boolean =
        (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    private fun isSurfaceTreeHealthy(): Boolean {
        val fv = findFlutterView() ?: return false
        if (!fv.isAttachedToWindow || fv.visibility != View.VISIBLE || fv.width <= 0 || fv.height <= 0) {
            return false
        }
        val tv = findTextureView(fv)
        if (tv != null) {
            val texture = tv.surfaceTexture
            if (!tv.isAvailable || texture == null) {
                return false
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && texture.isReleased) {
                return false
            }
        }
        val sv = findSurfaceView(fv)
        if (sv != null) {
            val surface = sv.holder?.surface
            if (surface == null || !surface.isValid) {
                return false
            }
        }
        return true
    }

    private fun findFlutterView(): FlutterView? {
        val byId = findViewById<View>(FLUTTER_VIEW_ID)
        if (byId is FlutterView) return byId
        return findViewOfType(window?.decorView, FlutterView::class.java)
    }

    private fun findSurfaceView(root: View?): SurfaceView? {
        return findViewOfType(root, SurfaceView::class.java)
    }

    private fun findTextureView(root: View?): TextureView? {
        return findViewOfType(root, TextureView::class.java)
    }

    private fun <T : View> findViewOfType(root: View?, targetClass: Class<T>): T? {
        if (root == null) return null
        if (targetClass.isInstance(root)) return targetClass.cast(root)
        if (root is ViewGroup) {
            for (i in 0 until root.childCount) {
                val found = findViewOfType(root.getChildAt(i), targetClass)
                if (found != null) return found
            }
        }
        return null
    }

    private fun cancelRenderWatchdog() {
        watchdogGeneration++
        pendingWatchdog?.let { mainHandler.removeCallbacks(it) }
        pendingWatchdog = null
    }

    private fun restartActivityImmediately() {
        if (isFinishing || isDestroyed) return
        cancelRenderWatchdog()

        val now = SystemClock.elapsedRealtime()
        val intentRestartAt = intent?.getLongExtra(EXTRA_AUTO_RESTARTED_AT, 0L) ?: 0L
        val withinProcessCooldown =
            lastProcessAutoRestartMs > 0L && (now - lastProcessAutoRestartMs) < RESTART_COOLDOWN_MS
        val withinIntentCooldown =
            intentRestartAt > 0L && (now - intentRestartAt) < RESTART_COOLDOWN_MS
        if (withinProcessCooldown || withinIntentCooldown) {
            return
        }
        lastProcessAutoRestartMs = now

        val restartIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TASK or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION
            )
            putExtra(EXTRA_AUTO_RESTARTED_AT, now)
        }
        startActivity(restartIntent)
        finish()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            overrideActivityTransition(OVERRIDE_TRANSITION_OPEN, 0, 0)
            overrideActivityTransition(OVERRIDE_TRANSITION_CLOSE, 0, 0)
        } else {
            @Suppress("DEPRECATION")
            overridePendingTransition(0, 0)
        }
    }

    companion object {
        private const val LIFECYCLE_CHANNEL = "com.paidix.paidix/lifecycle"
        private const val EXTRA_AUTO_RESTARTED_AT = "paidix_auto_restarted_at"
        private const val RESTART_COOLDOWN_MS = 8_000L
        private const val RESUME_RENDER_GRACE_MS = 600L
        private const val PICKER_RETURN_RENDER_GRACE_MS = 1_600L
        private const val COLD_START_RENDER_GRACE_MS = 10_000L
        private var lastProcessAutoRestartMs = 0L
    }
}

