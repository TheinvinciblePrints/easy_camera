import 'package:flutter/foundation.dart';

import 'camera_enums.dart';

/// A camera available on the device.
@immutable
class EasyCameraDescription {
  const EasyCameraDescription({
    required this.id,
    required this.lens,
    required this.sensorOrientation,
    required this.hasFlash,
  });

  /// Platform identifier used to open this camera.
  final String id;

  final CameraLens lens;

  /// Clockwise angle the sensor is mounted at, relative to the device's
  /// natural orientation.
  final int sensorOrientation;

  final bool hasFlash;

  @override
  bool operator ==(Object other) =>
      other is EasyCameraDescription &&
      other.id == id &&
      other.lens == lens &&
      other.sensorOrientation == sensorOrientation &&
      other.hasFlash == hasFlash;

  @override
  int get hashCode => Object.hash(id, lens, sensorOrientation, hasFlash);

  @override
  String toString() => 'EasyCameraDescription($id, $lens)';
}
