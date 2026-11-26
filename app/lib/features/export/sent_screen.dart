import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/routing/routes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pill_buttons.dart';
import '../../sticker_engine/sticker_check.dart';
import '../../whatsapp/whatsapp_bridge.dart';
import '../create/start.dart';
import 'sticker_actions.dart';
import 'sticker_image.dart';

/// "It’s in WhatsApp." (canvas: Sent).
class SentScreen extends ConsumerStatefulWidget {
  const SentScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<SentScreen> createState() => _SentScreenState();
}

class _SentScreenState extends ConsumerState<SentScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  WhatsAppStatus? _status;
  String? _packName;

  @override
  void initState() {
    super.initState();
    _checkBusiness();
    _loadPackName();
  }

  Future<void> _loadPackName() async {
    final record = findSticker(ref, widget.id);
    if (record == null) return;
    final pack = await (await ref.read(exporterProvider.future)).packOf(record);
    if (mounted && pack != null) setState(() => _packName = pack.name);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _slap.value = 1;
    } else if (_slap.value == 0) {
      _slap.forward();
    }
  }

  Future<void> _checkBusiness() async {
    if (!Platform.isAndroid) return;
    final record = findSticker(ref, widget.id);
    try {
      final status = await ref
          .read(bridgeProvider)
          .status(identifier: record?.packIdentifier);
      if (mounted) setState(() => _status = status);
    } catch (_) {}
  }

  @override
  void dispose() {
    _slap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = (ref.watch(libraryProvider).value ?? const [])
        .where((r) => r.id == widget.id)
        .firstOrNull;
    if (record == null) return const Scaffold(body: SizedBox());
    final packName =
        _packName ??
        (record.kind == StickerKind.still
            ? 'My Stickers'
            : 'My Moving Stickers');
    final status = _status;
    final offerBusiness =
        status != null &&
        status.businessInstalled &&
        status.businessHasPack == false;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PeelSpace.gutter,
            8,
            PeelSpace.gutter,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  RoundIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    onPressed: () => context.go(Routes.home),
                  ),
                  const Spacer(),
                  Transform.rotate(
                    angle: 0.07,
                    child: PeelChip(
                      label: 'Added',
                      pair: PeelPairs.mint,
                      icon: Icons.check_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Semantics(
                header: true,
                child: Text.rich(
                  const TextSpan(
                    text: 'It’s in\n',
                    children: [
                      TextSpan(
                        text: 'WhatsApp',
                        style: TextStyle(color: WhatsAppColors.green),
                      ),
                      TextSpan(text: '.'),
                    ],
                  ),
                  style: PeelType.title(size: 54).copyWith(height: 0.95),
                ),
              ),
              const SizedBox(height: 14),
              _ChatScene(slap: _slap, sticker: StickerImage(record, size: 112)),
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  text: 'Open any chat, tap the sticker icon and look for ',
                  children: [
                    TextSpan(
                      text: packName,
                      style: const TextStyle(
                        color: PeelColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                style: PeelType.body().copyWith(fontSize: 15),
              ),
              if (offerBusiness) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                  decoration: BoxDecoration(
                    color: PeelColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Use WhatsApp Business too?',
                              style: PeelType.label().copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Add it there as well',
                              style: PeelType.caption(),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () => sendToWhatsApp(
                          context,
                          ref,
                          record,
                          openSentScreen: false,
                          again: true,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: PeelColors.paper,
                          foregroundColor: PeelColors.ink,
                          minimumSize: const Size(0, PeelSpace.minTouch),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: SecondaryPillButton(
                      label: 'Open WhatsApp',
                      onPressed: () => ref.read(bridgeProvider).open(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SecondaryPillButton(
                      label: 'Make another',
                      leading: const Icon(Icons.add_rounded, size: 18),
                      onPressed: () {
                        context.go(Routes.home);
                        showCreateSheet(context, ref);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (record.hasSound && record.handoffVideo != null)
                PrimaryPillButton(
                  label: 'Next: give it its sound',
                  leading: Icon(
                    Icons.volume_up_rounded,
                    color: PeelPairs.butter.fill,
                  ),
                  onPressed: () =>
                      context.pushReplacement(Routes.sound(record.id)),
                )
              else
                PrimaryPillButton(
                  label: 'Done',
                  onPressed: () => context.go(Routes.home),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// WhatsApp's own colours, for the chat preview and the heading.
abstract final class WhatsAppColors {
  static const green = Color(0xFF25D366);
  static const teal = Color(0xFF008069);
  static const wallpaper = Color(0xFFEFEAE2);
  static const outgoing = Color(0xFFD9FDD3);
  static const tick = Color(0xFF53BDEB);
  static const meta = Color(0xFF667781);
  static const text = Color(0xFF111B21);
  static const mic = Color(0xFF00A884);
}

/// A WhatsApp chat with the new sticker landing in it.
class _ChatScene extends StatelessWidget {
  const _ChatScene({required this.slap, required this.sticker});

  final Animation<double> slap;
  final Widget sticker;

  static const _metaStyle = TextStyle(
    fontSize: 10.5,
    color: WhatsAppColors.meta,
    height: 1,
  );

  Widget _bubble(String text, String time, {bool mine = false}) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 230),
        padding: const EdgeInsets.fromLTRB(9, 6, 7, 5),
        decoration: BoxDecoration(
          color: mine ? WhatsAppColors.outgoing : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(mine ? 9 : 2),
            topRight: Radius.circular(mine ? 2 : 9),
            bottomLeft: const Radius.circular(9),
            bottomRight: const Radius.circular(9),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x21000000),
              offset: Offset(0, 1),
              blurRadius: 0.5,
            ),
          ],
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          alignment: WrapAlignment.end,
          spacing: 8,
          children: [
            Text(
              text,
              style: const TextStyle(
                fontSize: 14.5,
                color: WhatsAppColors.text,
                height: 1.25,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: _Meta(time: time, read: mine),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        height: 318,
        decoration: BoxDecoration(
          color: WhatsAppColors.wallpaper,
          borderRadius: BorderRadius.circular(28),
          boxShadow: PeelShadows.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Chat header.
            Container(
              color: const Color(0xFFFFFFFF),
              padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: WhatsAppColors.text,
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: PeelPairs.butter.fill,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      'S',
                      style: TextStyle(
                        color: PeelPairs.butter.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sam',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: WhatsAppColors.text,
                          ),
                        ),
                        Text(
                          'online',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: WhatsAppColors.meta,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.videocam_outlined,
                    size: 21,
                    color: WhatsAppColors.text,
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.call_outlined,
                    size: 19,
                    color: WhatsAppColors.text,
                  ),
                ],
              ),
            ),
            // Messages on the wallpaper.
            Expanded(
              child: CustomPaint(
                painter: const _DoodlePainter(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFFFF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Today',
                            style: TextStyle(
                              fontSize: 11,
                              color: WhatsAppColors.meta,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _bubble('Send me something good 👀', '10:41'),
                      const SizedBox(height: 4),
                      _bubble('Made this myself', '10:42', mine: true),
                      const Spacer(),
                      // The sticker lands: no bubble, just the sticker
                      // with its time underneath, like WhatsApp.
                      Align(
                        alignment: Alignment.centerRight,
                        child: AnimatedBuilder(
                          animation: slap,
                          builder: (context, child) {
                            final t = Curves.easeOutBack.transform(slap.value);
                            return Opacity(
                              opacity: slap.value.clamp(0, 1),
                              child: Transform.translate(
                                offset: Offset(0, -36 * (1 - t)),
                                child: Transform.rotate(
                                  angle: (-10 * (1 - t)) * math.pi / 180,
                                  child: Transform.scale(
                                    scale: 1.2 - 0.2 * t,
                                    child: child,
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              sticker,
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xE6FFFFFF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const _Meta(time: '10:42', read: true),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Message bar.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.emoji_emotions_outlined,
                            size: 19,
                            color: WhatsAppColors.meta,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Message',
                              style: TextStyle(
                                fontSize: 14,
                                color: WhatsAppColors.meta,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.sticky_note_2_outlined,
                            size: 19,
                            color: WhatsAppColors.meta,
                          ),
                          SizedBox(width: 10),
                          Icon(
                            Icons.photo_camera_outlined,
                            size: 19,
                            color: WhatsAppColors.meta,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: WhatsAppColors.mic,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic_rounded,
                      size: 19,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "10:42 ✓✓": a message's time, with blue ticks on messages you sent.
class _Meta extends StatelessWidget {
  const _Meta({required this.time, this.read = false});

  final String time;
  final bool read;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(time, style: _ChatScene._metaStyle),
        if (read) ...[
          const SizedBox(width: 3),
          const Icon(
            Icons.done_all_rounded,
            size: 14,
            color: WhatsAppColors.tick,
          ),
        ],
      ],
    );
  }
}

/// A faint doodle pattern, like WhatsApp's chat wallpaper.
class _DoodlePainter extends CustomPainter {
  const _DoodlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0F5E4B3C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const step = 46.0;
    var row = 0;
    for (var y = 12.0; y < size.height; y += step, row++) {
      for (var x = (row.isEven ? 10.0 : 33.0); x < size.width; x += step) {
        switch (((x / step).floor() + row) % 4) {
          case 0:
            canvas.drawCircle(Offset(x, y), 5, paint);
          case 1:
            canvas.drawLine(Offset(x - 5, y + 4), Offset(x + 5, y - 4), paint);
            canvas.drawLine(Offset(x - 5, y - 4), Offset(x + 5, y + 4), paint);
          case 2:
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(x, y), width: 10, height: 8),
                const Radius.circular(2),
              ),
              paint,
            );
          default:
            final path = Path()
              ..moveTo(x - 5, y + 3)
              ..quadraticBezierTo(x, y - 6, x + 5, y + 3);
            canvas.drawPath(path, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_DoodlePainter old) => false;
}
