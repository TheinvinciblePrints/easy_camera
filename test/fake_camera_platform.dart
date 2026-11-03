import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_easy_camera/src/platform/camera_platform.dart';
import 'package:flutter_easy_camera/src/platform/messages.g.dart';

/// In-memory [CameraPlatform] that records calls.
class FakeCameraPlatform extends CameraPlatform {
  FakeCameraPlatform({
    this.permission = PlatformPermissionStatus.granted,
    this.permissionAfterRequest = PlatformPermissionStatus.granted,
    List<PlatformCameraInfo>? cameras,
  }) : cameras =
           cameras ??
           <PlatformCameraInfo>[
             PlatformCameraInfo(
               id: 'back0',
               lens: PlatformLens.back,
               sensorOrientation: 90,
               hasFlash: true,
             ),
             PlatformCameraInfo(
               id: 'front1',
               lens: PlatformLens.front,
               sensorOrientation: 270,
               hasFlash: false,
             ),
           ];

  PlatformPermissionStatus permission;
  PlatformPermissionStatus permissionAfterRequest;
  final List<PlatformCameraInfo> cameras;

  final List<String> calls = <String>[];
  PlatformCaptureOptions? lastCaptureOptions;
  PlatformException? captureError;
  int _texture = 0;

  final StreamController<PlatformDeviceOrientation> orientation =
      StreamController<PlatformDeviceOrientation>.broadcast();
  final StreamController<PlatformPreviewInfo> preview =
      StreamController<PlatformPreviewInfo>.broadcast();
  final StreamController<(String, String)> errorEvents =
      StreamController<(String, String)>.broadcast();

  @override
  Future<PlatformPermissionStatus> checkPermission() async {
    calls.add('checkPermission');
    return permission;
  }

  @override
  Future<PlatformPermissionStatus> requestPermission() async {
    calls.add('requestPermission');
    permission = permissionAfterRequest;
    return permission;
  }

  @override
  Future<bool> openAppSettings() async {
    calls.add('openAppSettings');
    return true;
  }

  @override
  Future<List<PlatformCameraInfo>> availableCameras() async => cameras;

  @override
  Future<PlatformCameraDescription> open(
    String cameraId,
    PlatformResolution resolution,
  ) async {
    calls.add('open:$cameraId');
    final PlatformCameraInfo info = cameras.firstWhere(
      (PlatformCameraInfo c) => c.id == cameraId,
    );
    return PlatformCameraDescription(
      textureId: ++_texture,
      preview: PlatformPreviewInfo(
        width: 1280,
        height: 960,
        rotationDegrees: 90,
        mirror: info.lens == PlatformLens.front,
      ),
      minZoom: 1,
      maxZoom: 8,
      minExposureOffset: -2,
      maxExposureOffset: 2,
      hasFlash: info.hasFlash,
    );
  }

  @override
  Future<void> setFlashMode(PlatformFlashMode mode) async =>
      calls.add('flash:${mode.name}');

  @override
  Future<void> setZoom(double zoom) async => calls.add('zoom:$zoom');

  @override
  Future<void> setFocusPoint(double x, double y) async =>
      calls.add('focus:$x,$y');

  @override
  Future<void> setExposureOffset(double offset) async =>
      calls.add('exposure:$offset');

  @override
  Future<PlatformCaptureResult> takePicture(
    PlatformCaptureOptions options,
  ) async {
    calls.add('takePicture');
    lastCaptureOptions = options;
    if (captureError != null) throw captureError!;
    return PlatformCaptureResult(
      path: '/tmp/IMG_1.jpg',
      bytes: _onePixelPng,
      width: 1568,
      height: 1176,
      lens: PlatformLens.back,
      timestampMs: 1700000000000,
    );
  }

  @override
  Future<void> pausePreview() async => calls.add('pause');

  @override
  Future<void> resumePreview() async => calls.add('resume');

  @override
  Future<void> close() async => calls.add('close');

  @override
  Stream<PlatformDeviceOrientation> get deviceOrientationChanges =>
      orientation.stream;

  @override
  Stream<PlatformPreviewInfo> get previewChanges => preview.stream;

  @override
  Stream<(String, String)> get errors => errorEvents.stream;
}

/// A valid 1x1 PNG so `Image.memory` can decode the fake capture.
final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);
