import 'package:flutter/material.dart';

import 'models/camera_enums.dart';
import 'models/capture_preset.dart';
import 'widgets/framing_overlay.dart';

/// Builds a custom flash button for the current [mode].
typedef FlashControlBuilder =
    Widget Function(BuildContext context, CameraFlashMode mode);

/// Settings for `EasyCameraView`.
@immutable
class CameraConfig {
  const CameraConfig({
    this.initialLens = CameraLens.back,
    this.resolution = ResolutionPreset.high,
    this.initialFlashMode = CameraFlashMode.off,
    this.previewFit = PreviewFit.cover,
    this.capturePreset = CapturePreset.original,
    this.cropToPreview = true,
    this.framingOverlay,
    this.showControls = true,
    this.showCaptureButton = true,
    this.showFlashButton = true,
    this.showSwitchCameraButton = true,
    this.showCloseButton = true,
    this.showZoomSelector = true,
    this.enableTapToFocus = true,
    this.enablePinchZoom = true,
    this.enableHaptics = true,
    this.showReview = true,
    this.focusColor = Colors.white,
    this.captureButton,
    this.switchCameraButton,
    this.closeButton,
    this.flashButtonBuilder,
  });

  /// Preset for snapping meals for a calorie or nutrition app: a plate guide,
  /// AI-sized captures with metadata stripped, and a review step.
  const CameraConfig.food({
    CameraLens initialLens = CameraLens.back,
    CapturePreset capturePreset = CapturePreset.food,
    FramingOverlay? framingOverlay = FramingOverlay.plate,
    bool showReview = true,
    bool enableHaptics = true,
  }) : this(
         initialLens: initialLens,
         resolution: ResolutionPreset.veryHigh,
         capturePreset: capturePreset,
         framingOverlay: framingOverlay,
         showReview: showReview,
         enableHaptics: enableHaptics,
       );

  final CameraLens initialLens;
  final ResolutionPreset resolution;
  final CameraFlashMode initialFlashMode;
  final PreviewFit previewFit;

  /// Native post-processing applied to every capture.
  final CapturePreset capturePreset;

  /// Crop photos to what the preview shows when [previewFit] is
  /// [PreviewFit.cover], so the result matches what the user framed.
  /// Ignored when the preset or [framingOverlay] sets a crop.
  final bool cropToPreview;

  /// Optional guide drawn over the preview, such as a plate outline.
  final FramingOverlay? framingOverlay;

  /// Master switch for all built-in controls.
  final bool showControls;
  final bool showCaptureButton;
  final bool showFlashButton;
  final bool showSwitchCameraButton;
  final bool showCloseButton;

  /// Quick zoom chips such as 1x and 2x.
  final bool showZoomSelector;

  final bool enableTapToFocus;
  final bool enablePinchZoom;

  /// Light haptic feedback on capture.
  final bool enableHaptics;

  /// Show the photo, and the analysis if an analyzer is set, before handing
  /// it back. The user can retake or accept.
  final bool showReview;

  /// Color of the tap-to-focus ring.
  final Color focusColor;

  final Widget? captureButton;
  final Widget? switchCameraButton;
  final Widget? closeButton;
  final FlashControlBuilder? flashButtonBuilder;
}
