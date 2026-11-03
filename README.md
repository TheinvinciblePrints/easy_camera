# EasyCamera

[![CI](https://github.com/TheinvinciblePrints/easy_camera/actions/workflows/ci.yml/badge.svg)](https://github.com/TheinvinciblePrints/easy_camera/actions/workflows/ci.yml)

A native Flutter camera with **CameraX** on Android and **AVFoundation** on iOS. It does not depend on `package:camera`. It ships customizable controls, framing guides and a review step, and it produces **AI-ready captures**: photos are rotated, cropped, resized, compressed and stripped of metadata on the device, then handed to you as bytes ready for a vision model.

## Features
- Native camera on both platforms, with no third-party camera dependencies
- One-line full-screen capture: `EasyCamera.capture(context)`
- Tap to focus and expose, pinch zoom, zoom chips (0.5x / 1x / 2x / 5x), flash and torch
- Front and back camera switching with correct mirroring
- Framing guides (a plate circle or a label rectangle) with a matching crop
- Review screen with retake / use photo
- **AI-ready output:** capture presets sized for vision models, base64 / data URI helpers, and ready-made payloads for Claude, OpenAI and Gemini
- **Pluggable analysis:** pass an `ImageAnalyzer` and its result appears on the review screen
- `EasyCameraController` for fully custom camera UIs
- Permission handling built in, including an "Open Settings" path
- App lifecycle handled: the camera pauses in the background and resumes on return

## Installation

```yaml
dependencies:
  flutter_easy_camera: ^1.0.0
```

### iOS
Minimum iOS 15. Add a camera usage description to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Take photos of your meals to estimate calories.</string>
```

### Android
Minimum SDK 23. The `CAMERA` permission is added by the plugin's manifest.

## Quick start

```dart
import 'package:flutter_easy_camera/flutter_easy_camera.dart';

final EasyCaptureResult? photo = await EasyCamera.capture(context);
if (photo != null) {
  print('${photo.width}x${photo.height}, ${photo.sizeInBytes} bytes at ${photo.path}');
}
```

## Using it in an AI calorie app

`CameraConfig.food()` turns on a plate guide, crops photos to it, and uses `CapturePreset.food`. That preset caps the long side at 1568 px (the size Claude's vision models use without resizing), uses JPEG quality 85, and strips EXIF/GPS. Uploads stay small and fast, and no location leaves the device.

```dart
class Meal {
  Meal({required this.name, required this.calories});
  factory Meal.fromJson(Map<String, dynamic> json) =>
      Meal(name: json['name'], calories: json['calories']);
  final String name;
  final int calories;
}

class MealAnalyzer extends ImageAnalyzer<Meal> {
  @override
  Future<Meal> analyze(EasyCaptureResult capture) async {
    // Call YOUR backend. Keep model API keys on the server, never in the app.
    final response = await http.post(
      Uri.parse('https://api.example.com/meals/analyze'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'image': capture.toClaudeImageBlock()}),
    );
    return Meal.fromJson(jsonDecode(response.body));
  }
}

final result = await EasyCamera.captureAndAnalyze<Meal>(
  context,
  config: const CameraConfig.food(),
  analyzer: MealAnalyzer(),
  resultBuilder: (context, meal) => Text('${meal.name}: ~${meal.calories} kcal'),
);
if (result != null) {
  final (photo, meal) = result; // meal is null if analysis failed
}
```

Your backend can forward the block straight into a Claude Messages API request:

```json
{
  "model": "claude-sonnet-5-5",
  "max_tokens": 1024,
  "messages": [{
    "role": "user",
    "content": [
      <the image block from toClaudeImageBlock()>,
      {"type": "text", "text": "Identify each food and estimate calories. Reply as JSON: {\"name\": string, \"calories\": number}"}
    ]
  }]
}
```

### Payload helpers on `EasyCaptureResult`

| Method | Output |
|---|---|
| `bytes` | Raw JPEG `Uint8List` (for multipart uploads) |
| `toBase64()` | Base64 string |
| `toDataUri()` | `data:image/jpeg;base64,...` |
| `toClaudeImageBlock()` | `{"type": "image", "source": {"type": "base64", ...}}` |
| `toOpenAIImagePart()` | `{"type": "image_url", "image_url": {"url": "data:..."}}` |
| `toGeminiInlineData()` | `{"inline_data": {"mime_type": ..., "data": ...}}` |
| `toJson()` | Metadata only (size, lens, timestamp) |

### Capture presets

| Preset | Long side | Quality | Metadata |
|---|---|---|---|
| `CapturePreset.original` | full sensor | 95 | kept |
| `CapturePreset.food` | 1568 px | 85 | stripped |
| `CapturePreset.document` | 2048 px | 90 | stripped |
| `CapturePreset.compact` | 768 px | 75 | stripped |

Or make your own: `CapturePreset(maxDimension: 1024, jpegQuality: 80, cropAspectRatio: 4 / 3, stripMetadata: true)`.

## The camera view

`EasyCameraView` is the full-screen camera behind `EasyCamera.capture`. Use it directly to embed it in your own route:

```dart
EasyCameraView(
  config: const CameraConfig(
    initialLens: CameraLens.back,
    resolution: ResolutionPreset.veryHigh,
    capturePreset: CapturePreset.compact,
    framingOverlay: FramingOverlay.label,
    showReview: false,
  ),
  onCapture: (photo) => Navigator.pop(context, photo),
  overlayBuilder: (context, state) => const Align(
    alignment: Alignment(0, -0.8),
    child: Text('Hold steady', style: TextStyle(color: Colors.white)),
  ),
)
```

### `CameraConfig`

| Option | Default | Description |
|---|---|---|
| `initialLens` | `back` | `front`, `back` or `external` |
| `resolution` | `high` | `low`, `medium`, `high`, `veryHigh`, `max` |
| `initialFlashMode` | `off` | `off`, `auto`, `on`, `torch` |
| `previewFit` | `cover` | `cover` fills the screen, `contain` letterboxes |
| `capturePreset` | `original` | Native post-processing, see above |
| `cropToPreview` | `true` | Crop photos to what a `cover` preview shows |
| `framingOverlay` | `null` | `FramingOverlay.plate`, `.label` or custom |
| `showControls` | `true` | Master switch for built-in controls |
| `showCaptureButton`, `showFlashButton`, `showSwitchCameraButton`, `showCloseButton`, `showZoomSelector` | `true` | Individual controls |
| `enableTapToFocus`, `enablePinchZoom`, `enableHaptics` | `true` | Interactions |
| `showReview` | `true` | Retake / use photo screen (shows analysis when an analyzer is set) |
| `focusColor` | white | Color of the focus ring |
| `captureButton`, `switchCameraButton`, `closeButton`, `flashButtonBuilder` | `null` | Custom widgets |

Replace the controls completely with `controlsBuilder`, or the permission screen with `permissionBuilder`.

## Custom UI with the controller

```dart
final controller = EasyCameraController(initialLens: CameraLens.back);
await controller.initialize();

// In build():
ValueListenableBuilder<EasyCameraState>(
  valueListenable: controller,
  builder: (context, state, _) => Stack(children: [
    EasyCameraPreview(
      controller: controller,
      onTap: (point, _) => controller.focusAt(point),
    ),
    if (state.isReady)
      TakePhotoButton(onTap: () async {
        final photo = await controller.takePicture(preset: CapturePreset.food);
      }),
  ]),
);

// Also available: switchCamera(), setLens(), setFlashMode(), cycleFlashMode(),
// setZoom(), setExposureOffset(), pausePreview(), resumePreview(), dispose().
```

`EasyCameraState` exposes `status` (`ready`, `permissionDenied`, `error`, ...), `permission`, `cameras`, `lens`, `flashMode`, `hasFlash`, `zoom` and its range, the exposure range, `deviceOrientation`, `isCapturing` and `error`.

## Permissions

The controller asks for camera access on `initialize()`. To handle it yourself:

```dart
final status = await EasyCamera.checkPermission();
if (status == CameraPermissionStatus.permanentlyDenied) {
  await EasyCamera.openAppSettings();
}
```

## Migrating from 0.0.x

1.0.0 replaces `package:camera` with native code, and the API changed:

| 0.0.x | 1.0.0 |
|---|---|
| `await EasyCamera.initialize()` | Not needed (use `EasyCamera.debugLogging = true` for logs) |
| `EasyCamera.cameraView(config:, onCapture:)` | `EasyCameraView(config:, onCapture:)` or `EasyCamera.capture(context)` |
| `onCapture: (XFile? file)` | `onCapture: (EasyCaptureResult photo)` (`photo.path`, `photo.bytes`) |
| `ImageResolution` | `ResolutionPreset` |
| `CameraType.front / rear` | `CameraLens.front / back` |
| `CameraFlashType.always` | `CameraFlashMode.on` (plus `torch`) |
| `CameraPreviewSize.fill / normal` | `PreviewFit.cover / contain` |
| `showImagePreview` | `showReview` |
| `showCaptureIcon`, `showFlashControl`, `showCameraSwitchIcon`, `showCloseIcon` | `showCaptureButton`, `showFlashButton`, `showSwitchCameraButton`, `showCloseButton` |
| `captureIcon`, `cameraSwitchIcon`, `closeIcon`, `flashControlBuilder` | `captureButton`, `switchCameraButton`, `closeButton`, `flashButtonBuilder` |
| `minAvailableZoom`, `maxAvailableZoom` | Read from the device automatically |
| `package:camera` exports (`XFile`, `CameraController`, ...) | Removed |

The default lens is now `back` (it was `front`). `package:flutter_easy_camera/easy_camera.dart` still works as an import.

## Development

The native bridge is generated with [Pigeon](https://pub.dev/packages/pigeon) from `pigeons/messages.dart`:

```bash
dart run pigeon --input pigeons/messages.dart
```

Bump Pigeon deliberately: change the pinned version in `pubspec.yaml`, regenerate, and commit the output. CI fails if the generated files are stale.

To build the example with Swift Package Manager, clone the repo into a folder named `flutter_easy_camera`. SwiftPM rejects the example's local plugin package when the folder name differs from the plugin name. Apps that install the package from pub.dev are not affected.

## License
MIT
