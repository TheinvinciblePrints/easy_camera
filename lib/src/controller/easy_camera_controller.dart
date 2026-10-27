import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../logger.dart';
import '../models/camera_description.dart';
import '../models/camera_enums.dart';
import '../models/camera_exception.dart';
import '../models/capture_preset.dart';
import '../models/capture_result.dart';
import '../platform/camera_platform.dart';
import '../platform/mappers.dart';
import '../platform/messages.g.dart';
import 'easy_camera_state.dart';

/// Drives the native camera. Listen to it (it is a [ValueNotifier]) to
/// rebuild UI, or hand it to `EasyCameraView` / `EasyCameraPreview`.
///
/// ```dart
/// final controller = EasyCameraController(initialLens: CameraLens.back);
/// await controller.initialize();
/// final photo = await controller.takePicture(preset: CapturePreset.food);
/// ```
///
/// The controller pauses the camera when the app goes to the background and
/// resumes it on return. Call [dispose] when done.
class EasyCameraController extends ValueNotifier<EasyCameraState>
    with WidgetsBindingObserver {
  EasyCameraController({
    this.initialLens = CameraLens.back,
    this.resolution = ResolutionPreset.high,
    this.initialFlashMode = CameraFlashMode.off,
    this.requestPermissionOnInit = true,
    CameraPlatform? platform,
  }) : _platform = platform ?? CameraPlatform.instance,
       super(const EasyCameraState());

  /// Lens opened by [initialize]. Falls back to any available camera.
  final CameraLens initialLens;

  final ResolutionPreset resolution;

  final CameraFlashMode initialFlashMode;

  /// Show the system permission prompt from [initialize] if needed.
  final bool requestPermissionOnInit;

  final CameraPlatform _platform;
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];
  bool _disposed = false;
  bool _observing = false;

  /// Asks for permission if needed and opens the camera.
  ///
  /// Never throws: inspect [EasyCameraState.status] and
  /// [EasyCameraState.error] instead.
  Future<void> initialize() async {
    if (_disposed) return;
    _update(
      value.copyWith(status: CameraStatus.initializing, clearError: true),
    );
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
      _listenToPlatform();
    }

    try {
      CameraPermissionStatus permission =
          (await _platform.checkPermission()).toStatus();
      if (permission != CameraPermissionStatus.granted &&
          permission != CameraPermissionStatus.permanentlyDenied &&
          requestPermissionOnInit) {
        permission = (await _platform.requestPermission()).toStatus();
      }
      if (permission != CameraPermissionStatus.granted) {
        _update(
          value.copyWith(
            status: CameraStatus.permissionDenied,
            permission: permission,
          ),
        );
        return;
      }

      final List<EasyCameraDescription> cameras =
          (await _platform.availableCameras())
              .map((PlatformCameraInfo c) => c.toDescription())
              .toList();
      if (cameras.isEmpty) {
        throw const EasyCameraException(
          'camera_not_found',
          'This device has no camera.',
        );
      }
      _update(value.copyWith(permission: permission, cameras: cameras));

      final EasyCameraDescription target = cameras.firstWhere(
        (EasyCameraDescription c) => c.lens == initialLens,
        orElse: () => cameras.first,
      );
      await _open(target);
      if (initialFlashMode != CameraFlashMode.off) {
        await setFlashMode(initialFlashMode);
      }
    } on PlatformException catch (e) {
      _fail(EasyCameraException.fromPlatform(e));
    } on EasyCameraException catch (e) {
      _fail(e);
    }
  }

  /// Shows the system permission prompt, then opens the camera if granted.
  Future<CameraPermissionStatus> requestPermission() async {
    final CameraPermissionStatus status =
        (await _platform.requestPermission()).toStatus();
    _update(value.copyWith(permission: status));
    if (status == CameraPermissionStatus.granted && !value.isReady) {
      await initialize();
    }
    return status;
  }

  /// Opens this app's page in the system settings.
  Future<bool> openAppSettings() => _platform.openAppSettings();

  /// Switches between front and back cameras.
  Future<void> switchCamera() async {
    final CameraLens? current = value.lens;
    final EasyCameraDescription? next =
        value.cameras
            .where((EasyCameraDescription c) => c.lens != current)
            .firstOrNull;
    if (next != null) {
      await _guard(() => _open(next));
    }
  }

  /// Opens the first camera facing [lens].
  Future<void> setLens(CameraLens lens) async {
    final EasyCameraDescription? camera =
        value.cameras
            .where((EasyCameraDescription c) => c.lens == lens)
            .firstOrNull;
    if (camera != null && camera != value.camera) {
      await _guard(() => _open(camera));
    }
  }

  Future<void> setFlashMode(CameraFlashMode mode) async {
    if (!value.isReady) return;
    if (!value.hasFlash && mode != CameraFlashMode.off) return;
    await _guard(() async {
      await _platform.setFlashMode(mode.toPlatform());
      _update(value.copyWith(flashMode: mode));
    });
  }

  /// Moves to the next flash mode: off, auto, on, torch, then off again.
  Future<CameraFlashMode> cycleFlashMode() async {
    const List<CameraFlashMode> order = CameraFlashMode.values;
    final CameraFlashMode next =
        order[(order.indexOf(value.flashMode) + 1) % order.length];
    await setFlashMode(next);
    return value.flashMode;
  }

  /// Sets the zoom ratio, clamped to the camera's range.
  Future<void> setZoom(double zoom) async {
    if (!value.isReady) return;
    final double clamped = zoom.clamp(value.minZoom, value.maxZoom);
    if (clamped == value.zoom) return;
    _update(value.copyWith(zoom: clamped));
    await _guard(() => _platform.setZoom(clamped));
  }

  /// Focuses and meters at [point], given in normalized (0..1) coordinates of
  /// the preview as displayed.
  Future<void> focusAt(Offset point) async {
    if (!value.isReady) return;
    await _guard(
      () => _platform.setFocusPoint(
        point.dx.clamp(0.0, 1.0),
        point.dy.clamp(0.0, 1.0),
      ),
    );
  }

  /// Exposure compensation in EV, clamped to the camera's range.
  Future<void> setExposureOffset(double offset) async {
    if (!value.isReady) return;
    final double clamped = offset.clamp(
      value.minExposureOffset,
      value.maxExposureOffset,
    );
    _update(value.copyWith(exposureOffset: clamped));
    await _guard(() => _platform.setExposureOffset(clamped));
  }

  /// Takes a photo and processes it natively according to [preset].
  ///
  /// [cropAspectRatio] overrides the preset's crop for this shot.
  Future<EasyCaptureResult> takePicture({
    CapturePreset preset = CapturePreset.original,
    double? cropAspectRatio,
  }) async {
    if (!value.isReady) {
      throw const EasyCameraException(
        'camera_not_open',
        'Camera is not ready.',
      );
    }
    if (value.isCapturing) {
      throw const EasyCameraException(
        'capture_in_progress',
        'A photo is already being taken.',
      );
    }
    _update(value.copyWith(isCapturing: true));
    try {
      final PlatformCaptureResult result = await _platform.takePicture(
        PlatformCaptureOptions(
          maxDimension: preset.maxDimension,
          jpegQuality: preset.jpegQuality,
          cropAspectRatio: cropAspectRatio ?? preset.cropAspectRatio,
          mirrorFront: preset.mirrorFrontCamera,
          stripMetadata: preset.stripMetadata,
          includeBytes: true,
        ),
      );
      return EasyCaptureResult(
        path: result.path,
        bytes: result.bytes ?? Uint8List(0),
        width: result.width,
        height: result.height,
        lens: result.lens.toLens(),
        capturedAt: DateTime.fromMillisecondsSinceEpoch(result.timestampMs),
      );
    } on PlatformException catch (e) {
      final EasyCameraException error = EasyCameraException.fromPlatform(e);
      _update(value.copyWith(error: error));
      throw error;
    } finally {
      _update(value.copyWith(isCapturing: false));
    }
  }

  /// Stops the preview without releasing the camera.
  Future<void> pausePreview() async {
    if (!value.isReady || value.isPaused) return;
    _update(value.copyWith(isPaused: true));
    await _guard(_platform.pausePreview);
  }

  Future<void> resumePreview() async {
    if (!value.isReady || !value.isPaused) return;
    _update(value.copyWith(isPaused: false));
    await _guard(_platform.resumePreview);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        pausePreview();
      case AppLifecycleState.resumed:
        if (value.isReady) {
          resumePreview();
        } else if (value.status == CameraStatus.permissionDenied) {
          // The user may have granted access in settings.
          _recheckPermission();
        }
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
    }
    for (final StreamSubscription<Object?> s in _subscriptions) {
      s.cancel();
    }
    _platform.close().catchError((Object e) => logError('$e', 'close'));
    super.dispose();
  }

  Future<void> _open(EasyCameraDescription camera) async {
    final PlatformCameraDescription opened = await _platform.open(
      camera.id,
      resolution.toPlatform(),
    );
    _update(
      value.copyWith(
        status: CameraStatus.ready,
        camera: camera,
        textureId: opened.textureId,
        preview: opened.preview.toPreviewInfo(),
        hasFlash: opened.hasFlash,
        flashMode: CameraFlashMode.off,
        zoom: opened.minZoom,
        minZoom: opened.minZoom,
        maxZoom: opened.maxZoom,
        exposureOffset: 0,
        minExposureOffset: opened.minExposureOffset,
        maxExposureOffset: opened.maxExposureOffset,
        isPaused: false,
        clearError: true,
      ),
    );
  }

  Future<void> _recheckPermission() async {
    final CameraPermissionStatus status =
        (await _platform.checkPermission()).toStatus();
    if (status == CameraPermissionStatus.granted) {
      await initialize();
    }
  }

  void _listenToPlatform() {
    _subscriptions
      ..add(
        _platform.deviceOrientationChanges.listen(
          (PlatformDeviceOrientation o) => _update(
            value.copyWith(deviceOrientation: o.toDeviceOrientation()),
          ),
        ),
      )
      ..add(
        _platform.previewChanges.listen(
          (PlatformPreviewInfo p) =>
              _update(value.copyWith(preview: p.toPreviewInfo())),
        ),
      )
      ..add(
        _platform.errors.listen(((String, String) e) {
          logError(e.$2, e.$1);
          _update(value.copyWith(error: EasyCameraException(e.$1, e.$2)));
        }),
      );
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on PlatformException catch (e) {
      final EasyCameraException error = EasyCameraException.fromPlatform(e);
      logError('${error.message}', error.code);
      _update(value.copyWith(error: error));
    }
  }

  void _fail(EasyCameraException error) {
    logError('${error.message}', error.code);
    _update(
      value.copyWith(
        status:
            error.code == 'permission_denied'
                ? CameraStatus.permissionDenied
                : CameraStatus.error,
        error: error,
      ),
    );
  }

  void _update(EasyCameraState next) {
    if (!_disposed) value = next;
  }
}
