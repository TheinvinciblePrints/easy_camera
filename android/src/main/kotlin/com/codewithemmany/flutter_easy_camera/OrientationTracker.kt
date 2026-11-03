package com.codewithemmany.flutter_easy_camera

import android.content.Context
import android.view.OrientationEventListener
import android.view.Surface

/**
 * Tracks the physical orientation of the device, even when the UI is locked,
 * and reports it as a [Surface] rotation constant.
 */
internal class OrientationTracker(
    context: Context,
    private val onChanged: (surfaceRotation: Int) -> Unit,
) {
  var surfaceRotation: Int = Surface.ROTATION_0
    private set

  private val listener =
      object : OrientationEventListener(context) {
        override fun onOrientationChanged(orientation: Int) {
          if (orientation == ORIENTATION_UNKNOWN) return
          val rotation =
              when (orientation) {
                in 45 until 135 -> Surface.ROTATION_270
                in 135 until 225 -> Surface.ROTATION_180
                in 225 until 315 -> Surface.ROTATION_90
                else -> Surface.ROTATION_0
              }
          if (rotation != surfaceRotation) {
            surfaceRotation = rotation
            onChanged(rotation)
          }
        }
      }

  fun start() {
    if (listener.canDetectOrientation()) listener.enable()
  }

  fun stop() = listener.disable()

  companion object {
    fun toDeviceOrientation(surfaceRotation: Int): PlatformDeviceOrientation =
        when (surfaceRotation) {
          Surface.ROTATION_90 -> PlatformDeviceOrientation.LANDSCAPE_LEFT
          Surface.ROTATION_180 -> PlatformDeviceOrientation.PORTRAIT_DOWN
          Surface.ROTATION_270 -> PlatformDeviceOrientation.LANDSCAPE_RIGHT
          else -> PlatformDeviceOrientation.PORTRAIT_UP
        }

    fun toDegrees(surfaceRotation: Int): Int =
        when (surfaceRotation) {
          Surface.ROTATION_90 -> 90
          Surface.ROTATION_180 -> 180
          Surface.ROTATION_270 -> 270
          else -> 0
        }
  }
}
