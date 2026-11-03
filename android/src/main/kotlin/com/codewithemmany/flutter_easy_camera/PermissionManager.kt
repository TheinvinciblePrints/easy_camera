package com.codewithemmany.flutter_easy_camera

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.PluginRegistry
import kotlin.coroutines.resume
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.suspendCancellableCoroutine

/** Checks and requests the CAMERA runtime permission. */
internal class PermissionManager(private val context: Context) :
    PluginRegistry.RequestPermissionsResultListener {
  private var pending: CancellableContinuation<PlatformPermissionStatus>? = null
  private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

  fun isGranted(): Boolean =
      ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) ==
          PackageManager.PERMISSION_GRANTED

  fun check(activity: Activity?): PlatformPermissionStatus {
    if (isGranted()) return PlatformPermissionStatus.GRANTED
    if (!prefs.getBoolean(KEY_REQUESTED, false)) return PlatformPermissionStatus.NOT_DETERMINED
    // After a denial Android only shows the rationale flag while the dialog can
    // still be shown; once it is false the user picked "Don't ask again".
    val canAskAgain =
        activity != null &&
            ActivityCompat.shouldShowRequestPermissionRationale(
                activity, Manifest.permission.CAMERA)
    return if (canAskAgain) PlatformPermissionStatus.DENIED
    else PlatformPermissionStatus.PERMANENTLY_DENIED
  }

  suspend fun request(activity: Activity?): PlatformPermissionStatus {
    if (isGranted()) return PlatformPermissionStatus.GRANTED
    if (activity == null) {
      throw FlutterError("no_activity", "Camera permission requires a foreground activity.")
    }
    if (pending != null) {
      throw FlutterError("permission_in_progress", "A permission request is already running.")
    }
    return suspendCancellableCoroutine { continuation ->
      pending = continuation
      continuation.invokeOnCancellation { pending = null }
      prefs.edit().putBoolean(KEY_REQUESTED, true).apply()
      ActivityCompat.requestPermissions(
          activity, arrayOf(Manifest.permission.CAMERA), REQUEST_CODE)
    }
  }

  override fun onRequestPermissionsResult(
      requestCode: Int,
      permissions: Array<out String>,
      grantResults: IntArray,
  ): Boolean {
    if (requestCode != REQUEST_CODE) return false
    val continuation = pending ?: return true
    pending = null
    val granted =
        grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
    continuation.resume(
        if (granted) PlatformPermissionStatus.GRANTED else PlatformPermissionStatus.DENIED)
    return true
  }

  private companion object {
    const val REQUEST_CODE = 0x45C4
    const val PREFS = "flutter_easy_camera"
    const val KEY_REQUESTED = "camera_permission_requested"
  }
}
