package com.codewithemmany.flutter_easy_camera

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/** Entry point that wires the Pigeon host API to a CameraX [CameraSession]. */
class FlutterEasyCameraPlugin : FlutterPlugin, ActivityAware {
  private var session: CameraSession? = null
  private var permissions: PermissionManager? = null
  private var activityBinding: ActivityPluginBinding? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    val permissionManager = PermissionManager(binding.applicationContext)
    val cameraSession =
        CameraSession(
            binding.applicationContext,
            binding.textureRegistry,
            CameraFlutterApi(binding.binaryMessenger),
            permissionManager,
        )
    permissions = permissionManager
    session = cameraSession
    CameraHostApi.setUp(binding.binaryMessenger, cameraSession)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    CameraHostApi.setUp(binding.binaryMessenger, null)
    session?.dispose()
    session = null
    permissions = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activityBinding = binding
    session?.activity = binding.activity
    permissions?.let(binding::addRequestPermissionsResultListener)
  }

  override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
      onAttachedToActivity(binding)

  override fun onDetachedFromActivity() {
    permissions?.let { activityBinding?.removeRequestPermissionsResultListener(it) }
    session?.activity = null
    activityBinding = null
  }
}
