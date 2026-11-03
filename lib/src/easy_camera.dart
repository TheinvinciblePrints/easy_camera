import 'package:flutter/material.dart';

import 'analysis/image_analyzer.dart';
import 'camera_config.dart';
import 'models/camera_description.dart';
import 'models/camera_enums.dart';
import 'models/capture_result.dart';
import 'platform/camera_platform.dart';
import 'platform/mappers.dart';
import 'platform/messages.g.dart';
import 'widgets/easy_camera_view.dart';

/// Static helpers for the camera.
abstract final class EasyCamera {
  /// Print camera errors with `debugPrint`.
  static bool debugLogging = false;

  static Future<List<EasyCameraDescription>> availableCameras() async =>
      (await CameraPlatform.instance.availableCameras())
          .map((PlatformCameraInfo c) => c.toDescription())
          .toList();

  static Future<CameraPermissionStatus> checkPermission() async =>
      (await CameraPlatform.instance.checkPermission()).toStatus();

  static Future<CameraPermissionStatus> requestPermission() async =>
      (await CameraPlatform.instance.requestPermission()).toStatus();

  /// Opens this app's page in the system settings, where the user can grant
  /// camera access after denying it permanently.
  static Future<bool> openAppSettings() =>
      CameraPlatform.instance.openAppSettings();

  /// Pushes a full-screen camera and returns the accepted photo, or null if
  /// the user closed the camera.
  ///
  /// ```dart
  /// final photo = await EasyCamera.capture(context, config: CameraConfig.food());
  /// if (photo != null) upload(photo.toClaudeImageBlock());
  /// ```
  static Future<EasyCaptureResult?> capture(
    BuildContext context, {
    CameraConfig config = const CameraConfig(),
  }) {
    return Navigator.of(context).push<EasyCaptureResult>(
      MaterialPageRoute<EasyCaptureResult>(
        fullscreenDialog: true,
        builder:
            (BuildContext context) => EasyCameraView(
              config: config,
              onCapture:
                  (EasyCaptureResult capture) =>
                      Navigator.of(context).pop(capture),
            ),
      ),
    );
  }

  /// Like [capture], but also runs [analyzer] and shows its result on the
  /// review screen. Returns the photo with its analysis, or null if the user
  /// closed the camera.
  static Future<(EasyCaptureResult, T?)?> captureAndAnalyze<T>(
    BuildContext context, {
    required ImageAnalyzer<T> analyzer,
    CameraConfig config = const CameraConfig(),
    Widget Function(BuildContext context, T result)? resultBuilder,
  }) {
    return Navigator.of(context).push<(EasyCaptureResult, T?)>(
      MaterialPageRoute<(EasyCaptureResult, T?)>(
        fullscreenDialog: true,
        builder:
            (BuildContext context) => EasyCameraView<T>(
              config: config,
              analyzer: analyzer,
              analysisResultBuilder: resultBuilder,
              onCapture: (_) {},
              onAnalyzed:
                  (EasyCaptureResult capture, T? result) =>
                      Navigator.of(context).pop((capture, result)),
            ),
      ),
    );
  }
}
