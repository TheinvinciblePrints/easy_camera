import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Button that spins when switching between front and back cameras.
class CameraSwitchIcon extends StatefulWidget {
  const CameraSwitchIcon({
    super.key,
    required this.onTap,
    this.switchCameraIcon,
  });

  final VoidCallback? onTap;
  final Widget? switchCameraIcon;

  @override
  State<CameraSwitchIcon> createState() => _CameraSwitchIconState();
}

class _CameraSwitchIconState extends State<CameraSwitchIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isAnimating = false;
  final double _targetRotationAngle = 0;
  double _currentRotationAngle = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        setState(() => _isAnimating = false);
      }
    });
  }

  void _animateRotation() {
    if (_isAnimating) {
      return;
    }

    setState(() => _isAnimating = true);
    _controller.forward(from: 0.0);
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _animateRotation,
      child: Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: _currentRotationAngle,
                end: _targetRotationAngle,
              ),
              duration: const Duration(milliseconds: 500), // Smooth transition
              curve: Curves.easeOut,
              onEnd: () {
                _currentRotationAngle = _targetRotationAngle;
              },
              builder: (BuildContext context, double angle, Widget? child) {
                return Transform.rotate(
                  angle: (_controller.value * 2 * math.pi) + angle,
                  child: child,
                );
              },
              child:
                  widget.switchCameraIcon ??
                  ClipOval(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: const Padding(
                        padding: EdgeInsets.all(2.0),
                        child: Icon(
                          Icons.cameraswitch_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
            );
          },
        ),
      ),
    );
  }
}
