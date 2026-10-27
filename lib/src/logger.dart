import 'package:flutter/foundation.dart';

import 'easy_camera.dart';

/// Prints [message] when `EasyCamera.debugLogging` is on.
void logError(String message, [String? code]) {
  if (!EasyCamera.debugLogging) {
    return;
  }
  debugPrint('[flutter_easy_camera] ${code == null ? '' : '$code: '}$message');
}
