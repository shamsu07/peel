import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/routing/routes.dart';
import '../../core/widgets/common.dart';
import '../../whatsapp/whatsapp_bridge.dart';

/// Settings: grouped sections of rows, the pattern people know from their
/// phone's own settings. Explanations live on their own pages.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  WhatsAppStatus? _status;

  @override
  void initState() {
    super.initState();
    ref
        .read(bridgeProvider)
        .status()
        .then((s) {
          if (mounted) setState(() => _status = s);
        })
        .catchError((_) {});
  }

  String _installed(bool? yes) => switch (yes) {
    null => 'Checking…',
    true => 'Installed',
    false => 'Not installed',
  };

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            PeelSpace.gutter,
            8,
            PeelSpace.gutter,
            32,
          ),
          children: [
            const PeelHeader(),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text('Settings', style: PeelType.title()),
            ),
            const SizedBox(height: 24),
            SettingsGroup(
              title: 'WhatsApp',
              children: [
                SettingsRow(
                  icon: Icons.chat_bubble_rounded,
                  pair: PeelPairs.mint,
                  title: 'WhatsApp',
                  value: _installed(status?.consumerInstalled),
                ),
                if (Platform.isAndroid)
                  SettingsRow(
                    icon: Icons.storefront_rounded,
                    pair: PeelPairs.sky,
                    title: 'WhatsApp Business',
                    value: _installed(status?.businessInstalled),
                  ),
                SettingsRow(
                  icon: Icons.north_east_rounded,
                  pair: PeelPairs.butter,
                  title: 'Open WhatsApp',
                  onTap: status?.anyInstalled == true
                      ? () => ref.read(bridgeProvider).open()
                      : null,
                ),
              ],
            ),
            SettingsGroup(
              title: 'Privacy',
              children: [
                SettingsRow(
                  icon: Icons.lock_rounded,
                  pair: PeelPairs.mint,
                  title: 'Your photos stay on this phone',
                  subtitle: 'No account, no uploads',
                  onTap: () => context.push(Routes.privacy),
                ),
              ],
            ),
            SettingsGroup(
              title: 'Help',
              children: [
                SettingsRow(
                  icon: Icons.volume_up_rounded,
                  pair: PeelPairs.butter,
                  title: 'How stickers with sound work',
                  onTap: () => context.push(Routes.soundHelp),
                ),
                SettingsRow(
                  icon: Icons.rule_rounded,
                  pair: PeelPairs.sky,
                  title: 'WhatsApp’s sticker rules',
                  onTap: () => context.push(Routes.rulesHelp),
                ),
              ],
            ),
            SettingsGroup(
              title: 'About',
              children: [
                const SettingsRow(
                  icon: Icons.info_rounded,
                  pair: PeelPairs.lilac,
                  title: 'Version',
                  value: '0.1 (test build)',
                ),
                SettingsRow(
                  icon: Icons.science_rounded,
                  pair: PeelPairs.bubblegum,
                  title: 'Test lab',
                  subtitle: 'For testing only',
                  onTap: () => context.push(Routes.lab),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // A quiet sign-off: the logo, faded.
            const Center(
              child: ExcludeSemantics(
                child: PeelLogo(height: 44, opacity: 0.45),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Made for WhatsApp stickers',
                style: PeelType.caption().copyWith(
                  fontSize: 12,
                  color: PeelColors.muted.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled white card of rows with inset dividers.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                style: PeelType.caption().copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          ClipRSuperellipse(
            borderRadius: BorderRadius.circular(20),
            child: ColoredBox(
              color: PeelColors.surface,
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i < children.length - 1)
                      Padding(
                        padding: EdgeInsets.only(left: 60),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: PeelColors.paper,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One settings row: icon tile, title, optional subtitle, value or chevron.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.pair,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
  });

  final IconData icon;
  final InkPair pair;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null || value != null;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: ShapeDecoration(
                  color: pair.fill,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: Icon(icon, size: 20, color: pair.ink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          PeelType.body(
                            color: enabled ? PeelColors.ink : PeelColors.muted,
                          ).copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: PeelType.caption().copyWith(fontSize: 13),
                      ),
                  ],
                ),
              ),
              if (value != null)
                Text(value!, style: PeelType.caption().copyWith(fontSize: 15)),
              if (onTap != null)
                Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: PeelColors.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A plain page of short sections, for Privacy and Help.
class InfoPage extends StatelessWidget {
  const InfoPage({super.key, required this.title, required this.sections});

  final String title;
  final List<(String heading, String body)> sections;

  static InfoPage privacy() => const InfoPage(
    title: 'Privacy.',
    sections: [
      (
        'Everything happens on your phone',
        'Peel cuts out, trims and compresses your stickers on this phone. The '
            'photos, videos and sounds you pick or record are never uploaded.',
      ),
      (
        'No account',
        'There’s no sign-up and no profile. Peel doesn’t know who you are.',
      ),
      (
        'What leaves your phone',
        'Only what you choose to send: stickers you add to WhatsApp, and files '
            'you save or share.',
      ),
    ],
  );

  static InfoPage soundHelp() => const InfoPage(
    title: 'Stickers with sound.',
    sections: [
      (
        'Why there’s an extra step',
        'WhatsApp lets you make stickers with sound inside WhatsApp, but it '
            'doesn’t let other apps add them yet. WhatsApp has said it plans to.',
      ),
      (
        'What Peel does',
        'Peel adds the moving sticker to WhatsApp straight away, and saves a '
            'short video of it with your sound to Photos.',
      ),
      (
        'Finishing it in WhatsApp',
        'Open a chat, tap the sticker icon, tap Create sticker, pick the video '
            'and keep its sound. When WhatsApp opens this up to apps, Peel will '
            'do it in one tap.',
      ),
    ],
  );

  static InfoPage rulesHelp() => const InfoPage(
    title: 'WhatsApp’s sticker rules.',
    sections: [
      ('Size', 'Every sticker is a 512 × 512 square.'),
      (
        'File size',
        'Still stickers must be under 100 KB and moving ones under 500 KB. '
            'Peel squeezes stickers to fit automatically.',
      ),
      ('Length', 'Moving stickers can be up to 10 seconds.'),
      (
        'Packs',
        'WhatsApp takes stickers in packs of at least 3. Peel adds bonus '
            'stickers so you can send just one.',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            PeelSpace.gutter,
            8,
            PeelSpace.gutter,
            32,
          ),
          children: [
            const PeelHeader(),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(title, style: PeelType.title(size: 34)),
            ),
            const SizedBox(height: 20),
            for (final (heading, body) in sections) ...[
              Text(heading, style: PeelType.label()),
              const SizedBox(height: 6),
              Text(body, style: PeelType.body()),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}
