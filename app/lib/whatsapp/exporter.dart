import 'dart:io';

import '../library/library_store.dart';
import '../library/sticker_record.dart';
import '../sticker_engine/render.dart';
import '../sticker_engine/sticker_check.dart';
import 'pack_models.dart';
import 'pack_store.dart';
import 'whatsapp_bridge.dart';

enum SendOutcome {
  /// Android: WhatsApp confirmed. iOS: handed over to WhatsApp's preview.
  sent,
  cancelled,
  rejected,
  notInstalled,
  nothingToSend,
  failed,
}

class SendResult {
  const SendResult(this.outcome, {this.message, this.packName});

  final SendOutcome outcome;
  final String? message;

  /// The pack the stickers went into, when sent.
  final String? packName;

  bool get ok => outcome == SendOutcome.sent;
}

/// Gets the user's stickers into WhatsApp, into a pack they pick: an
/// existing one, or a new one.
///
/// - Android: WhatsApp re-reads a pack from our ContentProvider, so adding a
///   sticker to a pack it already has updates that pack in place.
/// - iPhone: WhatsApp can't update a pack. Sending a pack it already has
///   adds a second copy with the new stickers (Phase 0, 26 Nov 2026); the
///   pack picker says so.
class WhatsAppExporter {
  WhatsAppExporter({
    required this.library,
    required this.packs,
    required this.bridge,
    bool? isIOS,
  }) : _isIOS = isIOS ?? Platform.isIOS;

  final LibraryStore library;
  final PackStore packs;
  final WhatsAppBridge bridge;
  final bool _isIOS;

  /// True when adding to a pack WhatsApp already has makes a second copy.
  bool get updatesMakeCopies => _isIOS;

  /// Packs already in WhatsApp that [count] more stickers of [kind] fit in.
  Future<List<PackEntry>> packsToJoin(StickerKind kind, {int count = 1}) =>
      packs.packsInWhatsApp(kind, room: count);

  /// The name offered for a new pack of [kind].
  Future<String> suggestPackName(StickerKind kind) => packs.suggestName(kind);

  /// Adds [records] (all one kind) to the pack [packIdentifier], or to a new
  /// pack called [newPackName] when it's null, and sends that pack to
  /// WhatsApp.
  Future<SendResult> send(
    List<StickerRecord> records, {
    String? packIdentifier,
    String? newPackName,
  }) async {
    if (records.isEmpty) return const SendResult(SendOutcome.nothingToSend);
    final kind = records.first.kind;
    assert(records.every((r) => r.kind == kind), 'one kind per pack');
    try {
      final id = packIdentifier ?? await _newPackFor(records, newPackName);
      for (final r in records) {
        final tray = await trayPngFromImageFile(
          library.file(r.previewFile).path,
        );
        await library.assignToPack(r, id, tray);
      }
      final pack = (await packs.load()).packs.firstWhere(
        (p) => p.identifier == id,
      );
      final result = _map(await bridge.addPack(packs, pack), pack.name);
      if (result.ok) {
        await packs.markInWhatsApp(id);
        await library.markSent(records.map((r) => r.id));
      }
      return result;
    } catch (e) {
      return SendResult(SendOutcome.failed, message: '$e');
    }
  }

  /// A new pack for [records], or the unsent one they were put in by an
  /// earlier try that was cancelled.
  Future<String> _newPackFor(List<StickerRecord> records, String? name) async {
    final earlier = records.first.packIdentifier;
    if (earlier != null && records.every((r) => r.packIdentifier == earlier)) {
      final pack = (await packs.load()).packs
          .where((p) => p.identifier == earlier)
          .firstOrNull;
      if (pack != null &&
          !pack.inWhatsApp &&
          pack.userStickers.length == records.length) {
        final wanted = name?.trim() ?? '';
        if (wanted.isNotEmpty && wanted != pack.name) {
          await packs.renamePack(earlier, wanted);
        }
        return earlier;
      }
    }
    return (await packs.createPack(records.first.kind, name: name)).identifier;
  }

  /// Sends the pack [record] is in again, e.g. to WhatsApp Business too.
  Future<SendResult> resend(StickerRecord record) async {
    final pack = await packOf(record);
    if (pack == null) return send([record]);
    try {
      return _map(await bridge.addPack(packs, pack), pack.name);
    } catch (e) {
      return SendResult(SendOutcome.failed, message: '$e');
    }
  }

  static SendResult _map(AddPackResult r, String packName) =>
      switch (r.outcome) {
        AddPackOutcome.added || AddPackOutcome.sentToWhatsApp => SendResult(
          SendOutcome.sent,
          packName: packName,
        ),
        AddPackOutcome.cancelled => const SendResult(SendOutcome.cancelled),
        AddPackOutcome.rejected => SendResult(
          SendOutcome.rejected,
          message: r.message,
        ),
        AddPackOutcome.notInstalled => const SendResult(
          SendOutcome.notInstalled,
        ),
        AddPackOutcome.invalid => SendResult(
          SendOutcome.failed,
          message: r.problems.join(', '),
        ),
      };

  /// The pack that holds [record], if any.
  Future<PackEntry?> packOf(StickerRecord record) async {
    final id = record.packIdentifier;
    if (id == null) return null;
    return (await packs.load()).packs
        .where((p) => p.identifier == id)
        .firstOrNull;
  }
}
