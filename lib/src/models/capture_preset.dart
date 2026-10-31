import 'package:flutter/foundation.dart';

/// How a capture is post-processed on the device before it reaches Dart.
///
/// All work (rotation, mirroring, cropping, resizing and JPEG encoding)
/// happens natively, so the bytes you get are ready to upload.
@immutable
class CapturePreset {
  const CapturePreset({
    this.maxDimension,
    this.jpegQuality = 90,
    this.cropAspectRatio,
    this.mirrorFrontCamera = true,
    this.stripMetadata = false,
  }) : assert(jpegQuality > 0 && jpegQuality <= 100),
       assert(maxDimension == null || maxDimension > 0),
       assert(cropAspectRatio == null || cropAspectRatio > 0);

  /// Full sensor size, light compression, metadata kept.
  static const CapturePreset original = CapturePreset(jpegQuality: 95);

  /// Tuned for sending meals to a vision model.
  ///
  /// The long side is capped at 1568 px, the size Claude's vision models work
  /// at without resizing, and other providers handle it well too. Metadata,
  /// including GPS, is stripped before the image leaves the device.
  static const CapturePreset food = CapturePreset(
    maxDimension: 1568,
    jpegQuality: 85,
    stripMetadata: true,
  );

  /// For labels, receipts and menus where text must stay legible.
  static const CapturePreset document = CapturePreset(
    maxDimension: 2048,
    jpegQuality: 90,
    stripMetadata: true,
    mirrorFrontCamera: false,
  );

  /// Small and fast for quick, low-cost model calls or thumbnails.
  static const CapturePreset compact = CapturePreset(
    maxDimension: 768,
    jpegQuality: 75,
    stripMetadata: true,
  );

  /// Longest side of the output in pixels. Null keeps the captured size.
  final int? maxDimension;

  /// JPEG quality from 1 to 100.
  final int jpegQuality;

  /// Width / height of a centered crop. Null lets the camera view decide
  /// (the framing overlay or the visible preview), or skips cropping when
  /// used with the controller directly.
  ///
  /// The ratio follows the photo's orientation: 3/4 on a landscape photo
  /// becomes 4/3.
  final double? cropAspectRatio;

  /// Mirror front-camera photos so they match what the user saw.
  final bool mirrorFrontCamera;

  /// Remove EXIF data such as GPS location, device model and timestamps.
  final bool stripMetadata;

  CapturePreset copyWith({
    int? maxDimension,
    int? jpegQuality,
    double? cropAspectRatio,
    bool? mirrorFrontCamera,
    bool? stripMetadata,
  }) {
    return CapturePreset(
      maxDimension: maxDimension ?? this.maxDimension,
      jpegQuality: jpegQuality ?? this.jpegQuality,
      cropAspectRatio: cropAspectRatio ?? this.cropAspectRatio,
      mirrorFrontCamera: mirrorFrontCamera ?? this.mirrorFrontCamera,
      stripMetadata: stripMetadata ?? this.stripMetadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CapturePreset &&
      other.maxDimension == maxDimension &&
      other.jpegQuality == jpegQuality &&
      other.cropAspectRatio == cropAspectRatio &&
      other.mirrorFrontCamera == mirrorFrontCamera &&
      other.stripMetadata == stripMetadata;

  @override
  int get hashCode => Object.hash(
    maxDimension,
    jpegQuality,
    cropAspectRatio,
    mirrorFrontCamera,
    stripMetadata,
  );
}
