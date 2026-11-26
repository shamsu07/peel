import 'package:material_ui/material_ui.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import 'pill_buttons.dart';

/// Back/close button, centred title, optional trailing action.
class PeelHeader extends StatelessWidget {
  const PeelHeader({
    super.key,
    this.title,
    this.close = false,
    this.onBack,
    this.trailing,
  });

  final String? title;
  final bool close;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PeelSpace.minTouch,
      child: Row(
        children: [
          RoundIconButton(
            icon: close ? Icons.close_rounded : Icons.chevron_left_rounded,
            tooltip: close ? 'Close' : 'Back',
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: title == null
                ? const SizedBox()
                : Text(
                    title!,
                    textAlign: TextAlign.center,
                    style: PeelType.button(color: PeelColors.ink)
                        .copyWith(letterSpacing: -0.2),
                  ),
          ),
          SizedBox(
            width: trailing == null ? PeelSpace.minTouch : null,
            child: trailing,
          ),
        ],
      ),
    );
  }
}

/// The dark grid that shows transparency behind a sticker.
class Checkerboard extends StatelessWidget {
  const Checkerboard({super.key, required this.child, this.radius = 28});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(painter: const _CheckerPainter(), child: child),
    );
  }
}

class _CheckerPainter extends CustomPainter {
  const _CheckerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Dark in both modes: the sticker's white edge stands out on it.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF26262C),
    );
    const cell = 11.0;
    final grey = Paint()..color = const Color(0xFF2F2F36);
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        if (((x / cell).floor() + (y / cell).floor()).isOdd) {
          canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), grey);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// White bottom sheet with grabber, title and close button.
class PeelSheet extends StatelessWidget {
  const PeelSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          PeelSpace.gutter,
          10,
          PeelSpace.gutter,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: ShapeDecoration(
                  color: PeelColors.hairline,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: PeelType.title(size: 30)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: PeelType.body().copyWith(fontSize: 15),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: PeelColors.closeFill,
                    foregroundColor: PeelColors.tagRed,
                    fixedSize: const Size.square(PeelSpace.minTouch),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

Future<T?> showPeelSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PeelColors.surface,
      barrierColor: const Color(0x6B111113),
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: builder,
    );

/// A tinted note, e.g. the "squeezed to fit" explanation.
class PeelNote extends StatelessWidget {
  const PeelNote({
    super.key,
    required this.text,
    this.pair = PeelPairs.sky,
    this.icon = Icons.info_rounded,
    this.action,
  });

  final String text;
  final InkPair pair;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: ShapeDecoration(
        color: pair.fill,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: pair.ink, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: PeelType.caption(color: pair.ink)
                      .copyWith(fontSize: 14, height: 1.4),
                ),
                if (action != null) ...[const SizedBox(height: 10), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small rounded label, e.g. "BONUS" or "In WhatsApp".
class PeelChip extends StatelessWidget {
  const PeelChip({super.key, required this.label, this.pair, this.icon});

  final String label;
  final InkPair? pair;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = pair?.ink ?? PeelColors.mutedStrong;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: pair?.fill ?? PeelColors.track,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: PeelType.caption(color: fg)
                  .copyWith(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Ready for WhatsApp ✓" that opens the list of rules the sticker passes.
class ReadyPill extends StatefulWidget {
  const ReadyPill({super.key, required this.checks});

  final List<String> checks;

  @override
  State<ReadyPill> createState() => _ReadyPillState();
}

class _ReadyPillState extends State<ReadyPill> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    const pair = PeelPairs.mint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Material(
          color: pair.fill,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: PeelColors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_rounded, size: 16, color: pair.ink),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ready for WhatsApp',
                    style: PeelType.caption(color: pair.ink)
                        .copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: pair.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: _open
              ? Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: ShapeDecoration(
                    color: PeelColors.surface,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WhatsApp’s rules, all passed',
                        style: PeelType.caption(),
                      ),
                      const SizedBox(height: 8),
                      for (final c in widget.checks)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: pair.ink,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                c,
                                style: PeelType.body(color: PeelColors.ink)
                                    .copyWith(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// What a notification is about; picks its little icon.
enum SnackTone { done, problem, info }

/// Guesses the tone from the wording, so call sites stay simple.
SnackTone _toneOf(String message) {
  final m = message.toLowerCase();
  if (m.startsWith('couldn') ||
      m.startsWith('something') ||
      m.contains('didn’t') ||
      m.startsWith('not added') ||
      m.contains('isn’t installed') ||
      m.contains('can’t')) {
    return SnackTone.problem;
  }
  if (m.startsWith('saved') ||
      m.startsWith('copied') ||
      m.startsWith('added') ||
      m.startsWith('sent') ||
      m.contains('deleted') ||
      m.contains('copied')) {
    return SnackTone.done;
  }
  return SnackTone.info;
}

/// A light, helpful notification: soft charcoal, regular-weight text, a
/// small tinted icon saying what happened, and an optional text action
/// (e.g. Undo). Closes by itself.
SnackBar peelSnackBar(
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
  SnackTone? tone,
}) {
  final t = tone ?? _toneOf(message);
  final (IconData icon, Color fill, Color ink) = switch (t) {
    SnackTone.done => (
      Icons.check_rounded,
      PeelPairs.mint.fill,
      PeelPairs.mint.ink,
    ),
    SnackTone.problem => (
      Icons.priority_high_rounded,
      const Color(0xFFFFD4D1),
      const Color(0xFFB42318),
    ),
    SnackTone.info => (
      Icons.info_rounded,
      PeelPairs.sky.fill,
      PeelPairs.sky.ink,
    ),
  };
  return SnackBar(
    duration: duration,
    // With a button (e.g. Undo) it would otherwise stay until tapped.
    persist: false,
    behavior: SnackBarBehavior.floating,
    elevation: 0,
    backgroundColor: PeelColors.dark
        ? const Color(0xF0303038)
        : const Color(0xF01E1E24),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
    shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(18)),
    dismissDirection: DismissDirection.down,
    content: Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: ink),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: PeelType.body(
              color: const Color(0xEBFFFFFF),
            ).copyWith(fontSize: 15, height: 1.3, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
    action: actionLabel == null
        ? null
        : SnackBarAction(
            label: actionLabel,
            textColor: PeelPairs.butter.fill,
            onPressed: onAction ?? () {},
          ),
  );
}

void showPeelSnack(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
  SnackTone? tone,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      peelSnackBar(
        message,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        tone: tone,
      ),
      snackBarAnimationStyle: peelSnackMotion,
    );
}

/// Rises in gently, leaves quickly.
const peelSnackMotion = AnimationStyle(
  duration: Duration(milliseconds: 340),
  reverseDuration: Duration(milliseconds: 200),
  curve: Curves.easeOutCubic,
  reverseCurve: Curves.easeInCubic,
);

/// The PEEL sticker logo, for the top-left of Home.
class PeelLogo extends StatelessWidget {
  const PeelLogo({super.key, this.height = 52, this.opacity = 1});

  final double height;

  /// Faded without an extra layer (cheaper than an Opacity widget).
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/peel_logo.png',
      height: height,
      width: height * 95 / 52,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      opacity: opacity == 1 ? null : AlwaysStoppedAnimation(opacity),
      semanticLabel: 'Peel',
    );
  }
}
