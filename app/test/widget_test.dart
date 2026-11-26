import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:peel/app.dart';
import 'package:peel/app_state.dart';
import 'package:peel/core/design/typography.dart';
import 'package:peel/library/sticker_record.dart';
import 'package:peel/sticker_engine/sticker_check.dart';

class _FakeLibrary extends LibraryNotifier {
  _FakeLibrary(this.records);

  final List<StickerRecord> records;

  @override
  Future<List<StickerRecord>> build() async => records;
}

StickerRecord _record(String id, {bool sent = false, bool sound = false}) =>
    StickerRecord(
      id: id,
      kind: StickerKind.still,
      source: StickerSource.photo,
      createdAt: DateTime(2026, 11, 26),
      webpFile: '$id.webp',
      previewFile: '$id.png',
      sentToWhatsApp: sent,
      sound: sound
          ? const StickerSound(
              origin: SoundOrigin.recording,
              startMs: 0,
              durationMs: 3000,
              path: '/tmp/x.m4a',
            )
          : null,
    );

void main() {
  setUpAll(() => PeelType.useBrandFonts = false);

  Future<void> pumpApp(
    WidgetTester tester, {
    List<StickerRecord> stickers = const [],
  }) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [libraryProvider.overrideWith(() => _FakeLibrary(stickers))],
        child: const PeelApp(warmUp: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('first run shows the two ways to make a sticker', (tester) async {
    await pumpApp(tester);

    expect(find.bySemanticsLabel('Peel'), findsOneWidget);
    expect(find.bySemanticsLabel('Snap. Peel. Send.'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Photo')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Video')), findsOneWidget);
    expect(find.text('Stickers with sound'), findsOneWidget);
    expect(
      find.text('No sign-up. Your photos never leave your phone.'),
      findsOneWidget,
    );
  });

  testWidgets('the sound card opens the New sticker sheet', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Stickers with sound'));
    await tester.pumpAndSettle();

    expect(find.text('New sticker.'), findsOneWidget);
    expect(find.text('Take a photo now'), findsOneWidget);
  });

  testWidgets('with stickers, home becomes My stickers', (tester) async {
    await pumpApp(
      tester,
      stickers: [_record('a'), _record('b', sent: true, sound: true)],
    );

    expect(find.text('My stickers.'), findsOneWidget);
    expect(find.text('Send 1 new to WhatsApp'), findsOneWidget);
    expect(find.text('New sticker'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
  });

  testWidgets('settings opens the privacy page', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings.'), findsOneWidget);
    expect(find.text('Your photos stay on this phone'), findsOneWidget);

    await tester.tap(find.text('Your photos stay on this phone'));
    await tester.pumpAndSettle();
    expect(find.text('Everything happens on your phone'), findsOneWidget);
  });
}
