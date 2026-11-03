import 'package:flutter/material.dart';

/// Shape of a [FramingOverlay] cut-out.
enum FramingShape { circle, roundedRect }

/// A guide drawn over the preview to help the user frame the subject. The
/// area outside the guide is dimmed.
@immutable
class FramingOverlay {
  const FramingOverlay({
    this.shape = FramingShape.roundedRect,
    this.aspectRatio = 1.0,
    this.sizeFactor = 0.82,
    this.borderColor = Colors.white,
    this.borderWidth = 2.5,
    this.dimColor = const Color(0x8C000000),
    this.cornerRadius = 24,
    this.hint,
    this.cropToFrame = true,
  }) : assert(sizeFactor > 0 && sizeFactor <= 1),
       assert(aspectRatio > 0);

  /// A round guide for a plate or bowl.
  static const FramingOverlay plate = FramingOverlay(
    shape: FramingShape.circle,
    hint: 'Fit your whole plate inside the circle',
  );

  /// A portrait rectangle for nutrition labels.
  static const FramingOverlay label = FramingOverlay(
    aspectRatio: 3 / 4,
    hint: 'Line up the nutrition label',
  );

  final FramingShape shape;

  /// Width / height of the guide. Circles always use 1.
  final double aspectRatio;

  /// Fraction of the shorter side of the preview the guide spans.
  final double sizeFactor;

  final Color borderColor;
  final double borderWidth;
  final Color dimColor;
  final double cornerRadius;

  /// Short instruction shown below the guide.
  final String? hint;

  /// Crop captures to the guide's aspect ratio.
  final bool cropToFrame;

  double get effectiveAspectRatio =>
      shape == FramingShape.circle ? 1.0 : aspectRatio;

  /// The guide's rectangle inside a box of [size].
  Rect frameRect(Size size) {
    final double ratio = effectiveAspectRatio;
    double width = size.shortestSide * sizeFactor;
    double height = width / ratio;
    final double maxHeight = size.height * sizeFactor;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * ratio;
    }
    return Rect.fromCenter(
      center: size.center(Offset.zero),
      width: width,
      height: height,
    );
  }
}

/// Paints a [FramingOverlay].
class FramingOverlayView extends StatelessWidget {
  const FramingOverlayView({super.key, required this.overlay});

  final FramingOverlay overlay;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size size = constraints.biggest;
          final Rect frame = overlay.frameRect(size);
          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: CustomPaint(painter: _FramingPainter(overlay, frame)),
              ),
              if (overlay.hint != null)
                Positioned(
                  left: 24,
                  right: 24,
                  top: frame.bottom + 16,
                  child: Text(
                    overlay.hint!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      shadows: <Shadow>[
                        Shadow(blurRadius: 6, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FramingPainter extends CustomPainter {
  _FramingPainter(this.overlay, this.frame);

  final FramingOverlay overlay;
  final Rect frame;

  Path _framePath() {
    final Path path = Path();
    if (overlay.shape == FramingShape.circle) {
      path.addOval(frame);
    } else {
      path.addRRect(
        RRect.fromRectAndRadius(frame, Radius.circular(overlay.cornerRadius)),
      );
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Path cutout = _framePath();
    final Path dim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      cutout,
    );
    canvas.drawPath(dim, Paint()..color = overlay.dimColor);
    canvas.drawPath(
      cutout,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = overlay.borderWidth
        ..color = overlay.borderColor,
    );
  }

  @override
  bool shouldRepaint(_FramingPainter oldDelegate) =>
      oldDelegate.overlay != overlay || oldDelegate.frame != frame;
}
