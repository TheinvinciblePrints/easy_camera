import 'package:flutter/material.dart';

/// Round button showing the current flash mode.
class CameraFlashIcon extends StatelessWidget {
  const CameraFlashIcon({
    super.key,
    required this.onTap,
    required this.flashIcon,
    this.flashControlBuilder,
  });

  final void Function()? onTap;
  final IconData flashIcon;
  final Widget? flashControlBuilder;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 60,
        height: 60,
        child:
            flashControlBuilder ??
            ClipOval(
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                padding: const EdgeInsets.all(2.0),
                child: Icon(flashIcon, color: Colors.white),
              ),
            ),
      ),
    );
  }
}
