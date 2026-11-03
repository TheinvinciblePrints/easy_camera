// Pigeon schema for the native camera bridge.
//
// Regenerate with:
//   dart run pigeon --input pigeons/messages.dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/platform/messages.g.dart',
    kotlinOut:
        'android/src/main/kotlin/com/codewithemmany/flutter_easy_camera/Messages.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.codewithemmany.flutter_easy_camera',
    ),
    swiftOut:
        'ios/flutter_easy_camera/Sources/flutter_easy_camera/Messages.g.swift',
  ),
)
enum PlatformLens { front, back, external }

enum PlatformFlashMode { off, auto, on, torch }

enum PlatformResolution { low, medium, high, veryHigh, max }

enum PlatformPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  notDetermined,
}

enum PlatformDeviceOrientation {
  portraitUp,
  landscapeLeft,
  portraitDown,
  landscapeRight,
}

class PlatformCameraInfo {
  PlatformCameraInfo({
    required this.id,
    required this.lens,
    required this.sensorOrientation,
    required this.hasFlash,
  });

  String id;
  PlatformLens lens;
  int sensorOrientation;
  bool hasFlash;
}

class PlatformCaptureOptions {
  PlatformCaptureOptions({
    this.maxDimension,
    required this.jpegQuality,
    this.cropAspectRatio,
    required this.mirrorFront,
    required this.stripMetadata,
    required this.includeBytes,
  });

  /// Longest side of the output image in pixels. Null keeps the sensor size.
  int? maxDimension;

  /// JPEG quality from 1 to 100.
  int jpegQuality;

  /// Width / height of a centered crop applied after rotation. Null skips it.
  double? cropAspectRatio;

  /// Mirror front-camera shots so they match the preview.
  bool mirrorFront;

  /// Drop EXIF/GPS metadata from the output file.
  bool stripMetadata;

  /// Return the encoded JPEG bytes along with the file path.
  bool includeBytes;
}

/// How the native preview buffer must be drawn to appear upright.
class PlatformPreviewInfo {
  PlatformPreviewInfo({
    required this.width,
    required this.height,
    required this.rotationDegrees,
    required this.mirror,
  });

  /// Buffer size before [rotationDegrees] is applied.
  double width;
  double height;

  /// Clockwise rotation (0, 90, 180 or 270) to apply to the buffer.
  int rotationDegrees;

  /// Whether to flip horizontally after rotating (front cameras).
  bool mirror;
}

class PlatformCameraDescription {
  PlatformCameraDescription({
    required this.textureId,
    required this.preview,
    required this.minZoom,
    required this.maxZoom,
    required this.minExposureOffset,
    required this.maxExposureOffset,
    required this.hasFlash,
  });

  int textureId;
  PlatformPreviewInfo preview;
  double minZoom;
  double maxZoom;
  double minExposureOffset;
  double maxExposureOffset;
  bool hasFlash;
}

class PlatformCaptureResult {
  PlatformCaptureResult({
    required this.path,
    this.bytes,
    required this.width,
    required this.height,
    required this.lens,
    required this.timestampMs,
  });

  String path;
  Uint8List? bytes;
  int width;
  int height;
  PlatformLens lens;
  int timestampMs;
}

@HostApi()
abstract class CameraHostApi {
  @async
  PlatformPermissionStatus checkPermission();

  @async
  PlatformPermissionStatus requestPermission();

  bool openAppSettings();

  @async
  List<PlatformCameraInfo> availableCameras();

  /// Opens [cameraId] and starts the preview. Any previously opened camera is
  /// closed first.
  @async
  PlatformCameraDescription open(
    String cameraId,
    PlatformResolution resolution,
  );

  @async
  void setFlashMode(PlatformFlashMode mode);

  @async
  void setZoom(double zoom);

  /// [x] and [y] are normalized (0..1) in preview coordinates.
  @async
  void setFocusPoint(double x, double y);

  @async
  void setExposureOffset(double offset);

  @async
  PlatformCaptureResult takePicture(PlatformCaptureOptions options);

  @async
  void pausePreview();

  @async
  void resumePreview();

  @async
  void close();
}

@FlutterApi()
abstract class CameraFlutterApi {
  void onDeviceOrientationChanged(PlatformDeviceOrientation orientation);

  void onPreviewChanged(PlatformPreviewInfo preview);

  void onError(String code, String message);

  void onClosed();
}
