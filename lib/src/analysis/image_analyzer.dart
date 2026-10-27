import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/capture_result.dart';

/// Turns a capture into a typed result, for example by sending it to your
/// backend, which asks a vision model to estimate the calories in a meal.
///
/// The package ships no implementation and never handles API keys. Keep
/// provider keys on your server and call it from [analyze].
///
/// ```dart
/// class MealAnalyzer extends ImageAnalyzer<Meal> {
///   @override
///   Future<Meal> analyze(EasyCaptureResult capture) async {
///     final response = await http.post(
///       Uri.parse('https://api.example.com/meals/analyze'),
///       headers: {'Content-Type': 'application/json'},
///       body: jsonEncode({'image': capture.toClaudeImageBlock()}),
///     );
///     return Meal.fromJson(jsonDecode(response.body));
///   }
/// }
/// ```
abstract class ImageAnalyzer<T> {
  const ImageAnalyzer();

  /// Wraps a function as an analyzer.
  const factory ImageAnalyzer.fromCallback(
    Future<T> Function(EasyCaptureResult capture) analyze,
  ) = _CallbackImageAnalyzer<T>;

  Future<T> analyze(EasyCaptureResult capture);
}

class _CallbackImageAnalyzer<T> extends ImageAnalyzer<T> {
  const _CallbackImageAnalyzer(this._analyze);

  final Future<T> Function(EasyCaptureResult capture) _analyze;

  @override
  Future<T> analyze(EasyCaptureResult capture) => _analyze(capture);
}

/// Progress of an [ImageAnalyzer] run.
@immutable
sealed class AnalysisState<T> {
  const AnalysisState();
}

final class AnalysisIdle<T> extends AnalysisState<T> {
  const AnalysisIdle();
}

final class AnalysisLoading<T> extends AnalysisState<T> {
  const AnalysisLoading();
}

final class AnalysisSuccess<T> extends AnalysisState<T> {
  const AnalysisSuccess(this.result);

  final T result;
}

final class AnalysisFailure<T> extends AnalysisState<T> {
  const AnalysisFailure(this.error, [this.stackTrace]);

  final Object error;
  final StackTrace? stackTrace;
}
