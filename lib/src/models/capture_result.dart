import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'camera_enums.dart';

/// A processed photo, ready to display, store or send to a vision model.
@immutable
class EasyCaptureResult {
  const EasyCaptureResult({
    required this.path,
    required this.bytes,
    required this.width,
    required this.height,
    required this.lens,
    required this.capturedAt,
  });

  /// Location of the JPEG in the app's cache directory. Move it somewhere
  /// permanent if you need to keep it.
  final String path;

  /// The encoded JPEG.
  final Uint8List bytes;

  final int width;
  final int height;

  /// Camera that took the photo.
  final CameraLens lens;

  final DateTime capturedAt;

  File get file => File(path);

  String get mimeType => 'image/jpeg';

  int get sizeInBytes => bytes.lengthInBytes;

  double get aspectRatio => width / height;

  /// The JPEG as a base64 string.
  String toBase64() => base64Encode(bytes);

  /// The JPEG as a `data:` URI.
  String toDataUri() => 'data:$mimeType;base64,${toBase64()}';

  /// An image content block for the Claude Messages API:
  /// `{"type": "image", "source": {"type": "base64", ...}}`.
  ///
  /// Put it in a user message's `content` list next to a text block with
  /// your prompt.
  Map<String, Object> toClaudeImageBlock() => <String, Object>{
    'type': 'image',
    'source': <String, Object>{
      'type': 'base64',
      'media_type': mimeType,
      'data': toBase64(),
    },
  };

  /// An image part for OpenAI-style chat APIs:
  /// `{"type": "image_url", "image_url": {"url": "data:..."}}`.
  Map<String, Object> toOpenAIImagePart() => <String, Object>{
    'type': 'image_url',
    'image_url': <String, Object>{'url': toDataUri()},
  };

  /// An inline data part for the Gemini API:
  /// `{"inline_data": {"mime_type": ..., "data": ...}}`.
  Map<String, Object> toGeminiInlineData() => <String, Object>{
    'inline_data': <String, Object>{'mime_type': mimeType, 'data': toBase64()},
  };

  /// Metadata about the capture, without the image itself. Handy for logging
  /// or sending alongside a multipart upload.
  Map<String, Object> toJson() => <String, Object>{
    'path': path,
    'mimeType': mimeType,
    'width': width,
    'height': height,
    'sizeInBytes': sizeInBytes,
    'lens': lens.name,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
  };

  /// Deletes the file from the cache.
  Future<void> delete() async {
    final File f = file;
    if (await f.exists()) {
      await f.delete();
    }
  }

  @override
  String toString() =>
      'EasyCaptureResult(${width}x$height, $sizeInBytes bytes, $path)';
}
