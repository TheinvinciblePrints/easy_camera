import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_easy_camera/flutter_easy_camera.dart';

void main() {
  EasyCamera.debugLogging = true;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Easy Camera',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  EasyCaptureResult? _photo;
  MealEstimate? _meal;

  Future<void> _basicCapture() async {
    final EasyCaptureResult? photo = await EasyCamera.capture(
      context,
      config: const CameraConfig(
        resolution: ResolutionPreset.high,
        capturePreset: CapturePreset.compact,
      ),
    );
    if (photo != null) {
      setState(() {
        _photo = photo;
        _meal = null;
      });
    }
  }

  Future<void> _foodSnap() async {
    final (EasyCaptureResult, MealEstimate?)? result =
        await EasyCamera.captureAndAnalyze<MealEstimate>(
          context,
          config: const CameraConfig.food(),
          analyzer: const FakeMealAnalyzer(),
          resultBuilder:
              (BuildContext context, MealEstimate meal) =>
                  MealSummary(meal: meal),
        );
    if (result != null) {
      setState(() {
        _photo = result.$1;
        _meal = result.$2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final EasyCaptureResult? photo = _photo;
    return Scaffold(
      appBar: AppBar(title: const Text('Easy Camera')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          FilledButton.icon(
            onPressed: _foodSnap,
            icon: const Icon(Icons.restaurant),
            label: const Text('Snap a meal (AI demo)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _basicCapture,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Basic capture'),
          ),
          const SizedBox(height: 24),
          if (photo != null) ...<Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(photo.path)),
            ),
            const SizedBox(height: 12),
            Text(
              '${photo.width} x ${photo.height} · '
              '${(photo.sizeInBytes / 1024).toStringAsFixed(0)} KB · '
              '${photo.lens.name} camera',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_meal != null) ...<Widget>[
            const SizedBox(height: 12),
            MealSummary(meal: _meal!),
          ],
        ],
      ),
    );
  }
}

/// Example result type for a calorie app.
class MealEstimate {
  const MealEstimate({
    required this.name,
    required this.calories,
    required this.items,
  });

  final String name;
  final int calories;
  final List<String> items;
}

/// Stand-in for a real analyzer. A real one would post
/// `capture.toClaudeImageBlock()` to your backend, which calls the model with
/// your API key and returns structured JSON.
class FakeMealAnalyzer extends ImageAnalyzer<MealEstimate> {
  const FakeMealAnalyzer();

  @override
  Future<MealEstimate> analyze(EasyCaptureResult capture) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final int calories = 350 + math.Random().nextInt(500);
    return MealEstimate(
      name: 'Grilled chicken bowl',
      calories: calories,
      items: const <String>['Chicken breast', 'Rice', 'Avocado', 'Greens'],
    );
  }
}

class MealSummary extends StatelessWidget {
  const MealSummary({super.key, required this.meal});

  final MealEstimate meal;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(meal.name, style: text.titleMedium),
        Text('~${meal.calories} kcal', style: text.headlineSmall),
        const SizedBox(height: 4),
        Text(meal.items.join(' · '), style: text.bodySmall),
      ],
    );
  }
}
