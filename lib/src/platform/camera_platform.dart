import 'dart:async';

import 'package:flutter/foundation.dart';

import 'messages.g.dart';

/// Thin layer over the generated Pigeon API.
///
/// Swap [instance] for a fake in tests.
abstract class CameraPlatform {
  static CameraPlatform instance = PigeonCameraPlatform();

  Future<PlatformPermissionStatus> checkPermission();
  Future<PlatformPermissionStatus> requestPermission();
  Future<bool> openAppSettings();
  Future<List<PlatformCameraInfo>> availableCameras();
  Future<PlatformCameraDescription> open(
    String cameraId,
    PlatformResolution resolution,
  );
  Future<void> setFlashMode(PlatformFlashMode mode);
  Future<void> setZoom(double zoom);
  Future<void> setFocusPoint(double x, double y);
  Future<void> setExposureOffset(double offset);
  Future<PlatformCaptureResult> takePicture(PlatformCaptureOptions options);
  Future<void> pausePreview();
  Future<void> resumePreview();
  Future<void> close();

  Stream<PlatformDeviceOrientation> get deviceOrientationChanges;
  Stream<PlatformPreviewInfo> get previewChanges;
  Stream<(String code, String message)> get errors;
}

/// Default [CameraPlatform] backed by the native plugin.
class PigeonCameraPlatform extends CameraPlatform implements CameraFlutterApi {
  PigeonCameraPlatform({CameraHostApi? hostApi})
    : _host = hostApi ?? CameraHostApi();

  final CameraHostApi _host;
  bool _listening = false;

  final StreamController<PlatformDeviceOrientation> _orientation =
      StreamController<PlatformDeviceOrientation>.broadcast();
  final StreamController<PlatformPreviewInfo> _preview =
      StreamController<PlatformPreviewInfo>.broadcast();
  final StreamController<(String, String)> _errors =
      StreamController<(String, String)>.broadcast();

  void _ensureListening() {
    if (_listening) return;
    _listening = true;
    CameraFlutterApi.setUp(this);
  }

  @override
  Future<PlatformPermissionStatus> checkPermission() => _host.checkPermission();

  @override
  Future<PlatformPermissionStatus> requestPermission() =>
      _host.requestPermission();

  @override
  Future<bool> openAppSettings() => _host.openAppSettings();

  @override
  Future<List<PlatformCameraInfo>> availableCameras() =>
      _host.availableCameras();

  @override
  Future<PlatformCameraDescription> open(
    String cameraId,
    PlatformResolution resolution,
  ) {
    _ensureListening();
    return _host.open(cameraId, resolution);
  }

  @override
  Future<void> setFlashMode(PlatformFlashMode mode) => _host.setFlashMode(mode);

  @override
  Future<void> setZoom(double zoom) => _host.setZoom(zoom);

  @override
  Future<void> setFocusPoint(double x, double y) => _host.setFocusPoint(x, y);

  @override
  Future<void> setExposureOffset(double offset) =>
      _host.setExposureOffset(offset);

  @override
  Future<PlatformCaptureResult> takePicture(PlatformCaptureOptions options) =>
      _host.takePicture(options);

  @override
  Future<void> pausePreview() => _host.pausePreview();

  @override
  Future<void> resumePreview() => _host.resumePreview();

  @override
  Future<void> close() => _host.close();

  @override
  Stream<PlatformDeviceOrientation> get deviceOrientationChanges =>
      _orientation.stream;

  @override
  Stream<PlatformPreviewInfo> get previewChanges => _preview.stream;

  @override
  Stream<(String, String)> get errors => _errors.stream;

  // CameraFlutterApi

  @override
  @protected
  void onDeviceOrientationChanged(PlatformDeviceOrientation orientation) =>
      _orientation.add(orientation);

  @override
  @protected
  void onPreviewChanged(PlatformPreviewInfo preview) => _preview.add(preview);

  @override
  @protected
  void onError(String code, String message) => _errors.add((code, message));

  @override
  @protected
  void onClosed() {}
}
