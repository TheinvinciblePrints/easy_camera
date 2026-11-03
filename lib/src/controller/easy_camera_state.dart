import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/camera_description.dart';
import '../models/camera_enums.dart';
import '../models/camera_exception.dart';
import '../models/preview_info.dart';

/// Lifecycle of an `EasyCameraController`.
enum CameraStatus {
  /// `initialize()` has not been called.
  uninitialized,

  /// Asking for permission or opening the camera.
  initializing,

  /// The preview is running and photos can be taken.
  ready,

  /// The user has not granted camera access. See `permission`.
  permissionDenied,

  /// No camera could be opened. See `error`.
  error,

  /// The controller was disposed.
  disposed,
}

/// Snapshot of everything the camera UI needs.
@immutable
class EasyCameraState {
  const EasyCameraState({
    this.status = CameraStatus.uninitialized,
    this.permission,
    this.cameras = const <EasyCameraDescription>[],
    this.camera,
    this.textureId,
    this.preview = PreviewInfo.empty,
    this.flashMode = CameraFlashMode.off,
    this.hasFlash = false,
    this.zoom = 1.0,
    this.minZoom = 1.0,
    this.maxZoom = 1.0,
    this.exposureOffset = 0.0,
    this.minExposureOffset = 0.0,
    this.maxExposureOffset = 0.0,
    this.deviceOrientation = DeviceOrientation.portraitUp,
    this.isCapturing = false,
    this.isPaused = false,
    this.error,
  });

  final CameraStatus status;
  final CameraPermissionStatus? permission;

  /// All cameras on the device.
  final List<EasyCameraDescription> cameras;

  /// The open camera.
  final EasyCameraDescription? camera;

  /// Flutter texture showing the preview.
  final int? textureId;
  final PreviewInfo preview;

  final CameraFlashMode flashMode;
  final bool hasFlash;

  final double zoom;
  final double minZoom;
  final double maxZoom;

  final double exposureOffset;
  final double minExposureOffset;
  final double maxExposureOffset;

  /// Physical orientation of the device, even when the UI is locked.
  final DeviceOrientation deviceOrientation;

  final bool isCapturing;
  final bool isPaused;

  /// The most recent error, if any.
  final EasyCameraException? error;

  bool get isReady => status == CameraStatus.ready && textureId != null;

  CameraLens? get lens => camera?.lens;

  /// Whether there is a camera facing the other way to switch to.
  bool get canSwitchCamera =>
      cameras.map((EasyCameraDescription c) => c.lens).toSet().length > 1;

  EasyCameraState copyWith({
    CameraStatus? status,
    CameraPermissionStatus? permission,
    List<EasyCameraDescription>? cameras,
    EasyCameraDescription? camera,
    int? textureId,
    PreviewInfo? preview,
    CameraFlashMode? flashMode,
    bool? hasFlash,
    double? zoom,
    double? minZoom,
    double? maxZoom,
    double? exposureOffset,
    double? minExposureOffset,
    double? maxExposureOffset,
    DeviceOrientation? deviceOrientation,
    bool? isCapturing,
    bool? isPaused,
    EasyCameraException? error,
    bool clearError = false,
    bool clearTexture = false,
  }) {
    return EasyCameraState(
      status: status ?? this.status,
      permission: permission ?? this.permission,
      cameras: cameras ?? this.cameras,
      camera: camera ?? this.camera,
      textureId: clearTexture ? null : textureId ?? this.textureId,
      preview: preview ?? this.preview,
      flashMode: flashMode ?? this.flashMode,
      hasFlash: hasFlash ?? this.hasFlash,
      zoom: zoom ?? this.zoom,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      exposureOffset: exposureOffset ?? this.exposureOffset,
      minExposureOffset: minExposureOffset ?? this.minExposureOffset,
      maxExposureOffset: maxExposureOffset ?? this.maxExposureOffset,
      deviceOrientation: deviceOrientation ?? this.deviceOrientation,
      isCapturing: isCapturing ?? this.isCapturing,
      isPaused: isPaused ?? this.isPaused,
      error: clearError ? null : error ?? this.error,
    );
  }
}
