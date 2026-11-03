# Changelog

## [1.0.0] - 2026-10-27
### Breaking
- Replaced `package:camera` with a native implementation: CameraX on Android and AVFoundation on iOS. The package is a Flutter plugin again.
- Removed the `camera`, `image_editor`, `native_device_orientation` and `photo_view` dependencies, and the re-export of `package:camera`.
- `onCapture` now receives an `EasyCaptureResult` instead of an `XFile`.
- `EasyCamera.initialize()` and `EasyCamera.cameraView()` are gone. Use `EasyCameraView`, `EasyCamera.capture()` or `EasyCameraController`.
- Renamed enums and `CameraConfig` fields (see the migration table in the README). The default lens is now `back`.
- Minimum iOS 15 and Android SDK 23.

### Added
- `EasyCameraController` for custom UIs, with `EasyCameraState`.
- `EasyCamera.capture()` and `EasyCamera.captureAndAnalyze()` one-liners.
- Native post-processing through `CapturePreset`: rotation, front-camera mirroring, crop, resize, JPEG quality and metadata stripping. Includes `food`, `document` and `compact` presets for vision models.
- AI payload helpers on `EasyCaptureResult`: `toBase64()`, `toDataUri()`, `toClaudeImageBlock()`, `toOpenAIImagePart()`, `toGeminiInlineData()`, `toJson()`.
- `ImageAnalyzer<T>` for plugging in your own analysis (for example a calorie estimate); results appear on the review screen.
- `CameraConfig.food()` preset, `FramingOverlay` guides (`plate`, `label`) with a matching crop.
- Torch mode, zoom chips, pinch zoom on both platforms, exposure compensation and a new review screen.
- Permission handling with a built-in "allow camera" / "Open Settings" screen.
- Unit and widget tests against a fake platform.

## [0.0.7] - 2025-04-04
### Changed
- Converted package from a Flutter plugin to a normal Dart package.
- Removed unused native code for Android and iOS.
- Updated `pubspec.yaml` to remove unnecessary platform dependencies.
- Cleaned up project structure by deleting `android/`, `ios/`, `macos/`, `windows/`, and `linux/` directories.
- Updated README to reflect changes and clarify package scope.

### Fixed
- Avoids unnecessary native compilation and linking, reducing app build size and maintenance effort.

## [0.0.1] - 2025-03-28
### Added
- Initial release of `flutter_easy_camera` package.
- Basic camera preview wrapper and image capture functionality.
- Customizable camera settings (flash, camera switch, resolution, etc.).

