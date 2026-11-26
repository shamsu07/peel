import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../sticker_engine/sticker_check.dart';
import '../whatsapp/pack_store.dart';
import 'sticker_record.dart';

/// All the stickers the user made, kept on the phone only.
///
/// Layout: `<app support>/library/stickers.json` plus each sticker's WebP,
/// PNG preview, sound and hand-off video. A sticker joins a WhatsApp pack
/// (through [PackStore]) when the user adds it to WhatsApp.
class LibraryStore {
  LibraryStore(this.root, this.packs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static Future<LibraryStore> open(PackStore packs) async {
    final support = await getApplicationSupportDirectory();
    return LibraryStore(Directory('${support.path}/library'), packs);
  }

  final Directory root;
  final PackStore packs;
  final DateTime Function() _clock;

  File get _index => File('${root.path}/stickers.json');

  File file(String name) => File('${root.path}/$name');

  /// Newest first.
  Future<List<StickerRecord>> load() async {
    if (!await _index.exists()) return [];
    final list = jsonDecode(await _index.readAsString()) as List;
    return [
      for (final item in list)
        StickerRecord.fromJson((item as Map).cast<String, Object?>()),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _save(List<StickerRecord> records) async {
    await root.create(recursive: true);
    final tmp = File('${_index.path}.tmp');
    await tmp.writeAsString(
      jsonEncode([for (final r in records) r.toJson()]),
      flush: true,
    );
    await tmp.rename(_index.path);
  }

  /// Saves a finished sticker. It joins a pack later, in [assignToPack].
  Future<StickerRecord> add({
    required Uint8List webp,
    required Uint8List previewPng,
    Uint8List? trayPng,
    required StickerKind kind,
    required StickerSource source,
    StickerSound? sound,
    String accessibilityText = '',
  }) async {
    await root.create(recursive: true);
    final now = _clock();
    final id = 'st_${now.microsecondsSinceEpoch}';
    await file('$id.webp').writeAsBytes(webp, flush: true);
    await file('$id.png').writeAsBytes(previewPng, flush: true);

    final record = StickerRecord(
      id: id,
      kind: kind,
      source: source,
      createdAt: now,
      webpFile: '$id.webp',
      previewFile: '$id.png',
      sound: sound,
      accessibilityText: accessibilityText,
    );
    await _save([...await load(), record]);
    return record;
  }

  /// Puts [record] in the pack [identifier], taking it out of any other
  /// pack first. The sticker's own preview becomes the pack icon if the pack
  /// has none yet.
  Future<StickerRecord> assignToPack(
    StickerRecord record,
    String identifier,
    Uint8List trayPng,
  ) async {
    if (record.packIdentifier == identifier) return record;
    if (record.packIdentifier != null && record.packFile != null) {
      await packs.removeSticker(record.packIdentifier!, record.packFile!);
    }
    final (_, fileName) = await packs.addStickerTo(
      identifier,
      webp: await file(record.webpFile).readAsBytes(),
      trayPng: trayPng,
      emojis: record.emojis,
      accessibilityText: record.accessibilityText,
    );
    return update(
      record.copyWith(packIdentifier: identifier, packFile: fileName),
    );
  }

  Future<StickerRecord> update(StickerRecord record) async {
    final all = await load();
    await _save([for (final r in all) r.id == record.id ? record : r]);
    return record;
  }

  Future<void> markSent(Iterable<String> ids) async {
    final set = ids.toSet();
    final all = await load();
    await _save([
      for (final r in all)
        set.contains(r.id) ? r.copyWith(sentToWhatsApp: true) : r,
    ]);
  }

  /// Deletes a sticker and its files, and takes it out of its pack.
  Future<void> delete(StickerRecord record) async {
    final all = await load();
    await _save(all.where((r) => r.id != record.id).toList());
    for (final name in [
      record.webpFile,
      record.previewFile,
      if (record.handoffVideo != null) record.handoffVideo!,
    ]) {
      final f = file(name);
      if (await f.exists()) await f.delete();
    }
    final soundPath = record.sound?.path;
    if (soundPath != null && soundPath.startsWith(root.path)) {
      final f = File(soundPath);
      if (await f.exists()) await f.delete();
    }
    if (record.packIdentifier != null && record.packFile != null) {
      await packs.removeSticker(record.packIdentifier!, record.packFile!);
    }
  }

  /// A new file path inside the library for a sound or video.
  String newPath(String extension) =>
      '${root.path}/${_clock().microsecondsSinceEpoch}.$extension';
}
