import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peel/features/lab/synthetic_clip.dart';
import 'package:peel/sticker_engine/compressor.dart';
import 'package:peel/sticker_engine/sticker_check.dart';
import 'package:peel/whatsapp/pack_store.dart';
import 'package:peel/whatsapp/whatsapp_bridge.dart';

/// A minimal PNG header claiming 96x96: enough for the tray checks.
Uint8List fakeTrayPng() {
  final b = BytesBuilder()
    ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    ..add([0, 0, 0, 13])
    ..add(ascii.encode('IHDR'))
    ..add([0, 0, 0, 96, 0, 0, 0, 96, 8, 6, 0, 0, 0]);
  return b.toBytes();
}

Uint8List stillSticker(int variant) {
  final clip = SyntheticClip(duration: Duration.zero, detailed: false);
  return StaticCompressor().compress(clip.render(variant * 300), 512).bytes;
}

Future<Uint8List> movingSticker() async => (await AnimatedCompressor().compress(
  SyntheticClip(duration: const Duration(seconds: 1), detailed: false),
)).bytes;

class FakeBonus implements BonusSource {
  FakeBonus(this.still, this.moving);

  final Uint8List still;
  final Uint8List moving;

  @override
  Future<List<BonusSticker>> bonusFor(StickerKind kind) async => [
    for (final id in ['okay', 'haha'])
      BonusSticker(
        fileName: 'bonus_${id}_${kind.name}.webp',
        bytes: kind == StickerKind.still ? still : moving,
        emojis: const ['👍'],
        accessibilityText: id,
      ),
  ];
}

void main() {
  late Directory tmp;
  late PackStore store;
  late Uint8List moving;
  var tick = 0;

  setUpAll(() async {
    moving = await movingSticker();
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('peel_packs_');
    store = PackStore(
      Directory('${tmp.path}/sticker_packs'),
      bonus: FakeBonus(stillSticker(99), moving),
      clock: () => DateTime.fromMicrosecondsSinceEpoch(++tick),
    );
  });

  tearDown(() => tmp.delete(recursive: true));

  Future<void> addStill(int n) async {
    for (var i = 0; i < n; i++) {
      await store.addSticker(
        webp: stillSticker(i),
        kind: StickerKind.still,
        trayPng: fakeTrayPng(),
      );
    }
  }

  test(
    'first sticker is padded with 2 bonus stickers and is sendable',
    () async {
      final pack = await store.addSticker(
        webp: stillSticker(0),
        kind: StickerKind.still,
        trayPng: fakeTrayPng(),
      );
      expect(pack.userStickers, hasLength(1));
      expect(pack.bonusCount, 2);
      expect(pack.identifier, 'peel_still_1');
      expect(pack.name, 'My Stickers');
      expect(await store.validate(pack), isEmpty);
    },
  );

  test('bonus stickers drop out as the user makes more', () async {
    await addStill(2);
    var pack = (await store.load()).packs.single;
    expect((pack.userStickers.length, pack.bonusCount), (2, 1));

    await addStill(1);
    pack = (await store.load()).packs.single;
    expect((pack.userStickers.length, pack.bonusCount), (3, 0));
    expect(pack.imageDataVersion, 3, reason: 'bumped on every change');
  });

  test('still and moving stickers go to separate packs', () async {
    await addStill(1);
    final movingPack = await store.addSticker(
      webp: moving,
      kind: StickerKind.moving,
      trayPng: fakeTrayPng(),
    );
    final packs = (await store.load()).packs;
    expect(packs.map((p) => p.identifier), ['peel_still_1', 'peel_moving_1']);
    expect(movingPack.animated, isTrue);
    expect(await store.validate(movingPack), isEmpty);
  });

  test('a moving sticker is refused in a still pack check', () async {
    expect(
      () => store.addSticker(
        webp: moving,
        kind: StickerKind.still,
        trayPng: fakeTrayPng(),
      ),
      throwsArgumentError,
    );
  });

  test('the 31st sticker starts a second pack', () async {
    await addStill(31);
    final packs = (await store.load()).packs;
    expect(packs.map((p) => p.name), ['My Stickers', 'My Stickers 2']);
    expect(packs.first.userStickers, hasLength(30));
    expect(packs.last.userStickers, hasLength(1));
    expect(packs.last.bonusCount, 2);
  });

  test('clearAll removes every pack and file', () async {
    await addStill(2);
    await store.clearAll();
    expect((await store.load()).packs, isEmpty);
    expect(await store.root.exists(), isFalse);
  });

  test('deleting refills with bonus stickers', () async {
    await addStill(3);
    final pack = (await store.load()).packs.single;
    final after = await store.removeSticker(
      pack.identifier,
      pack.userStickers.first.imageFile,
    );
    expect((after!.userStickers.length, after.bonusCount), (2, 1));
    expect(await store.validate(after), isEmpty);
  });

  test('iOS payload matches WhatsApp\'s pasteboard JSON', () async {
    await addStill(1);
    final pack = (await store.load()).packs.single;
    final json = jsonDecode(
      utf8.decode(await store.iosPayload(pack)),
    ) as Map<String, Object?>;
    expect(json['identifier'], 'peel_still_1');
    expect(json['publisher'], 'Peel');
    expect(json.containsKey('animated_sticker_pack'), isFalse);
    expect(base64Decode(json['tray_image']! as String), fakeTrayPng());
    final stickers = json['stickers']! as List;
    expect(stickers, hasLength(3));
    final first = stickers.first as Map;
    expect(
      checkSticker(
        base64Decode(first['image_data'] as String),
        kind: StickerKind.still,
      ).passes,
      isTrue,
    );
    expect(first['emojis'], isNotEmpty);
  });

  group('WhatsAppBridge', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('peel/whatsapp');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('Android: sends identifier and name, reads the outcome', () async {
      MethodCall? sent;
      messenger.setMockMethodCallHandler(channel, (call) async {
        sent = call;
        return {'outcome': 'rejected', 'message': 'tray too big'};
      });
      await addStill(1);
      final pack = (await store.load()).packs.single;
      final result = await WhatsAppBridge(
        channel: channel,
        isIOS: false,
      ).addPack(store, pack);
      expect(sent!.method, 'addPack');
      expect(sent!.arguments, {
        'identifier': 'peel_still_1',
        'name': 'My Stickers',
      });
      expect(result.outcome, AddPackOutcome.rejected);
      expect(result.message, 'tray too big');
    });

    test('iOS: sends the pasteboard payload', () async {
      MethodCall? sent;
      messenger.setMockMethodCallHandler(channel, (call) async {
        sent = call;
        return {'outcome': 'sentToWhatsApp'};
      });
      await addStill(1);
      final pack = (await store.load()).packs.single;
      final result = await WhatsAppBridge(
        channel: channel,
        isIOS: true,
      ).addPack(store, pack);
      expect(sent!.method, 'sendPack');
      expect((sent!.arguments as Map)['payload'], isA<Uint8List>());
      expect(result.outcome, AddPackOutcome.sentToWhatsApp);
    });

    test('an invalid pack is never sent', () async {
      var called = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        called = true;
        return null;
      });
      await addStill(1);
      final pack = (await store.load()).packs.single;
      await File(
        '${store.packDir(pack.identifier).path}/${PackStore.trayFileName}',
      ).delete();
      final result = await WhatsAppBridge(
        channel: channel,
        isIOS: false,
      ).addPack(store, pack);
      expect(result.outcome, AddPackOutcome.invalid);
      expect(called, isFalse);
    });
  });
}
