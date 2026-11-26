import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../design/tokens.dart';

/// A UI card that looks like a die-cut sticker: pastel fill, white edge,
/// soft shadow and an optional slight tilt.
///
/// Use it only for main choices, the sound card, tags and step numbers.
/// Everything else in the UI stays flat.
class DieCutCard extends StatelessWidget {
  const DieCutCard({
    super.key,
    required this.color,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.tiltDegrees = 0,
    this.radius = PeelRadii.card,
    this.edge = PeelDieCut.edge,
    this.padding = const EdgeInsets.all(16),
  }) : assert(
         tiltDegrees >= -PeelDieCut.maxTiltDegrees &&
             tiltDegrees <= PeelDieCut.maxTiltDegrees,
         'UI cards tilt at most ${PeelDieCut.maxTiltDegrees}°',
       );

  final Color color;
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double tiltDegrees;
  final double radius;
  final double edge;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(
        color: PeelColors.white,
        width: edge,
        strokeAlign: BorderSide.strokeAlignInside,
      ),
    );

    Widget card = DecoratedBox(
      decoration: ShapeDecoration(
        shadows: PeelShadows.card,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      child: Material(
        color: color,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding + EdgeInsets.all(edge), child: child),
        ),
      ),
    );

    if (tiltDegrees != 0) {
      card = Transform.rotate(angle: tiltDegrees * math.pi / 180, child: card);
    }

    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: card,
    );
  }
}

/// The small rotated tag, e.g. "NEW".
class DieCutTag extends StatelessWidget {
  const DieCutTag({
    super.key,
    required this.label,
    required this.textStyle,
    this.color = PeelColors.tagRed,
    this.tiltDegrees = 7,
  });

  final String label;
  final TextStyle textStyle;
  final Color color;
  final double tiltDegrees;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tiltDegrees * math.pi / 180,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: color,
          shadows: PeelShadows.card,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: PeelColors.white, width: 3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          child: Text(label, style: textStyle),
        ),
      ),
    );
  }
}
