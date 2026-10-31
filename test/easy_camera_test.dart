import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easy_camera/flutter_easy_camera.dart';
import 'package:flutter_easy_camera/src/platform/camera_platform.dart';
import 'package:flutter_easy_camera/src/platform/messages.g.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_camera_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCameraPlatform platform;

  setUp(() {
    platform = FakeCameraPlatform();
    CameraPlatform.instance = platform;
  });

  group('EasyCameraController', () {
    test('initialize opens the requested lens', () async {
      final EasyCameraController controller = EasyCameraController(
        initialLens: CameraLens.front,
      );
      await controller.initialize();

      expect(controller.value.status, CameraStatus.ready);
      expect(controller.value.lens, CameraLens.front);
      expect(controller.value.textureId, isNotNull);
      expect(controller.value.preview.mirror, isTrue);
      expect(controller.value.preview.quarterTurns, 1);
      expect(controller.value.canSwitchCamera, isTrue);
      expect(platform.calls, contains('open:front1'));
      controller.dispose();
    });

    test('initialize requests permission when not determined', () async {
      platform.permission = PlatformPermissionStatus.notDetermined;
      final EasyCameraController controller = EasyCameraController();
      await controller.initialize();

      expect(platform.calls, contains('requestPermission'));
      expect(controller.value.status, CameraStatus.ready);
      controller.dispose();
    });

    test('denied permission leaves the camera closed', () async {
      platform
        ..permission = PlatformPermissionStatus.notDetermined
        ..permissionAfterRequest = PlatformPermissionStatus.denied;
      final EasyCameraController controller = EasyCameraController();
      await controller.initialize();

      expect(controller.value.status, CameraStatus.permissionDenied);
      expect(controller.value.permission, CameraPermissionStatus.denied);
      expect(platform.calls.where((String c) => c.startsWith('open')), isEmpty);
      controller.dispose();
    });

    test('permanently denied permission does not prompt again', () async {
      platform.permission = PlatformPermissionStatus.permanentlyDenied;
      final EasyCameraController controller = EasyCameraController();
      await controller.initialize();

      expect(platform.calls, isNot(contains('requestPermission')));
      expect(
        controller.value.permission,
        CameraPermissionStatus.permanentlyDenied,
      );
      controller.dispose();
    });

    test('no cameras reports an error', () async {
      platform = FakeCameraPlatform(cameras: <PlatformCameraInfo>[]);
      final EasyCameraController controller = EasyCameraController(
        platform: platform,
      );
      await controller.initialize();

      expect(controller.value.status, CameraStatus.error);
      expect(controller.value.error?.code, 'camera_not_found');
      controller.dispose();
    });

    test('switchCamera toggles between lenses', () async {
      final EasyCameraController controller = EasyCameraController();
      await controller.initialize();
      expect(controller.value.lens, CameraLens.back);

      await controller.switchCamera();
      expect(controller.value.lens, CameraLens.front);
      await controller.switchCamera();
      expect(controller.value.lens, CameraLens.back);
      controller.dispose();
    });

    test('cycleFlashMode walks through every mode', () async {
      final EasyCameraController controller = EasyCameraController();
      await controller.initialize();

      final List<CameraFlashMode> seen = <CameraFlashMode>[
        for (int i = 0; i < 4; i++) await controller.cycleFlashMode(),
      ];
      expect(seen, <CameraFlashMode>[
        CameraFlashMode.auto,
        CameraFlashMode.on,
        CameraFlashMode.torch,
        CameraFlashMode.off,
      ]);
      controller.dispose();
    });

    test('flash is ignored on cameras without one', () async {
      final EasyCameraController controller = EasyCameraController(
        initialLens: CameraLens.front,
      );
      await controller.initialize();
      await controller.setFlashMode(CameraFlashMode.on);

      expect(controller.value.flashMode, CameraFlashMode.off);
      expect(
        platform.calls.where((String c) => c.startsWith('flash')),
        isEmpty,
      );
      controller.dispose();
    });

    test('zoom and exposure are clamped to the camera range', () async {
      final EasyCameraController controller = EasyCameraController();
      await controller.initialize();

      await controller.setZoom(20);
      expect(controller.value.zoom, 8);
      await controller.setZoom(0.1);
      expect(controller.value.zoom, 1);
      await controller.setExposureOffset(5);
      expect(controller.value.exposureOffset, 2);
      controller.dispose();
    });

    test('takePicture forwards the preset and returns the result', () async {
      final EasyCameraController controller = EasyCameraController();
      await controller.initialize();

      final EasyCaptureResult photo = await controller.takePicture(
        preset: CapturePreset.food,
        cropAspectRatio: 1,
      );

      final PlatformCaptureOptions options = platform.lastCaptureOptions!;
      expect(options.maxDimension, 1568);
      expect(options.jpegQuality, 85);
      expect(options.stripMetadata, isTrue);
      expect(options.cropAspectRatio, 1);
      expect(options.includeBytes, isTrue);
      expect(photo.width, 1568);
      expect(photo.lens, CameraLens.back);
      expect(controller.value.isCapturing, isFalse);
      controller.dispose();
    });

    test('takePicture maps platform errors', () async {
      platform.captureError = PlatformException(code: 'capture_failed');
      final EasyCameraController controller = EasyCameraController();
      await controller.initialize();

      await expectLater(
        controller.takePicture(),
        throwsA(
          isA<EasyCameraException>().having(
            (EasyCameraException e) => e.code,
            'code',
            'capture_failed',
          ),
        ),
      );
      expect(controller.value.isCapturing, isFalse);
      controller.dispose();
    });

    test('takePicture before initialize throws', () {
      final EasyCameraController controller = EasyCameraController();
      expect(controller.takePicture, throwsA(isA<EasyCameraException>()));
      controller.dispose();
    });

    test('app lifecycle pauses and resumes the preview', () async {
      final EasyCameraController controller = EasyCameraController();
      await controller.initialize();

      controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await Future<void>.delayed(Duration.zero);
      expect(controller.value.isPaused, isTrue);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(controller.value.isPaused, isFalse);
      expect(platform.calls, containsAllInOrder(<String>['pause', 'resume']));
      controller.dispose();
    });

    test('native events update the state', () async {
      final EasyCameraController controller = EasyCameraController();
      await controller.initialize();

      platform.orientation.add(PlatformDeviceOrientation.landscapeLeft);
      platform.preview.add(
        PlatformPreviewInfo(
          width: 960,
          height: 1280,
          rotationDegrees: 0,
          mirror: false,
        ),
      );
      platform.errorEvents.add(('interrupted', 'Camera interrupted'));
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.value.deviceOrientation,
        DeviceOrientation.landscapeLeft,
      );
      expect(controller.value.preview.width, 960);
      expect(controller.value.error?.code, 'interrupted');
      controller.dispose();
    });

    test('dispose closes the camera', () async {
      final EasyCameraController controller = EasyCameraController();
      await controller.initialize();
      controller.dispose();
      expect(platform.calls.last, 'close');
    });
  });

  group('EasyCaptureResult', () {
    final EasyCaptureResult photo = EasyCaptureResult(
      path: '/tmp/a.jpg',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      width: 400,
      height: 300,
      lens: CameraLens.back,
      capturedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
    );
    final String b64 = base64Encode(<int>[1, 2, 3]);

    test('encodes for data URIs and base64', () {
      expect(photo.toBase64(), b64);
      expect(photo.toDataUri(), 'data:image/jpeg;base64,$b64');
      expect(photo.sizeInBytes, 3);
      expect(photo.aspectRatio, 400 / 300);
    });

    test('builds provider image payloads', () {
      expect(photo.toClaudeImageBlock(), <String, Object>{
        'type': 'image',
        'source': <String, Object>{
          'type': 'base64',
          'media_type': 'image/jpeg',
          'data': b64,
        },
      });
      expect(photo.toOpenAIImagePart(), <String, Object>{
        'type': 'image_url',
        'image_url': <String, Object>{'url': 'data:image/jpeg;base64,$b64'},
      });
      expect(photo.toGeminiInlineData(), <String, Object>{
        'inline_data': <String, Object>{'mime_type': 'image/jpeg', 'data': b64},
      });
    });

    test('toJson has metadata but no image data', () {
      final Map<String, Object> json = photo.toJson();
      expect(json['width'], 400);
      expect(json['lens'], 'back');
      expect(json['capturedAt'], '2026-01-02T03:04:05.000Z');
      expect(json.values, isNot(contains(b64)));
    });
  });

  group('EasyCameraPreview.normalize', () {
    const PreviewInfo portrait = PreviewInfo(
      width: 1280,
      height: 960,
      rotationDegrees: 90,
    );

    test('maps the center to the center', () {
      expect(
        EasyCameraPreview.normalize(
          const Offset(200, 400),
          const Size(400, 800),
          portrait,
          PreviewFit.cover,
        ),
        const Offset(0.5, 0.5),
      );
    });

    test('accounts for the edges cover crops away', () {
      // A 3:4 preview covering a 400x800 box is 600 wide, so 100 px are
      // cropped on each side.
      final Offset left = EasyCameraPreview.normalize(
        Offset.zero,
        const Size(400, 800),
        portrait,
        PreviewFit.cover,
      );
      expect(left.dx, closeTo(100 / 600, 1e-9));
      expect(left.dy, 0);
    });
  });

  group('FramingOverlay', () {
    test('circle frames are square and centered', () {
      final Rect rect = FramingOverlay.plate.frameRect(const Size(400, 800));
      expect(rect.width, rect.height);
      expect(rect.center, const Offset(200, 400));
      expect(FramingOverlay.plate.effectiveAspectRatio, 1);
    });
  });

  group('EasyCameraView', () {
    testWidgets('shows controls when the camera is ready', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: EasyCameraView<void>(onCapture: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Texture), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('takePhotoButton')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.flash_off), findsOneWidget);
      expect(find.text('1x'), findsOneWidget);
    });

    testWidgets('hides controls when disabled', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EasyCameraView<void>(
            config: const CameraConfig(showControls: false),
            onCapture: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('takePhotoButton')),
        findsNothing,
      );
    });

    testWidgets('shows the permission screen when access is denied', (
      WidgetTester tester,
    ) async {
      platform.permission = PlatformPermissionStatus.permanentlyDenied;
      await tester.pumpWidget(
        MaterialApp(home: EasyCameraView<void>(onCapture: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('Camera access needed'), findsOneWidget);
      await tester.tap(find.text('Open Settings'));
      expect(platform.calls, contains('openAppSettings'));
    });

    testWidgets('capture, review and analysis flow', (
      WidgetTester tester,
    ) async {
      String? analysis;
      await tester.pumpWidget(
        MaterialApp(
          home: EasyCameraView<String>(
            config: const CameraConfig.food(enableHaptics: false),
            analyzer: ImageAnalyzer<String>.fromCallback(
              (EasyCaptureResult c) async => '${c.width}px meal',
            ),
            analysisResultBuilder: (BuildContext context, String r) => Text(r),
            onAnalyzed: (EasyCaptureResult c, String? r) => analysis = r,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Fit your whole plate inside the circle'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('takePhotoButton')));
      await tester.pumpAndSettle();

      // The food config crops to the plate guide.
      expect(platform.lastCaptureOptions!.cropAspectRatio, 1);
      expect(platform.calls, contains('pause'));
      expect(find.text('1568px meal'), findsOneWidget);

      await tester.tap(find.text('Use photo'));
      await tester.pumpAndSettle();
      expect(analysis, '1568px meal');
    });
  });
}
