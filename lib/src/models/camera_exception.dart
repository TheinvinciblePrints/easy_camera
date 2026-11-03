import 'package:flutter/services.dart';

/// An error raised by the camera.
///
/// Common [code]s: `permission_denied`, `camera_not_found`,
/// `camera_open_failed`, `camera_not_open`, `capture_failed`,
/// `processing_failed`, `interrupted`, `runtime_error`.
class EasyCameraException implements Exception {
  const EasyCameraException(this.code, [this.message]);

  factory EasyCameraException.fromPlatform(PlatformException e) =>
      EasyCameraException(e.code, e.message);

  final String code;
  final String? message;

  @override
  String toString() =>
      'EasyCameraException($code${message == null ? '' : ': $message'})';
}
