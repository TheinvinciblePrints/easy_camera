import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../analysis/image_analyzer.dart';
import '../camera_config.dart';
import '../controller/easy_camera_controller.dart';
import '../controller/easy_camera_state.dart';
import '../logger.dart';
import '../models/camera_enums.dart';
import '../models/camera_exception.dart';
import '../models/capture_result.dart';
import 'capture_review_screen.dart';
import 'easy_camera_preview.dart';
import 'flash_icon.dart';
import 'focus_indicator.dart';
import 'framing_overlay.dart';
import 'switch_camera_icon.dart';
import 'take_photo_button.dart';
import 'zoom_selector.dart';

/// Builds a replacement for the built-in controls. Call [capture] to take a
/// photo through the normal review and analysis flow.
typedef CameraControlsBuilder =
    Widget Function(
      BuildContext context,
      EasyCameraController controller,
      VoidCallback capture,
    );

/// Builds extra UI over the preview, such as tips or a live label.
typedef CameraOverlayBuilder =
    Widget Function(BuildContext context, EasyCameraState state);

/// A full-screen camera with controls, an optional framing guide, a review
/// step and optional AI analysis.
///
/// ```dart
/// EasyCameraView<Meal>(
///   config: const CameraConfig.food(),
///   analyzer: MealAnalyzer(),
///   analysisResultBuilder: (context, meal) => Text('${meal.calories} kcal'),
///   onAnalyzed: (photo, meal) => Navigator.pop(context, meal),
/// )
/// ```
class EasyCameraView<T> extends StatefulWidget {
  const EasyCameraView({
    super.key,
    this.config = const CameraConfig(),
    this.controller,
    this.onCapture,
    this.analyzer,
    this.onAnalyzed,
    this.analysisResultBuilder,
    this.overlayBuilder,
    this.controlsBuilder,
    this.permissionBuilder,
    this.onClose,
  }) : assert(
         onCapture != null || onAnalyzed != null,
         'Provide onCapture, onAnalyzed or both.',
       );

  final CameraConfig config;

  /// Supply your own controller to drive the camera from outside. Otherwise
  /// the view creates and disposes one using [config].
  final EasyCameraController? controller;

  /// Called with each accepted photo.
  final void Function(EasyCaptureResult capture)? onCapture;

  /// Runs on each photo. With `config.showReview` the result is shown on the
  /// review screen; otherwise a loading overlay is shown while it runs.
  final ImageAnalyzer<T>? analyzer;

  /// Called after [onCapture] when [analyzer] is set. `analysis` is null if
  /// the analyzer failed.
  final void Function(EasyCaptureResult capture, T? analysis)? onAnalyzed;

  /// Renders the analysis on the review screen.
  final Widget Function(BuildContext context, T result)? analysisResultBuilder;

  final CameraOverlayBuilder? overlayBuilder;
  final CameraControlsBuilder? controlsBuilder;

  /// Replaces the default "allow camera access" screen.
  final Widget Function(BuildContext context, EasyCameraController controller)?
  permissionBuilder;

  /// Called by the close button. Defaults to popping the route.
  final VoidCallback? onClose;

  @override
  State<EasyCameraView<T>> createState() => _EasyCameraViewState<T>();
}

class _EasyCameraViewState<T> extends State<EasyCameraView<T>> {
  late EasyCameraController _controller;
  bool _ownsController = false;
  Offset? _focusPoint;
  double _baseZoom = 1;
  Size _previewSize = Size.zero;
  bool _analyzing = false;

  CameraConfig get _config => widget.config;

  @override
  void initState() {
    super.initState();
    _attachController();
  }

