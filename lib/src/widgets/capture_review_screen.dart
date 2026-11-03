import 'package:flutter/material.dart';

import '../analysis/image_analyzer.dart';
import '../models/capture_result.dart';

/// What the user decided on the review screen.
@immutable
class CaptureReviewResult<T> {
  const CaptureReviewResult({required this.accepted, this.analysis});

  final bool accepted;

  /// The analyzer's result, or null if there was no analyzer or it failed.
  final T? analysis;
}

/// Shows a capture with retake and accept buttons and, when [analyzer] is
/// set, the analysis while it runs.
///
/// Pops with a [CaptureReviewResult].
class CaptureReviewScreen<T> extends StatefulWidget {
  const CaptureReviewScreen({
    super.key,
    required this.capture,
    this.analyzer,
    this.resultBuilder,
    this.retakeLabel = 'Retake',
    this.acceptLabel = 'Use photo',
  });

  final EasyCaptureResult capture;
  final ImageAnalyzer<T>? analyzer;

  /// Renders a successful analysis. Defaults to its `toString()`.
  final Widget Function(BuildContext context, T result)? resultBuilder;

  final String retakeLabel;
  final String acceptLabel;

  @override
  State<CaptureReviewScreen<T>> createState() => _CaptureReviewScreenState<T>();
}

class _CaptureReviewScreenState<T> extends State<CaptureReviewScreen<T>> {
  AnalysisState<T> _analysis = AnalysisIdle<T>();

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    final ImageAnalyzer<T>? analyzer = widget.analyzer;
    if (analyzer == null) return;
    setState(() => _analysis = AnalysisLoading<T>());
    try {
      final T result = await analyzer.analyze(widget.capture);
      if (mounted) setState(() => _analysis = AnalysisSuccess<T>(result));
    } catch (e, st) {
      if (mounted) setState(() => _analysis = AnalysisFailure<T>(e, st));
    }
  }

  void _finish(bool accepted) {
    final AnalysisState<T> analysis = _analysis;
    Navigator.of(context).pop(
      CaptureReviewResult<T>(
        accepted: accepted,
        analysis: analysis is AnalysisSuccess<T> ? analysis.result : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool waiting = _analysis is AnalysisLoading<T>;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _finish(false);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Center(
                    child: Image.memory(
                      widget.capture.bytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder:
                          (BuildContext context, Object e, _) => const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 64,
                          ),
                    ),
                  ),
                ),
              ),
              if (widget.analyzer != null) _buildAnalysisCard(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () => _finish(false),
                        icon: const Icon(Icons.refresh),
                        label: Text(widget.retakeLabel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: waiting ? null : () => _finish(true),
                        icon: const Icon(Icons.check),
                        label: Text(widget.acceptLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisCard(BuildContext context) {
    final Widget content = switch (_analysis) {
      AnalysisIdle<T>() || AnalysisLoading<T>() => const Row(
        children: <Widget>[
          SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 12),
          Text('Analyzing photo…'),
        ],
      ),
      AnalysisSuccess<T>(:final T result) =>
        widget.resultBuilder?.call(context, result) ?? Text('$result'),
      AnalysisFailure<T>(:final Object error) => Row(
        children: <Widget>[
          const Icon(Icons.error_outline),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Could not analyze this photo.\n$error',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(onPressed: _analyze, child: const Text('Retry')),
        ],
      ),
    };
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: SizedBox(width: double.infinity, child: content),
        ),
      ),
    );
  }
}
