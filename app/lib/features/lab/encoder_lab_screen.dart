import 'dart:isolate';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/widgets/pill_buttons.dart';
import '../../sticker_engine/compressor.dart';
import '../../sticker_engine/sticker_check.dart';
import 'synthetic_clip.dart';
import 'paste_lab_section.dart';
import 'whatsapp_lab_section.dart';
import '../../core/error_log.dart';

/// Phase 0 test screen: runs the real encoder on this phone and shows file
/// size, quality step and time. Opened by long-pressing "Peel." on Home.
///
/// TODO(launch): remove before release.
class EncoderLabScreen extends StatefulWidget {
  const EncoderLabScreen({super.key});

  @override
  State<EncoderLabScreen> createState() => _EncoderLabScreenState();
}

enum LabJob {
  still('Still sticker', 'Detailed photo cut-out'),
  cartoon3('3 s cartoon', 'Flat colours'),
  cartoon10('10 s cartoon', 'Flat colours, full length'),
  detailed10('10 s detailed', 'Worst case: camera grain');

  const LabJob(this.title, this.caption);

  final String title;
  final String caption;
}

class LabRun {
  const LabRun({
    required this.job,
    required this.kb,
    required this.detail,
    required this.millis,
    required this.passes,
    required this.problems,
  });

  final LabJob job;
  final double kb;
  final String detail;
  final int millis;
  final bool passes;
  final String problems;
}

/// Runs [job] on a background isolate so the UI stays smooth.
///
/// Must stay a top-level function: a closure created inside a widget's
/// method captures that widget's State, which can't be sent to an isolate.
Future<LabRun> runLabJobInBackground(LabJob job) =>
    Isolate.run(() => runLabJob(job));

Future<LabRun> runLabJob(LabJob job) async {
  final stopwatch = Stopwatch()..start();
  switch (job) {
    case LabJob.still:
      final clip = SyntheticClip(duration: Duration.zero, detailed: true);
      final result = StaticCompressor().compress(clip.render(0), clip.size);
      final check = checkSticker(
        result.bytes,
        kind: StickerKind.still,
        useOurTargets: true,
      );
      return LabRun(
        job: job,
        kb: result.bytes.length / 1024,
        detail: 'quality ${result.quality.round()} · ${result.attempts} tries',
        millis: stopwatch.elapsedMilliseconds,
        passes: check.passes,
        problems: check.problems.map((p) => p.name).join(', '),
      );
    case LabJob.cartoon3:
    case LabJob.cartoon10:
    case LabJob.detailed10:
      final clip = SyntheticClip(
        duration: Duration(seconds: job == LabJob.cartoon3 ? 3 : 10),
        detailed: job == LabJob.detailed10,
      );
      final result = await AnimatedCompressor().compress(clip);
      final check = checkSticker(
        result.bytes,
        kind: StickerKind.moving,
        useOurTargets: true,
      );
      return LabRun(
        job: job,
        kb: result.bytes.length / 1024,
        detail:
            '${result.rung} · ${result.frameCount} frames · '
            '${result.attempts} tries · ${result.quality.name}',
        millis: stopwatch.elapsedMilliseconds,
        passes: check.passes,
        problems: check.problems.map((p) => p.name).join(', '),
      );
  }
}

class _EncoderLabScreenState extends State<EncoderLabScreen> {
  final _runs = <LabRun>[];
  LabJob? _running;
  String? _error;

  Future<void> _run(LabJob job) async {
    setState(() {
      _running = job;
      _error = null;
    });
    try {
      final run = await runLabJobInBackground(job);
      if (!mounted) return;
      setState(() => _runs.insert(0, run));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            PeelSpace.gutter,
            8,
            PeelSpace.gutter,
            34,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: RoundIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Back',
                onPressed: () => context.pop(),
              ),
            ),
            const SizedBox(height: 20),
            Text('Encoder lab.', style: PeelType.title()),
            const SizedBox(height: 8),
            Text(
              'Runs the real sticker encoder on this phone. Targets: '
              '95 KB still, 480 KB moving.',
              style: PeelType.body(),
            ),
            const SizedBox(height: 20),
            for (final job in LabJob.values) ...[
              PrimaryPillButton(
                label: _running == job ? 'Running…' : job.title,
                onPressed: _running == null ? () => _run(job) : null,
              ),
              const SizedBox(height: 4),
              Text(job.caption, style: PeelType.caption()),
              const SizedBox(height: 12),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: PeelType.caption(color: const Color(0xFFB42318)),
                ),
              ),
            for (final run in _runs) _RunCard(run: run),
            const SizedBox(height: 32),
            const PasteLabSection(),
            const SizedBox(height: 32),
            const WhatsAppLabSection(),
            const SizedBox(height: 32),
            const _ErrorLogSection(),
          ],
        ),
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({required this.run});

  final LabRun run;

  @override
  Widget build(BuildContext context) {
    final pair = run.passes ? PeelPairs.mint : PeelPairs.bubblegum;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: ShapeDecoration(
        color: PeelColors.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(PeelRadii.tile),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(run.job.title, style: PeelType.label())),
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: pair.fill,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Text(
                    run.passes
                        ? 'Ready for WhatsApp'
                        : 'Fails: ${run.problems}',
                    style: PeelType.caption(color: pair.ink),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${run.kb.toStringAsFixed(1)} KB · '
            '${(run.millis / 1000).toStringAsFixed(1)} s',
            style: PeelType.body(color: PeelColors.ink),
          ),
          Text(run.detail, style: PeelType.caption()),
        ],
      ),
    );
  }
}

/// Errors recorded on this phone (no personal data), newest first.
class _ErrorLogSection extends StatefulWidget {
  const _ErrorLogSection();

  @override
  State<_ErrorLogSection> createState() => _ErrorLogSectionState();
}

class _ErrorLogSectionState extends State<_ErrorLogSection> {
  List<String> _lines = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lines = await ErrorLog.read();
    if (mounted) setState(() => _lines = lines);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Error log.', style: PeelType.title(size: 32)),
        const SizedBox(height: 8),
        if (_lines.isEmpty)
          Text('No errors recorded.', style: PeelType.body())
        else ...[
          for (final line in _lines.take(30))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SelectableText(
                line,
                style: PeelType.caption(color: PeelColors.ink),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () async {
                await ErrorLog.clear();
                await _load();
              },
              child: const Text('Clear log'),
            ),
          ),
        ],
      ],
    );
  }
}
