import 'package:flutter/material.dart';

/// An animated ring shown where the user tapped to focus.
class FocusIndicator extends StatefulWidget {
  const FocusIndicator({
    super.key,
    required this.position,
    this.color = Colors.white,
    this.size = 72,
  });

  /// Center of the ring. Changing it replays the animation.
  final Offset? position;
  final Color color;
  final double size;

  @override
  State<FocusIndicator> createState() => _FocusIndicatorState();
}

class _FocusIndicatorState extends State<FocusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1.4,
    end: 1,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.3, curve: Curves.easeOut),
    ),
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: 1,
    end: 0,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1, curve: Curves.easeIn),
    ),
  );

  @override
  void didUpdateWidget(FocusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.position != null && widget.position != oldWidget.position) {
      _controller.forward(from: 0);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.position != null) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Offset? position = widget.position;
    if (position == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(
        children: <Widget>[
          Positioned(
            left: position.dx - widget.size / 2,
            top: position.dy - widget.size / 2,
            child: AnimatedBuilder(
              animation: _controller,
              builder:
                  (BuildContext context, Widget? child) => Opacity(
                    opacity: _opacity.value,
                    child: Transform.scale(scale: _scale.value, child: child),
                  ),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.color, width: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
