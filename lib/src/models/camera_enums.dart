/// Which way a camera faces.
enum CameraLens {
  /// Faces the user (selfie camera).
  front,

  /// Faces away from the user.
  back,

  /// A camera that is not built into the device, such as a USB camera.
  external,
}

/// Flash behaviour for captures.
enum CameraFlashMode {
  /// Never fire the flash.
  off,

  /// Let the camera decide based on the scene.
  auto,

  /// Always fire the flash when capturing.
  on,

  /// Keep the light on continuously, which helps framing in dim rooms.
  torch,
}

/// Capture resolution. The long side of the photo is roughly:
enum ResolutionPreset {
  /// 640 px.
  low,

  /// 1280 px.
  medium,

  /// 1920 px.
  high,

  /// 2560 px.
  veryHigh,

  /// The largest size the sensor supports.
  max,
}

/// Camera permission state.
enum CameraPermissionStatus {
  /// The app may use the camera.
  granted,

  /// The user declined, but the app may ask again.
  denied,

  /// The user declined and the system will not ask again. Send them to
  /// settings with `EasyCamera.openAppSettings()`.
  permanentlyDenied,

  /// The app has not asked yet.
  notDetermined,
}

/// How the preview fills its box.
enum PreviewFit {
  /// Fill the whole box, cropping the edges of the preview.
  cover,

  /// Show the whole preview, letterboxed if needed.
  contain,
}