  @override
  void didUpdateWidget(EasyCameraView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (_ownsController) _controller.dispose();
      _attachController();
    }
  }

  void _attachController() {
    final EasyCameraController? external = widget.controller;
    _ownsController = external == null;
    _controller =
        external ??
        EasyCameraController(
          initialLens: _config.initialLens,
          resolution: _config.resolution,
          initialFlashMode: _config.initialFlashMode,
        );
    if (_controller.value.status == CameraStatus.uninitialized) {
      _controller.initialize();
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  double? _cropAspectRatio() {
    final double? presetCrop = _config.capturePreset.cropAspectRatio;
    if (presetCrop != null) return presetCrop;
    final FramingOverlay? overlay = _config.framingOverlay;
    if (overlay != null && overlay.cropToFrame) {
      return overlay.effectiveAspectRatio;
    }
    if (_config.cropToPreview &&
        _config.previewFit == PreviewFit.cover &&
        !_previewSize.isEmpty) {
      return _previewSize.width / _previewSize.height;
    }
    return null;
  }

  Future<void> _capture() async {
    if (_controller.value.isCapturing || _analyzing) return;
    if (_config.enableHaptics) unawaited(HapticFeedback.mediumImpact());

    final EasyCaptureResult capture;
    try {
      capture = await _controller.takePicture(
        preset: _config.capturePreset,
        cropAspectRatio: _cropAspectRatio(),
      );
    } on EasyCameraException catch (e) {
      logError('${e.message}', e.code);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(e.message ?? 'Could not take the photo.')),
        );
      }
      return;
    }
    if (!mounted) return;

    if (_config.showReview) {
      await _controller.pausePreview();
      if (!mounted) return;
      final CaptureReviewResult<T>? review = await Navigator.of(context).push(
        MaterialPageRoute<CaptureReviewResult<T>>(
          builder:
              (BuildContext context) => CaptureReviewScreen<T>(
                capture: capture,
                analyzer: widget.analyzer,
                resultBuilder: widget.analysisResultBuilder,
              ),
        ),
      );
      if (!mounted) return;
      if (review == null || !review.accepted) {
        unawaited(capture.delete());
        await _controller.resumePreview();
        return;
      }
      await _controller.resumePreview();
      _deliver(capture, review.analysis);
      return;
    }

    T? analysis;
    final ImageAnalyzer<T>? analyzer = widget.analyzer;
    if (analyzer != null) {
      setState(() => _analyzing = true);
      try {
        analysis = await analyzer.analyze(capture);
      } catch (e) {
        logError('$e', 'analysis_failed');
      }
      if (!mounted) return;
      setState(() => _analyzing = false);
    }
    _deliver(capture, analysis);
  }

  void _deliver(EasyCaptureResult capture, T? analysis) {
    widget.onCapture?.call(capture);
    if (widget.analyzer != null) widget.onAnalyzed?.call(capture, analysis);
  }

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ValueListenableBuilder<EasyCameraState>(
        valueListenable: _controller,
        builder: (BuildContext context, EasyCameraState state, Widget? _) {
          if (state.status == CameraStatus.permissionDenied) {
            return widget.permissionBuilder?.call(context, _controller) ??
                _PermissionView(controller: _controller, onClose: _close);
          }
          if (state.status == CameraStatus.error && !state.isReady) {
            return _ErrorView(
              error: state.error,
              onRetry: _controller.initialize,
              onClose: _close,
            );
          }
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _buildPreview(state),
              if (_config.framingOverlay != null)
                FramingOverlayView(overlay: _config.framingOverlay!),
              FocusIndicator(position: _focusPoint, color: _config.focusColor),
              if (widget.overlayBuilder != null)
                widget.overlayBuilder!(context, state),
              if (_config.showControls)
                widget.controlsBuilder?.call(context, _controller, _capture) ??
                    _buildControls(state),
              if (_analyzing)
                const ColoredBox(
                  color: Colors.black54,
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPreview(EasyCameraState state) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _previewSize = constraints.biggest;
        return GestureDetector(
          onScaleStart:
              _config.enablePinchZoom ? (_) => _baseZoom = state.zoom : null,
          onScaleUpdate:
              _config.enablePinchZoom
                  ? (ScaleUpdateDetails d) {
                    if (d.pointerCount >= 2) {
                      _controller.setZoom(_baseZoom * d.scale);
                    }
                  }
                  : null,
          child: EasyCameraPreview(
            controller: _controller,
            fit: _config.previewFit,
            onTap:
                _config.enableTapToFocus
                    ? (Offset normalized, Offset local) {
                      setState(() => _focusPoint = local);
                      _controller.focusAt(normalized);
                    }
                    : null,
          ),
        );
      },
    );
  }

  Widget _buildControls(EasyCameraState state) {
    final bool ready = state.isReady;
    return SafeArea(
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: <Widget>[
                if (_config.showCloseButton)
                  IconButton(
                    tooltip: 'Close',
                    iconSize: 30,
                    onPressed: _close,
                    icon:
                        _config.closeButton ??
                        CircleAvatar(
                          backgroundColor: Colors.black.withValues(alpha: 0.3),
                          child: const Icon(Icons.close, color: Colors.white),
                        ),
                  ),
                const Spacer(),
                if (_config.showFlashButton && state.hasFlash)
                  CameraFlashIcon(
                    onTap: ready ? _controller.cycleFlashMode : null,
                    flashIcon: _flashIcon(state.flashMode),
                    flashControlBuilder: _config.flashButtonBuilder?.call(
                      context,
                      state.flashMode,
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          if (_config.showZoomSelector && ready)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ZoomSelector(
                zoom: state.zoom,
                minZoom: state.minZoom,
                maxZoom: state.maxZoom,
                onChanged: _controller.setZoom,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const SizedBox(width: 60, height: 60),
                if (_config.showCaptureButton)
                  _config.captureButton != null
                      ? GestureDetector(
                        onTap: ready ? _capture : null,
                        child: _config.captureButton,
                      )
                      : TakePhotoButton(
                        key: const ValueKey<String>('takePhotoButton'),
                        busy: state.isCapturing,
                        onTap: ready && !state.isCapturing ? _capture : null,
                      ),
                if (_config.showSwitchCameraButton && state.canSwitchCamera)
                  CameraSwitchIcon(
                    onTap: ready ? _controller.switchCamera : null,
                    switchCameraIcon: _config.switchCameraButton,
                  )
                else
                  const SizedBox(width: 60, height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _flashIcon(CameraFlashMode mode) => switch (mode) {
    CameraFlashMode.off => Icons.flash_off,
    CameraFlashMode.auto => Icons.flash_auto,
    CameraFlashMode.on => Icons.flash_on,
    CameraFlashMode.torch => Icons.highlight,
  };
}

class _PermissionView extends StatelessWidget {
  const _PermissionView({required this.controller, required this.onClose});

  final EasyCameraController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final bool permanent =
        controller.value.permission == CameraPermissionStatus.permanentlyDenied;
    return _MessageView(
      icon: Icons.no_photography_outlined,
      title: 'Camera access needed',
      message:
          permanent
              ? 'Camera access is turned off for this app. You can turn it on in Settings.'
              : 'Allow camera access to take photos.',
      actionLabel: permanent ? 'Open Settings' : 'Allow camera',
      onAction:
          permanent ? controller.openAppSettings : controller.requestPermission,
      onClose: onClose,
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    required this.onRetry,
    required this.onClose,
  });

  final EasyCameraException? error;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return _MessageView(
      icon: Icons.error_outline,
      title: 'Camera unavailable',
      message: error?.message ?? 'The camera could not be started.',
      actionLabel: 'Try again',
      onAction: onRetry,
      onClose: onClose,
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.onClose,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: <Widget>[
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              tooltip: 'Close',
              onPressed: onClose,
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, color: Colors.white70, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: onAction, child: Text(actionLabel)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
