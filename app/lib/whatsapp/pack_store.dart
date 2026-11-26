import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../sticker_engine/sticker_check.dart';
import '../sticker_engine/whatsapp_rules.dart';
import 'pack_models.dart';

/// A ready-made filler sticker (spec §5.1: "Bonus").
class BonusSticker {
  const BonusSticker({
    required this.fileName,
    required this.bytes,
    required this.emojis,
    required this.accessibilityText,
  });

  final String fileName;
  final Uint8List bytes;
  final List<String> emojis;
  final String accessibilityText;
}

/// Supplies bonus stickers for each kind. A still pack needs still bonus
/// stickers and a moving pack needs moving ones (WhatsApp forbids mixing).
/// One sticker going into an iPhone batch pack.
class BatchSticker {
  const BatchSticker({
    required this.webp,
    this.emojis = const ['😀'],
    this.accessibilityText = '',
  });

  final Uint8List webp;
  final List<String> emojis;
  final String accessibilityText;
}

abstract interface class BonusSource {
  Future<List<BonusSticker>> bonusFor(StickerKind kind);
}

class PackProblem {
  const PackProblem(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Keeps the hidden auto-packs on disk, in the folder the Android
/// ContentProvider reads: `<app support>/sticker_packs/`.
///
/// Layout:
/// ```
/// sticker_packs/packs.json
/// sticker_packs/<identifier>/tray.png
/// sticker_packs/<identifier>/<sticker>.webp
/// ```
class PackStore {
  PackStore(this.root, {required this.bonus, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static Future<PackStore> open({required BonusSource bonus}) async {
    final support = await getApplicationSupportDirectory();
    return PackStore(Directory('${support.path}/sticker_packs'), bonus: bonus);
  }

  static const publisher = 'Peel';
  static const trayFileName = 'tray.png';

  final Directory root;
  final BonusSource bonus;
  final DateTime Function() _clock;

  File get _manifestFile => File('${root.path}/packs.json');

  Directory packDir(String identifier) => Directory('${root.path}/$identifier');

  File stickerFile(String identifier, String fileName) =>
      File('${root.path}/$identifier/$fileName');

  /// Deletes every pack this app stores. Packs already added to WhatsApp
  /// stay there until the user removes them in WhatsApp.
  Future<void> clearAll() async {
    if (await root.exists()) await root.delete(recursive: true);
  }

  Future<PackManifest> load() async {
    if (!await _manifestFile.exists()) return PackManifest.empty;
    final json = jsonDecode(await _manifestFile.readAsString());
    return PackManifest.fromJson((json as Map).cast<String, Object?>());
  }

  Future<void> _save(PackManifest manifest) async {
    await root.create(recursive: true);
    final tmp = File('${_manifestFile.path}.tmp');
    await tmp.writeAsString(jsonEncode(manifest.toJson()), flush: true);
    await tmp.rename(_manifestFile.path);
  }

  /// Adds a finished sticker to the current pack of its kind and returns
  /// that pack. Starts a new pack when the current one holds 30 of the
  /// user's stickers. [trayPng] becomes the pack icon if it has none yet.
  Future<PackEntry> addSticker({
    required Uint8List webp,
    required StickerKind kind,
    required Uint8List trayPng,
    List<String> emojis = const ['😀'],
    String accessibilityText = '',
  }) async {
    final check = checkSticker(webp, kind: kind);
    if (!check.passes) {
      throw ArgumentError('Sticker fails WhatsApp rules: ${check.problems}');
    }

    final manifest = await load();
    final packs = [...manifest.packs];
    var index = packs.lastIndexWhere((p) => p.kind == kind);
    if (index == -1 ||
        packs[index].userStickers.length >=
            WhatsAppStickerRules.maxStickersPerPack) {
      final number = packs.where((p) => p.kind == kind).length + 1;
      packs.add(_newPack(kind, number));
      index = packs.length - 1;
    }
    var pack = packs[index];

    final dir = packDir(pack.identifier);
    await dir.create(recursive: true);
    final fileName = 's_${_clock().microsecondsSinceEpoch}.webp';
    await stickerFile(
      pack.identifier,
      fileName,
    ).writeAsBytes(webp, flush: true);

    final tray = stickerFile(pack.identifier, trayFileName);
    if (!await tray.exists()) await tray.writeAsBytes(trayPng, flush: true);

    final users = [
      ...pack.userStickers,
      StickerEntry(
        imageFile: fileName,
        emojis: emojis,
        accessibilityText: accessibilityText,
      ),
    ];
    pack = await _withBonus(pack, users);
    packs[index] = pack;
    await _save(
      PackManifest(
        packs: packs,
        androidPlayStoreLink: manifest.androidPlayStoreLink,
        iosAppStoreLink: manifest.iosAppStoreLink,
      ),
    );
    return pack;
  }

  /// Packs of [kind] already in WhatsApp with room for [room] more of the
  /// user's stickers, newest first. These are the "existing packs" a new
  /// sticker can join.
  Future<List<PackEntry>> packsInWhatsApp(
    StickerKind kind, {
    int room = 1,
  }) async {
    final manifest = await load();
    return manifest.packs.reversed
        .where(
          (p) =>
              p.kind == kind &&
              p.inWhatsApp &&
              p.userStickers.length + room <=
                  WhatsAppStickerRules.maxStickersPerPack,
        )
        .toList();
  }

  /// The name a new pack of [kind] is offered: "My Stickers", then
  /// "My Stickers 2"… (or "My Video Stickers"…), skipping names in use.
  Future<String> suggestName(StickerKind kind) async {
    final taken = (await load()).packs.map((p) => p.name).toSet();
    final base = kind == StickerKind.still
        ? 'My Stickers'
        : 'My Video Stickers';
    var number = 1;
    while (taken.contains(number == 1 ? base : '$base $number')) {
      number++;
    }
    return number == 1 ? base : '$base $number';
  }

  /// Longest pack name we accept (WhatsApp allows 128 characters).
  static const maxNameLength = 40;

  /// Makes a new, empty pack of [kind], named [name] or the suggested name.
  Future<PackEntry> createPack(StickerKind kind, {String? name}) async {
    // Tidy up packs that never reached WhatsApp and have nothing left.
    final before = await load();
    final unused = before.packs
        .where((p) => !p.inWhatsApp && p.userStickers.isEmpty)
        .toList();
    for (final p in unused) {
      final dir = packDir(p.identifier);
      if (await dir.exists()) await dir.delete(recursive: true);
    }
    final manifest = PackManifest(
      packs: before.packs.where((p) => !unused.contains(p)).toList(),
      androidPlayStoreLink: before.androidPlayStoreLink,
      iosAppStoreLink: before.iosAppStoreLink,
    );
    final given = name?.trim() ?? '';
    final packName = given.isEmpty
        ? await suggestName(kind)
        : given.substring(0, given.length.clamp(0, maxNameLength));
    final prefix = kind == StickerKind.still ? 'peel_still_p' : 'peel_moving_p';
    final pack = PackEntry(
      identifier: '$prefix${_clock().microsecondsSinceEpoch}',
      name: packName,
      publisher: publisher,
      kind: kind,
      trayImageFile: trayFileName,
      imageDataVersion: 0,
      stickers: const [],
    );
    await packDir(pack.identifier).create(recursive: true);
    await _save(
      PackManifest(
        packs: [...manifest.packs, pack],
        androidPlayStoreLink: manifest.androidPlayStoreLink,
        iosAppStoreLink: manifest.iosAppStoreLink,
      ),
    );
    return pack;
  }

  /// Adds one of the user's stickers to the pack [identifier]. Returns the
  /// updated pack and the sticker's file name in it.
  Future<(PackEntry, String)> addStickerTo(
    String identifier, {
    required Uint8List webp,
    required Uint8List trayPng,
    List<String> emojis = const ['😀'],
    String accessibilityText = '',
  }) async {
    final manifest = await load();
    final packs = [...manifest.packs];
    final index = packs.indexWhere((p) => p.identifier == identifier);
    if (index == -1) throw ArgumentError('No pack $identifier');
    var pack = packs[index];
    final check = checkSticker(webp, kind: pack.kind);
    if (!check.passes) {
      throw ArgumentError('Sticker fails WhatsApp rules: ${check.problems}');
    }
    if (pack.userStickers.length >= WhatsAppStickerRules.maxStickersPerPack) {
      throw StateError('${pack.name} is full');
    }
    await packDir(identifier).create(recursive: true);
    final fileName = 's_${_clock().microsecondsSinceEpoch}.webp';
    await stickerFile(identifier, fileName).writeAsBytes(webp, flush: true);
    final tray = stickerFile(identifier, trayFileName);
    if (!await tray.exists()) await tray.writeAsBytes(trayPng, flush: true);
    pack = await _withBonus(pack, [
      ...pack.userStickers,
      StickerEntry(
        imageFile: fileName,
        emojis: emojis,
        accessibilityText: accessibilityText,
      ),
    ]);
    packs[index] = pack;
    await _save(
      PackManifest(
        packs: packs,
        androidPlayStoreLink: manifest.androidPlayStoreLink,
        iosAppStoreLink: manifest.iosAppStoreLink,
      ),
    );
    return (pack, fileName);
  }

  /// Renames a pack that hasn't reached WhatsApp yet.
  Future<void> renamePack(String identifier, String name) async {
    final manifest = await load();
    await _save(
      PackManifest(
        packs: [
          for (final p in manifest.packs)
            p.identifier == identifier ? p.copyWith(name: name) : p,
        ],
        androidPlayStoreLink: manifest.androidPlayStoreLink,
        iosAppStoreLink: manifest.iosAppStoreLink,
      ),
    );
  }

  /// Records that WhatsApp accepted the pack.
  Future<void> markInWhatsApp(String identifier) async {
    final manifest = await load();
    await _save(
      PackManifest(
        packs: [
          for (final p in manifest.packs)
            p.identifier == identifier ? p.copyWith(inWhatsApp: true) : p,
        ],
        androidPlayStoreLink: manifest.androidPlayStoreLink,
        iosAppStoreLink: manifest.iosAppStoreLink,
      ),
    );
  }

  /// iPhone only: WhatsApp on iOS can't update a pack (a re-send adds a
  /// duplicate; Phase 0, 26 Nov 2026). So each send becomes a new pack that
  /// holds only the stickers WhatsApp doesn't have yet, padded with bonus
  /// stickers when there are fewer than 3.
  Future<PackEntry> addBatchPack({
    required StickerKind kind,
    required List<BatchSticker> stickers,
    required Uint8List trayPng,
  }) async {
    if (stickers.isEmpty ||
        stickers.length > WhatsAppStickerRules.maxStickersPerPack) {
      throw ArgumentError('A batch needs 1 to 30 stickers');
    }
    final manifest = await load();
    final base = kind == StickerKind.still
        ? 'My Stickers'
        : 'My Video Stickers';
    final prefix = kind == StickerKind.still ? 'peel_still_b' : 'peel_moving_b';
    final number =
        manifest.packs.where((p) => p.identifier.startsWith(prefix)).length + 1;
    var pack = PackEntry(
      identifier: '$prefix$number',
      name: number == 1 ? base : '$base $number',
      publisher: publisher,
      kind: kind,
      trayImageFile: trayFileName,
      imageDataVersion: 0,
      stickers: const [],
    );
    await packDir(pack.identifier).create(recursive: true);
    await stickerFile(
      pack.identifier,
      trayFileName,
    ).writeAsBytes(trayPng, flush: true);
    final entries = <StickerEntry>[];
    for (var i = 0; i < stickers.length; i++) {
      final s = stickers[i];
      final name = 's_${i}_${_clock().microsecondsSinceEpoch}.webp';
      await stickerFile(
        pack.identifier,
        name,
      ).writeAsBytes(s.webp, flush: true);
      entries.add(
        StickerEntry(
          imageFile: name,
          emojis: s.emojis,
          accessibilityText: s.accessibilityText,
        ),
      );
    }
    pack = await _withBonus(pack, entries);
    await _save(
      PackManifest(
        packs: [...manifest.packs, pack],
        androidPlayStoreLink: manifest.androidPlayStoreLink,
        iosAppStoreLink: manifest.iosAppStoreLink,
      ),
    );
    return pack;
  }

  /// Removes one of the user's stickers. Bonus stickers refill the pack if
  /// it drops below 3.
  Future<PackEntry?> removeSticker(String identifier, String imageFile) async {
    final manifest = await load();
    final packs = [...manifest.packs];
    final index = packs.indexWhere((p) => p.identifier == identifier);
    if (index == -1) return null;

    final users = packs[index].userStickers
        .where((s) => s.imageFile != imageFile)
        .toList();
    final file = stickerFile(identifier, imageFile);
    if (await file.exists()) await file.delete();

    final pack = await _withBonus(packs[index], users);
    packs[index] = pack;
    await _save(
      PackManifest(
        packs: packs,
        androidPlayStoreLink: manifest.androidPlayStoreLink,
        iosAppStoreLink: manifest.iosAppStoreLink,
      ),
    );
    return pack;
  }

  /// Rebuilds the sticker list: the user's stickers first, then just enough
  /// bonus stickers to reach the minimum. Always bumps the version.
  Future<PackEntry> _withBonus(PackEntry pack, List<StickerEntry> users) async {
    final missing = WhatsAppStickerRules.minStickersPerPack - users.length;
    final fillers = <StickerEntry>[];
    if (missing > 0) {
      final available = await bonus.bonusFor(pack.kind);
      for (final b in available.take(missing)) {
        final file = stickerFile(pack.identifier, b.fileName);
        if (!await file.exists()) await file.writeAsBytes(b.bytes, flush: true);
        fillers.add(
          StickerEntry(
            imageFile: b.fileName,
            emojis: b.emojis,
            accessibilityText: b.accessibilityText,
            bonus: true,
          ),
        );
      }
    }
    return pack.copyWith(
      stickers: [...users, ...fillers],
      imageDataVersion: pack.imageDataVersion + 1,
    );
  }

  PackEntry _newPack(StickerKind kind, int number) {
    final base = kind == StickerKind.still
        ? 'My Stickers'
        : 'My Video Stickers';
    final id = kind == StickerKind.still ? 'peel_still' : 'peel_moving';
    return PackEntry(
      identifier: '${id}_$number',
      name: number == 1 ? base : '$base $number',
      publisher: publisher,
      kind: kind,
      trayImageFile: trayFileName,
      imageDataVersion: 0,
      stickers: const [],
    );
  }

  /// Checks a pack against WhatsApp's pack rules before sending it.
  Future<List<PackProblem>> validate(PackEntry pack) async {
    final problems = <PackProblem>[];
    final count = pack.stickers.length;
    if (count < WhatsAppStickerRules.minStickersPerPack ||
        count > WhatsAppStickerRules.maxStickersPerPack) {
      problems.add(PackProblem('Pack has $count stickers, needs 3 to 30'));
    }
    if (!WhatsAppStickerRules.isValidIdentifier(pack.identifier)) {
      problems.add(PackProblem('Bad identifier "${pack.identifier}"'));
    }
    final tray = stickerFile(pack.identifier, pack.trayImageFile);
    if (!await tray.exists()) {
      problems.add(const PackProblem('Tray icon missing'));
    } else {
      final png = await tray.readAsBytes();
      final size = pngSize(png);
      if (size == null ||
          size.$1 != WhatsAppStickerRules.trayIconPx ||
          size.$2 != WhatsAppStickerRules.trayIconPx) {
        problems.add(const PackProblem('Tray icon must be a 96x96 PNG'));
      }
      if (png.length > WhatsAppStickerRules.trayIconMaxBytes) {
        problems.add(const PackProblem('Tray icon over 50 KB'));
      }
    }
    for (final s in pack.stickers) {
      final file = stickerFile(pack.identifier, s.imageFile);
      if (!await file.exists()) {
        problems.add(PackProblem('Missing file ${s.imageFile}'));
        continue;
      }
      final check = checkSticker(await file.readAsBytes(), kind: pack.kind);
      if (!check.passes) {
        problems.add(PackProblem('${s.imageFile}: ${check.problems}'));
      }
      if (s.emojis.isEmpty ||
          s.emojis.length > WhatsAppStickerRules.maxEmojisPerSticker) {
        problems.add(PackProblem('${s.imageFile}: needs 1 to 3 emojis'));
      }
    }
    return problems;
  }

  /// The JSON WhatsApp on iOS reads from the pasteboard (see WhatsApp's
  /// sample StickerPack.sendToWhatsApp).
  Future<Uint8List> iosPayload(PackEntry pack) async {
    final manifest = await load();
    final tray = await stickerFile(
      pack.identifier,
      pack.trayImageFile,
    ).readAsBytes();
    final json = <String, Object?>{
      'identifier': pack.identifier,
      'name': pack.name,
      'publisher': pack.publisher,
      'tray_image': base64Encode(tray),
      if (pack.animated) 'animated_sticker_pack': true,
      if (manifest.iosAppStoreLink.isNotEmpty)
        'ios_app_store_link': manifest.iosAppStoreLink,
      if (manifest.androidPlayStoreLink.isNotEmpty)
        'android_play_store_link': manifest.androidPlayStoreLink,
      'stickers': [
        for (final s in pack.stickers)
          {
            'image_data': base64Encode(
              await stickerFile(pack.identifier, s.imageFile).readAsBytes(),
            ),
            'emojis': s.emojis,
            if (s.accessibilityText.isNotEmpty)
              'accessibility_text': s.accessibilityText,
          },
      ],
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(json)));
  }
}

/// Width and height from a PNG's IHDR chunk, or null if not a PNG.
(int, int)? pngSize(Uint8List bytes) {
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bytes.length < 24) return null;
  for (var i = 0; i < 8; i++) {
    if (bytes[i] != signature[i]) return null;
  }
  final data = ByteData.sublistView(bytes);
  return (data.getUint32(16), data.getUint32(20));
}
