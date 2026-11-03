import 'package:flutter/services.dart';

import '../models/camera_description.dart';
import '../models/camera_enums.dart';
import '../models/preview_info.dart';
import 'messages.g.dart';

extension PlatformLensMapper on PlatformLens {
  CameraLens toLens() => switch (this) {
    PlatformLens.front => CameraLens.front,
    PlatformLens.back => CameraLens.back,
    PlatformLens.external => CameraLens.external,
  };
}

extension CameraFlashModeMapper on CameraFlashMode {
  PlatformFlashMode toPlatform() => switch (this) {
    CameraFlashMode.off => PlatformFlashMode.off,
    CameraFlashMode.auto => PlatformFlashMode.auto,
    CameraFlashMode.on => PlatformFlashMode.on,
    CameraFlashMode.torch => PlatformFlashMode.torch,
  };
}

extension ResolutionPresetMapper on ResolutionPreset {
  PlatformResolution toPlatform() => switch (this) {
    ResolutionPreset.low => PlatformResolution.low,
    ResolutionPreset.medium => PlatformResolution.medium,
    ResolutionPreset.high => PlatformResolution.high,
    ResolutionPreset.veryHigh => PlatformResolution.veryHigh,
    ResolutionPreset.max => PlatformResolution.max,
  };
}

extension PlatformPermissionMapper on PlatformPermissionStatus {
  CameraPermissionStatus toStatus() => switch (this) {
    PlatformPermissionStatus.granted => CameraPermissionStatus.granted,
    PlatformPermissionStatus.denied => CameraPermissionStatus.denied,
    PlatformPermissionStatus.permanentlyDenied =>
      CameraPermissionStatus.permanentlyDenied,
    PlatformPermissionStatus.notDetermined =>
      CameraPermissionStatus.notDetermined,
  };
}

extension PlatformOrientationMapper on PlatformDeviceOrientation {
  DeviceOrientation toDeviceOrientation() => switch (this) {
    PlatformDeviceOrientation.portraitUp => DeviceOrientation.portraitUp,
    PlatformDeviceOrientation.landscapeLeft => DeviceOrientation.landscapeLeft,
    PlatformDeviceOrientation.portraitDown => DeviceOrientation.portraitDown,
    PlatformDeviceOrientation.landscapeRight =>
      DeviceOrientation.landscapeRight,
  };
}

extension PlatformCameraInfoMapper on PlatformCameraInfo {
  EasyCameraDescription toDescription() => EasyCameraDescription(
    id: id,
    lens: lens.toLens(),
    sensorOrientation: sensorOrientation,
    hasFlash: hasFlash,
  );
}

extension PlatformPreviewInfoMapper on PlatformPreviewInfo {
  PreviewInfo toPreviewInfo() => PreviewInfo(
    width: width,
    height: height,
    rotationDegrees: rotationDegrees,
    mirror: mirror,
  );
}
