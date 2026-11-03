import 'package:flutter/material.dart';

/// The round shutter button.
class TakePhotoButton extends StatefulWidget {
  const TakePhotoButton({super.key, required this.onTap, this.busy = false});

  /// Null disables the button.
  final void Function()? onTap;

  /// Shows a spinner while a photo is being processed.
  final bool busy;

  @override
  State createState() => _TakePhotoButtonState();
}

class _TakePhotoButtonState extends State<TakePhotoButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _animationController;
  double? _scale;
  final Duration _duration = const Duration(milliseconds: 100);

  @override
  void initState() {
    _animationController = AnimationController(
      vsync: this,
      duration: _duration,
      upperBound: 0.1,
    )..addListener(() {
      setState(() {});
    });
    super.initState();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scale = 1 - (_animationController?.value ?? 0);

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: SizedBox(
        height: 80,
        width: 80,
        child: Opacity(
          opacity: widget.onTap == null ? 0.5 : 1,
          child: Transform.scale(
            scale: _scale,
            child: CustomPaint(
              painter: TakePhotoButtonPainter(),
              child:
                  widget.busy
                      ? const Padding(
                        padding: EdgeInsets.all(22),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                      : null,
            ),
          ),
        ),
      ),
    );
  }

  void _onTapDown(TapDownDetails details) {
    _animationController?.forward();
  }

  void _onTapUp(TapUpDetails details) {
    Future<dynamic>.delayed(_duration, () {
      _animationController?.reverse();
    });

    widget.onTap?.call();
  }

  void _onTapCancel() {
    _animationController?.reverse();
  }
}

class TakePhotoButtonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint bgPainter =
        Paint()
          ..style = PaintingStyle.fill
          ..isAntiAlias = true;
    final double radius = size.width / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    bgPainter.color = Colors.white;
    canvas.drawCircle(center, radius, bgPainter);
    bgPainter.color = const Color(0xffB2B2B2);
    canvas.drawCircle(center, radius - 8, bgPainter);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
