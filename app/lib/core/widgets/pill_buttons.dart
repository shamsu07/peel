import 'package:material_ui/material_ui.dart';

import '../design/tokens.dart';
import '../design/whatsapp_colors.dart';
import '../design/typography.dart';

/// The one black button per screen: the next step, at the bottom.
class PrimaryPillButton extends StatelessWidget {
  const PrimaryPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.background = PeelColors.ink,
    this.foreground = PeelColors.surface,
  });

  /// A WhatsApp-green button for actions that go to WhatsApp.
  const PrimaryPillButton.whatsApp({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.trailing,
  }) : background = WhatsAppColors.green,
       foreground = WhatsAppColors.onGreen;

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final Widget? trailing;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: PeelColors.hairline,
        minimumSize: const Size.fromHeight(58),
        shape: const StadiumBorder(),
        textStyle: PeelType.button(color: foreground),
      ),
      child: _PillContent(label: label, leading: leading, trailing: trailing),
    );
  }
}

/// Quieter white pill for secondary actions such as "Share".
class SecondaryPillButton extends StatelessWidget {
  const SecondaryPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.background = PeelColors.surface,
    this.foreground = PeelColors.ink,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;

  /// White by default; pass a tint when the button sits on a white card.
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        minimumSize: const Size.fromHeight(48),
        shape: const StadiumBorder(),
        textStyle: PeelType.button(color: PeelColors.ink)
            .copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      child: _PillContent(label: label, leading: leading),
    );
  }
}

class _PillContent extends StatelessWidget {
  const _PillContent({required this.label, this.leading, this.trailing});

  final String label;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 10)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

/// White circular icon button used in headers (back, close, settings).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        backgroundColor: PeelColors.surface,
        foregroundColor: PeelColors.ink,
        fixedSize: const Size.square(PeelSpace.minTouch),
      ),
    );
  }
}
