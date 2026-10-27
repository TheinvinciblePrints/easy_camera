import 'package:flutter/foundation.dart';

/// How the native preview texture must be drawn to look upright.
@immutable
class PreviewInfo {
  const PreviewInfo({
    required this.width,
    required this.height,
    this.rotationDegrees = 0,
    this.mirror = false,
  });

  static const PreviewInfo empty = PreviewInfo(width: 3, height: 4);

  /// Texture size before [rotationDegrees] is applied.
  final double width;
  final double height;

  /// Clockwise rotation: 0, 90, 180 or 270.
  final int rotationDegrees;

  /// Flip horizontally after rotating.
  final bool mirror;

  int get quarterTurns => (rotationDegrees ~/ 90) % 4;

  /// Width / height as shown on screen.
  double get displayAspectRatio =>
      quarterTurns.isOdd ? height / width : width / height;

  @override
  bool operator ==(Object other) =>
      other is PreviewInfo &&
      other.width == width &&
      other.height == height &&
      other.rotationDegrees == rotationDegrees &&
      other.mirror == mirror;

  @override
  int get hashCode => Object.hash(width, height, rotationDegrees, mirror);
}
