import 'package:flutter/material.dart';

import '../controller/easy_camera_controller.dart';
import '../controller/easy_camera_state.dart';
import '../models/camera_enums.dart';
import '../models/preview_info.dart';

/// Shows the live preview of [controller], upright and mirrored as needed.
///
/// [onTap] receives the tapped point normalized (0..1) to the visible
/// preview, which is what `EasyCameraController.focusAt` expects.
class EasyCameraPreview extends StatelessWidget {
  const EasyCameraPreview({
    super.key,
    required this.controller,
    this.fit = PreviewFit.cover,
    this.onTap,
    this.placeholder,
  });

  final EasyCameraController controller;
  final PreviewFit fit;
  final void Function(Offset normalizedPoint, Offset localPosition)? onTap;
  final Widget? placeholder;

  /// Converts [local] in a box of [box] to a normalized point in the preview
  /// content, accounting for the parts [fit] crops away.
  static Offset normalize(
    Offset local,
    Size box,
    PreviewInfo preview,
    PreviewFit fit,
  ) {
    final double aspect = preview.displayAspectRatio;
    double contentW = box.width;
    double contentH = box.width / aspect;
    final bool tooShort = contentH < box.height;
    if (fit == PreviewFit.cover ? tooShort : !tooShort) {
      contentH = box.height;
      contentW = box.height * aspect;
    }
    final double dx = (box.width - contentW) / 2;
    final double dy = (box.height - contentH) / 2;
    return Offset(
      ((local.dx - dx) / contentW).clamp(0.0, 1.0),
      ((local.dy - dy) / contentH).clamp(0.0, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EasyCameraState>(
      valueListenable: controller,
      builder: (BuildContext context, EasyCameraState state, Widget? _) {
        final int? textureId = state.textureId;
        if (!state.isReady || textureId == null) {
          return placeholder ?? const ColoredBox(color: Colors.black);
        }
        final PreviewInfo preview = state.preview;

        Widget texture = SizedBox(
          width: preview.width,
          height: preview.height,
          child: Texture(textureId: textureId),
        );
        texture = RotatedBox(
          quarterTurns: preview.quarterTurns,
          child: texture,
        );
        if (preview.mirror) {
          texture = Transform.flip(flipX: true, child: texture);
        }

        final Widget fitted = ClipRect(
          child: FittedBox(
            fit: fit == PreviewFit.cover ? BoxFit.cover : BoxFit.contain,
            child: texture,
          ),
        );

        if (onTap == null) return fitted;
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp:
                  (TapUpDetails details) => onTap!(
                    normalize(
                      details.localPosition,
                      constraints.biggest,
                      preview,
                      fit,
                    ),
                    details.localPosition,
                  ),
              child: fitted,
            );
          },
        );
      },
    );
  }
}
