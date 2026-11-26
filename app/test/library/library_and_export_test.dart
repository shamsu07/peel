import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peel/core/design/typography.dart';
import 'package:peel/features/lab/synthetic_clip.dart';
import 'package:peel/library/library_store.dart';
import 'package:peel/library/sticker_record.dart';
import 'package:peel/sticker_engine/compressor.dart';
import 'package:peel/sticker_engine/render.dart';
import 'package:peel/sticker_engine/sticker_check.dart';
import 'package:peel/whatsapp/exporter.dart';
import 'package:peel/whatsapp/pack_store.dart';
import 'package:peel/whatsapp/whatsapp_bridge.dart';

import '../whatsapp/pack_store_test.dart' show FakeBonus, fakeTrayPng;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => PeelType.useBrandFonts = false);

  late Directory tmp;
  late PackStore packs;
  late LibraryStore library;
  late Uint8List still;
  late Uint8List previewPng;
  var tick = 0;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('peel_lib_');
    final clip = SyntheticClip(duration: Duration.zero, detailed: false);
    still = StaticCompressor().compress(clip.render(0), 512).bytes;
    packs = PackStore(
      Directory('${tmp.path}/sticker_packs'),
      bonus: FakeBonus(still, still),
      clock: () => DateTime.fromMicrosecondsSinceEpoch(++tick),
    );
    library = LibraryStore(
      Directory('${tmp.path}/library'),
      packs,
      clock: () => DateTime.fromMicrosecondsSinceEpoch(++tick),
    );
  });

  tearDown(() => tmp.delete(recursive: true));

  Future<StickerRecord> add() => library.add(
    webp: still,
    previewPng: previewPng,
    trayPng: fakeTrayPng(),
    kind: StickerKind.still,
    source: StickerSource.photo,
  );

  testWidgets('library: add, newest first, mark sent, delete', (tester) async {
    await tester.runAsync(() async {
      final clip = SyntheticClip(duration: Duration.zero, detailed: false);
      previewPng = await pngFromRgba(clip.render(0), 512, 512);

      final a = await add();
      final b = await add();
      final all = await library.load();
      expect(all.map((r) => r.id), [b.id, a.id]);
      expect(a.packIdentifier, isNull, reason: 'packs are picked on send');
      expect(await library.file(a.webpFile).exists(), isTrue);

      final pack = await packs.createPack(StickerKind.still);
      final inPack = await library.assignToPack(
        a,
        pack.identifier,
        fakeTrayPng(),
      );
      await library.assignToPack(b, pack.identifier, fakeTrayPng());

      await library.markSent([a.id]);
      expect(
        (await library.load()).firstWhere((r) => r.id == a.id).sentToWhatsApp,
        isTrue,
      );

      await library.delete(inPack);
      expect((await library.load()).map((r) => r.id), [b.id]);
      expect(await library.file(a.webpFile).exists(), isFalse);
      final after = (await packs.load()).packs.single;
      expect(after.userStickers, hasLength(1));
      expect(after.bonusCount, 2, reason: 'refilled after the delete');
    });
  });

  group('exporter', () {
    const channel = MethodChannel('peel/whatsapp');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final sent = <MethodCall>[];

    setUp(() {
      sent.clear();
      messenger.setMockMethodCallHandler(channel, (call) async {
        sent.add(call);
        return {
          'outcome': call.method == 'sendPack' ? 'sentToWhatsApp' : 'added',
        };
      });
    });
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    WhatsAppExporter exporter({required bool ios}) => WhatsAppExporter(
      library: library,
      packs: packs,
      bridge: WhatsAppBridge(channel: channel, isIOS: ios),
      isIOS: ios,
    );

    testWidgets('a first sticker starts a new pack with two bonus', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final clip = SyntheticClip(duration: Duration.zero, detailed: false);
        previewPng = await pngFromRgba(clip.render(0), 512, 512);
        final ios = exporter(ios: true);

        expect(await ios.packsToJoin(StickerKind.still), isEmpty);
        final result = await ios.send([await add()]);
        expect(result.ok, isTrue);
        expect(result.packName, 'My Stickers');
        expect(sent.single.method, 'sendPack');
        final pack = (await packs.load()).packs.single;
        expect(pack.inWhatsApp, isTrue);
        expect(pack.userStickers, hasLength(1));
        expect(pack.bonusCount, 2);
        expect((await library.load()).single.sentToWhatsApp, isTrue);
      });
    });

    testWidgets('a later sticker can join that pack, dropping a bonus', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final clip = SyntheticClip(duration: Duration.zero, detailed: false);
        previewPng = await pngFromRgba(clip.render(0), 512, 512);
        final android = exporter(ios: false);

        await android.send([await add()]);
        final join = await android.packsToJoin(StickerKind.still);
        expect(join, hasLength(1));

        final result = await android.send([
          await add(),
        ], packIdentifier: join.single.identifier);
        expect(result.ok, isTrue);
        expect(sent, hasLength(2));
        expect(
          (sent.last.arguments as Map)['identifier'],
          join.single.identifier,
          reason: 'same pack, so WhatsApp updates it in place',
        );
        final pack = (await packs.load()).packs.single;
        expect(pack.userStickers, hasLength(2));
        expect(pack.bonusCount, 1);
      });
    });

    testWidgets('"New pack" makes a second, separately named pack', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final clip = SyntheticClip(duration: Duration.zero, detailed: false);
        previewPng = await pngFromRgba(clip.render(0), 512, 512);
        final ios = exporter(ios: true);
        await ios.send([await add()]);
        final second = await ios.send([await add()]);
        expect(second.packName, 'My Stickers 2');
        expect(await ios.packsToJoin(StickerKind.still), hasLength(2));
      });
    });

    testWidgets('a cancelled add leaves stickers unsent, and a retry reuses '
        'the same new pack', (tester) async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => {'outcome': 'cancelled'},
      );
      await tester.runAsync(() async {
        final clip = SyntheticClip(duration: Duration.zero, detailed: false);
        previewPng = await pngFromRgba(clip.render(0), 512, 512);
        final r = await add();
        final android = exporter(ios: false);
        final result = await android.send([r]);
        expect(result.outcome, SendOutcome.cancelled);
        expect((await library.load()).single.sentToWhatsApp, isFalse);
        expect(await android.packsToJoin(StickerKind.still), isEmpty);

        await android.send([(await library.load()).single]);
        expect((await packs.load()).packs, hasLength(1));
      });
    });
  });
}
