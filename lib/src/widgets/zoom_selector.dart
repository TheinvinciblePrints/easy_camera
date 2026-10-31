import 'package:flutter/material.dart';

/// Quick zoom chips (for example 0.5x, 1x, 2x, 5x) within the camera's range.
class ZoomSelector extends StatelessWidget {
  const ZoomSelector({
    super.key,
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onChanged,
  });

  final double zoom;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double> onChanged;

  List<double> get _stops {
    final List<double> stops = <double>[
      if (minZoom < 0.95) minZoom,
      for (final double z in const <double>[1, 2, 5])
        if (z >= minZoom && z <= maxZoom) z,
    ];
    return stops;
  }

  static String _label(double z) =>
      z == z.roundToDouble() ? '${z.toInt()}x' : '${z.toStringAsFixed(1)}x';

  @override
  Widget build(BuildContext context) {
    final List<double> stops = _stops;
    if (stops.length < 2) return const SizedBox.shrink();
    // The active chip is the largest stop at or below the current zoom.
    final double active = stops.lastWhere(
      (double s) => zoom + 0.05 >= s,
      orElse: () => stops.first,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final double stop in stops)
              GestureDetector(
                onTap: () => onChanged(stop),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        stop == active
                            ? Colors.white.withValues(alpha: 0.25)
                            : Colors.transparent,
                  ),
                  child: Text(
                    stop == active ? _label(zoom) : _label(stop),
                    style: TextStyle(
                      color: stop == active ? Colors.amber : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
