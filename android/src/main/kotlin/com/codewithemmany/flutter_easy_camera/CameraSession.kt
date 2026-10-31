package com.codewithemmany.flutter_easy_camera

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.hardware.display.DisplayManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Size
import android.view.Display
import android.view.Surface
import android.view.WindowManager
import androidx.annotation.OptIn
import androidx.camera.camera2.interop.Camera2CameraInfo
import androidx.camera.camera2.interop.ExperimentalCamera2Interop
import androidx.camera.core.Camera
import androidx.camera.core.CameraInfo
import androidx.camera.core.CameraSelector
import androidx.camera.core.DisplayOrientedMeteringPointFactory
import androidx.camera.core.FocusMeteringAction
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.google.common.util.concurrent.ListenableFuture
import io.flutter.view.TextureRegistry
import java.io.File
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext

/** CameraX implementation of [CameraHostApi]. One camera is open at a time. */
internal class CameraSession(
    private val context: Context,
    private val textureRegistry: TextureRegistry,
    private val flutterApi: CameraFlutterApi,
    private val permissions: PermissionManager,
) : CameraHostApi {
  var activity: Activity? = null

  private val mainExecutor = ContextCompat.getMainExecutor(context)
  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

  private var provider: ProcessCameraProvider? = null
  private var camera: Camera? = null
  private var preview: Preview? = null
  private var imageCapture: ImageCapture? = null
  private var surfaceProducer: TextureRegistry.SurfaceProducer? = null
  private var lifecycleOwner: SessionLifecycleOwner? = null

  private var lens = PlatformLens.BACK
  private var sensorOrientation = 90
  private var previewResolution = Size(1280, 960)
  private var lastDisplayRotation = Surface.ROTATION_0

  private val orientationTracker =
      OrientationTracker(context) { rotation ->
        imageCapture?.targetRotation = rotation
        emit { flutterApi.onDeviceOrientationChanged(OrientationTracker.toDeviceOrientation(rotation)) }
      }

  private val displayListener =
      object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) = Unit

        override fun onDisplayRemoved(displayId: Int) = Unit

        override fun onDisplayChanged(displayId: Int) {
          val rotation = displayRotation()
          if (rotation != lastDisplayRotation && camera != null) {
            lastDisplayRotation = rotation
            emitPreviewChanged()
          }
        }
      }

  // region Permissions

  override suspend fun checkPermission(): PlatformPermissionStatus = permissions.check(activity)

  override suspend fun requestPermission(): PlatformPermissionStatus =
      permissions.request(activity)

  override fun openAppSettings(): Boolean {
    val intent =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    return runCatching { context.startActivity(intent) }.isSuccess
  }

  // endregion

  // region Camera lifecycle

  @OptIn(ExperimentalCamera2Interop::class)
  override suspend fun availableCameras(): List<PlatformCameraInfo> =
      cameraProvider().availableCameraInfos.map { info ->
        PlatformCameraInfo(
            id = Camera2CameraInfo.from(info).cameraId,
            lens = info.toPlatformLens(),
            sensorOrientation = info.sensorRotationDegrees.toLong(),
            hasFlash = info.hasFlashUnit(),
        )
      }

  @OptIn(ExperimentalCamera2Interop::class)
  override suspend fun open(
      cameraId: String,
      resolution: PlatformResolution,
  ): PlatformCameraDescription {
    if (!permissions.isGranted()) {
      throw FlutterError("permission_denied", "Camera permission has not been granted.")
    }
    val cameraProvider = cameraProvider()
    releaseCamera()

    val selector =
        CameraSelector.Builder()
            .addCameraFilter { infos ->
              infos.filter { Camera2CameraInfo.from(it).cameraId == cameraId }
            }
            .build()

    val producer = textureRegistry.createSurfaceProducer()
    surfaceProducer = producer
    producer.setCallback(
        object : TextureRegistry.SurfaceProducer.Callback {
          // Impeller may destroy the surface while the app is backgrounded;
          // asking the preview for a new surface reconnects it.
          override fun onSurfaceAvailable() {
            preview?.setSurfaceProvider(mainExecutor, ::provideSurface)
          }

          override fun onSurfaceCleanup() = Unit
        })

    val newPreview =
        Preview.Builder().setResolutionSelector(previewSelector(resolution)).build()
    newPreview.setSurfaceProvider(mainExecutor, ::provideSurface)

    val newCapture =
        ImageCapture.Builder()
            .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
            .setResolutionSelector(captureSelector(resolution))
            .setTargetRotation(orientationTracker.surfaceRotation)
            .build()

    val owner = SessionLifecycleOwner().apply { start() }
    val boundCamera =
        try {
          cameraProvider.bindToLifecycle(owner, selector, newPreview, newCapture)
        } catch (e: Exception) {
          owner.destroy()
          producer.release()
          surfaceProducer = null
          throw FlutterError("camera_open_failed", e.message ?: "Unable to open camera $cameraId.")
        }

    lifecycleOwner = owner
    preview = newPreview
    imageCapture = newCapture
    camera = boundCamera
    lens = boundCamera.cameraInfo.toPlatformLens()
    sensorOrientation = boundCamera.cameraInfo.sensorRotationDegrees
    newPreview.resolutionInfo?.resolution?.let { previewResolution = it }
    lastDisplayRotation = displayRotation()

    orientationTracker.start()
    displayManager().registerDisplayListener(displayListener, null)

    val zoom = boundCamera.cameraInfo.zoomState.value
    val exposure = boundCamera.cameraInfo.exposureState
    val step = exposure.exposureCompensationStep.toDouble()
    val range = exposure.exposureCompensationRange
    return PlatformCameraDescription(
        textureId = producer.id(),
        preview = previewInfo(),
        minZoom = (zoom?.minZoomRatio ?: 1f).toDouble(),
        maxZoom = (zoom?.maxZoomRatio ?: 1f).toDouble(),
        minExposureOffset = if (exposure.isExposureCompensationSupported) range.lower * step else 0.0,
        maxExposureOffset = if (exposure.isExposureCompensationSupported) range.upper * step else 0.0,
        hasFlash = boundCamera.cameraInfo.hasFlashUnit(),
    )
  }

  override suspend fun pausePreview() {
    lifecycleOwner?.pause()
  }

  override suspend fun resumePreview() {
    lifecycleOwner?.start()
  }

  override suspend fun close() {
    releaseCamera()
  }

  fun dispose() {
    releaseCamera()
    scope.cancel()
  }

  private fun releaseCamera() {
    if (camera == null && surfaceProducer == null) return
    orientationTracker.stop()
    displayManager().unregisterDisplayListener(displayListener)
    provider?.unbindAll()
    lifecycleOwner?.destroy()
    surfaceProducer?.release()
    lifecycleOwner = null
    surfaceProducer = null
    preview = null
    imageCapture = null
    camera = null
  }

  // endregion

  // region Controls

  override suspend fun setFlashMode(mode: PlatformFlashMode) {
    val activeCamera = requireCamera()
    val capture = imageCapture ?: throw notOpen()
    activeCamera.cameraControl.enableTorch(mode == PlatformFlashMode.TORCH).await()
    capture.flashMode =
        when (mode) {
          PlatformFlashMode.AUTO -> ImageCapture.FLASH_MODE_AUTO
          PlatformFlashMode.ON -> ImageCapture.FLASH_MODE_ON
          PlatformFlashMode.OFF,
          PlatformFlashMode.TORCH -> ImageCapture.FLASH_MODE_OFF
        }
  }

  override suspend fun setZoom(zoom: Double) {
    requireCamera().cameraControl.setZoomRatio(zoom.toFloat()).await()
  }

  override suspend fun setFocusPoint(x: Double, y: Double) {
    val activeCamera = requireCamera()
    val display = display() ?: return
    val factory = DisplayOrientedMeteringPointFactory(display, activeCamera.cameraInfo, 1f, 1f)
    val point = factory.createPoint(x.toFloat(), y.toFloat())
    val action =
        FocusMeteringAction.Builder(point, FocusMeteringAction.FLAG_AF or FocusMeteringAction.FLAG_AE)
            .setAutoCancelDuration(5, TimeUnit.SECONDS)
            .build()
    // Devices without AF support reject the action; that is not worth surfacing.
    runCatching { activeCamera.cameraControl.startFocusAndMetering(action).await() }
  }

  override suspend fun setExposureOffset(offset: Double) {
    val activeCamera = requireCamera()
    val exposure = activeCamera.cameraInfo.exposureState
    if (!exposure.isExposureCompensationSupported) return
    val step = exposure.exposureCompensationStep.toDouble()
    val index =
        Math.round(offset / step)
            .toInt()
            .coerceIn(exposure.exposureCompensationRange.lower, exposure.exposureCompensationRange.upper)
    activeCamera.cameraControl.setExposureCompensationIndex(index).await()
  }

  override suspend fun takePicture(options: PlatformCaptureOptions): PlatformCaptureResult {
    val capture = imageCapture ?: throw notOpen()
    val dir = File(context.cacheDir, "flutter_easy_camera").apply { mkdirs() }
    val timestamp = System.currentTimeMillis()
    val raw = File(dir, "raw_$timestamp.jpg")
    val output = File(dir, "IMG_$timestamp.jpg")
    val capturedLens = lens

    suspendCancellableCoroutine { continuation ->
      capture.takePicture(
          ImageCapture.OutputFileOptions.Builder(raw).build(),
          mainExecutor,
          object : ImageCapture.OnImageSavedCallback {
            override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
              continuation.resume(Unit)
            }

            override fun onError(exception: ImageCaptureException) {
              continuation.resumeWithException(
                  FlutterError("capture_failed", exception.message ?: "Capture failed."))
            }
          })
    }

    val processed =
        withContext(Dispatchers.IO) {
          try {
            ImageProcessor.process(
                raw, output, options, mirror = options.mirrorFront && capturedLens == PlatformLens.FRONT)
          } catch (e: Exception) {
            throw FlutterError("processing_failed", e.message ?: "Could not process the capture.")
          } finally {
            raw.delete()
          }
        }

    return PlatformCaptureResult(
        path = processed.file.absolutePath,
        bytes = if (options.includeBytes) processed.bytes else null,
        width = processed.width.toLong(),
        height = processed.height.toLong(),
        lens = capturedLens,
        timestampMs = timestamp,
    )
  }

  // endregion

  // region Preview

  private fun provideSurface(request: androidx.camera.core.SurfaceRequest) {
    val producer = surfaceProducer
    if (producer == null) {
      request.willNotProvideSurface()
      return
    }
    previewResolution = request.resolution
    producer.setSize(request.resolution.width, request.resolution.height)
    request.provideSurface(producer.surface, mainExecutor) {}
    emitPreviewChanged()
  }

  /**
   * Describes how Dart must rotate the texture to show it upright, following
   * https://developer.android.com/media/camera/camera2/camera-preview#orientation_calculation.
   */
  private fun previewInfo(): PlatformPreviewInfo {
    val displayDegrees = OrientationTracker.toDegrees(displayRotation())
    val front = lens == PlatformLens.FRONT
    val handlesRotation = surfaceProducer?.handlesCropAndRotation() ?: false
    val width = previewResolution.width.toDouble()
    val height = previewResolution.height.toDouble()
    return if (handlesRotation) {
      // SurfaceTexture already draws the frame upright (and mirrored for
      // front cameras) relative to the device's natural orientation.
      val swap = sensorOrientation % 180 != 0
      PlatformPreviewInfo(
          width = if (swap) height else width,
          height = if (swap) width else height,
          rotationDegrees = ((360 - displayDegrees) % 360).toLong(),
          mirror = false,
      )
    } else {
      val sign = if (front) 1 else -1
      PlatformPreviewInfo(
          width = width,
          height = height,
          rotationDegrees = ((sensorOrientation - displayDegrees * sign + 360) % 360).toLong(),
          mirror = front,
      )
    }
  }

  private fun emitPreviewChanged() {
    if (surfaceProducer == null) return
    val info = previewInfo()
    emit { flutterApi.onPreviewChanged(info) }
  }

  private fun previewSelector(resolution: PlatformResolution): ResolutionSelector {
    val bound =
        when (resolution) {
          PlatformResolution.LOW,
          PlatformResolution.MEDIUM -> Size(1280, 960)
          else -> Size(1920, 1440)
        }
    return ResolutionSelector.Builder()
        .setAspectRatioStrategy(AspectRatioStrategy.RATIO_4_3_FALLBACK_AUTO_STRATEGY)
        .setResolutionStrategy(
            ResolutionStrategy(bound, ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER))
        .build()
  }

  private fun captureSelector(resolution: PlatformResolution): ResolutionSelector {
    val strategy =
        when (resolution) {
          PlatformResolution.LOW -> fixed(Size(640, 480))
          PlatformResolution.MEDIUM -> fixed(Size(1280, 960))
          PlatformResolution.HIGH -> fixed(Size(1920, 1440))
          PlatformResolution.VERY_HIGH -> fixed(Size(2560, 1920))
          PlatformResolution.MAX -> ResolutionStrategy.HIGHEST_AVAILABLE_STRATEGY
        }
    return ResolutionSelector.Builder()
        .setAspectRatioStrategy(AspectRatioStrategy.RATIO_4_3_FALLBACK_AUTO_STRATEGY)
        .setResolutionStrategy(strategy)
        .build()
  }

  private fun fixed(size: Size) =
      ResolutionStrategy(size, ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER)

  // endregion

  // region Helpers

  private suspend fun cameraProvider(): ProcessCameraProvider =
      provider ?: ProcessCameraProvider.getInstance(context).await().also { provider = it }

  private fun requireCamera(): Camera = camera ?: throw notOpen()

  private fun notOpen() = FlutterError("camera_not_open", "No camera is open. Call open() first.")

  private fun displayManager() =
      context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager

  @Suppress("DEPRECATION")
  private fun display(): Display? =
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        activity?.display ?: displayManager().getDisplay(Display.DEFAULT_DISPLAY)
      } else {
        (context.getSystemService(Context.WINDOW_SERVICE) as WindowManager).defaultDisplay
      }

  private fun displayRotation(): Int = display()?.rotation ?: Surface.ROTATION_0

  private fun emit(block: suspend () -> Unit) {
    scope.launch { runCatching { block() } }
  }

  private suspend fun <T> ListenableFuture<T>.await(): T = suspendCancellableCoroutine { cont ->
    addListener(
        {
          try {
            cont.resume(get())
          } catch (e: Exception) {
            cont.resumeWithException(e.cause ?: e)
          }
        },
        mainExecutor,
    )
    cont.invokeOnCancellation { cancel(false) }
  }

  // endregion
}

private fun CameraInfo.toPlatformLens(): PlatformLens =
    when (lensFacing) {
      CameraSelector.LENS_FACING_FRONT -> PlatformLens.FRONT
      CameraSelector.LENS_FACING_EXTERNAL -> PlatformLens.EXTERNAL
      else -> PlatformLens.BACK
    }

/**
 * Lifecycle owned by the session so the camera runs independently of the
 * host activity type. Dart drives pause and resume from app lifecycle events.
 */
@SuppressLint("VisibleForTests")
private class SessionLifecycleOwner : LifecycleOwner {
  private val registry = LifecycleRegistry.createUnsafe(this)
  override val lifecycle: Lifecycle
    get() = registry

  fun start() {
    if (registry.currentState == Lifecycle.State.DESTROYED) return
    registry.currentState = Lifecycle.State.RESUMED
  }

  fun pause() {
    if (registry.currentState == Lifecycle.State.DESTROYED) return
    registry.currentState = Lifecycle.State.CREATED
  }

  fun destroy() {
    if (registry.currentState == Lifecycle.State.INITIALIZED) {
      registry.currentState = Lifecycle.State.CREATED
    }
    registry.currentState = Lifecycle.State.DESTROYED
  }
}
