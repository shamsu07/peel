import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_state.dart';
import '../../core/routing/routes.dart';
import '../../core/widgets/common.dart';
import '../../library/library_store.dart';
import '../../library/sticker_record.dart';
import '../../sticker_engine/sticker_check.dart';
import '../../whatsapp/exporter.dart';
import 'pack_picker.dart';

/// Things you can do with a finished sticker, shared by Ready, Sent and the
/// sticker details sheet.

/// Asks which pack the sticker joins (skipped when there's none to join),
/// then sends it. With [again], re-sends the pack it's already in (e.g. to
/// WhatsApp Business as well).
Future<void> sendToWhatsApp(
  BuildContext context,
  WidgetRef ref,
  StickerRecord record, {
  bool openSentScreen = true,
  bool again = false,
}) async {
  final exporter = await ref.read(exporterProvider.future);
  final SendResult result;
  if (again) {
    result = await exporter.resend(record);
  } else {
    if (!context.mounted) return;
    final choice = await choosePack(context, ref, kind: record.kind);
    if (choice == null) return;
    result = await exporter.send([record], packIdentifier: choice.identifier);
  }
  await ref.read(libraryProvider.notifier).reload();
  if (!context.mounted) return;
  switch (result.outcome) {
    case SendOutcome.sent:
      if (openSentScreen) {
        context.pushReplacement(Routes.sent(record.id));
      } else {
        showPeelSnack(
          context,
          result.packName == null
              ? 'Sent to WhatsApp.'
              : 'Added to ${result.packName} in WhatsApp.',
        );
      }
    case SendOutcome.notInstalled:
      context.push(Routes.noWhatsAppFor(record.id));
    case SendOutcome.cancelled:
      showPeelSnack(context, 'Not added. Tap Add to WhatsApp to try again.');
    case SendOutcome.nothingToSend:
      showPeelSnack(context, 'It’s already in WhatsApp.');
    case SendOutcome.rejected:
      showPeelSnack(
        context,
        'WhatsApp didn’t accept it${result.message == null ? '' : ': ${result.message}'}.',
      );
    case SendOutcome.failed:
      showPeelSnack(context, 'Something went wrong. Please try again.');
  }
}

Future<void> saveToPhotos(
  BuildContext context,
  WidgetRef ref,
  StickerRecord record,
) async {
  final library = await ref.read(libraryStoreProvider.future);
  try {
    if (!await Gal.hasPermission(toAlbum: true) &&
        !await Gal.requestPermission(toAlbum: true)) {
      if (context.mounted) {
        showPeelSnack(
          context,
          'Peel can’t save to Photos. Allow it in Settings.',
        );
      }
      return;
    }
    // Stickers with a square video (moving ones, and any with sound) save
    // as that video, sound included: Photos shows an animated WebP as a
    // still, and a picture can't carry sound. Silent stills save as a PNG.
    final video = record.handoffVideo;
    if (video != null && await library.file(video).exists()) {
      await Gal.putVideo(library.file(video).path, album: 'Peel');
    } else if (record.kind == StickerKind.moving) {
      await Gal.putImage(library.file(record.webpFile).path, album: 'Peel');
    } else {
      await Gal.putImage(library.file(record.previewFile).path, album: 'Peel');
    }
    if (context.mounted) showPeelSnack(context, 'Saved to Photos.');
  } on GalException catch (e) {
    if (context.mounted) {
      showPeelSnack(context, 'Couldn’t save: ${e.type.message}');
    }
  }
}

Future<void> shareSticker(WidgetRef ref, StickerRecord record) async {
  final library = await ref.read(libraryStoreProvider.future);
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile(library.file(record.webpFile).path, mimeType: 'image/webp'),
      ],
    ),
  );
}

/// Phase 0 test of the iPhone single-sticker route: copy, then paste into a
/// WhatsApp chat.
Future<void> copySticker(
  BuildContext context,
  WidgetRef ref,
  StickerRecord record,
) async {
  final library = await ref.read(libraryStoreProvider.future);
  final ok = await ref
      .read(nativeProvider)
      .copyStickerToClipboard(
        library.file(record.webpFile).path,
        library.file(record.previewFile).path,
      );
  if (context.mounted) {
    showPeelSnack(
      context,
      ok
          ? 'Copied. Paste it into a WhatsApp chat.'
          : 'Couldn’t copy this sticker.',
    );
  }
}

Future<bool> saveHandoffVideo(
  BuildContext context,
  WidgetRef ref,
  StickerRecord record,
) async {
  final video = record.handoffVideo;
  if (video == null) return false;
  final library = await ref.read(libraryStoreProvider.future);
  try {
    if (!await Gal.hasPermission(toAlbum: true) &&
        !await Gal.requestPermission(toAlbum: true)) {
      return false;
    }
    await Gal.putVideo(library.file(video).path, album: 'Peel');
    return true;
  } on GalException {
    return false;
  }
}

/// What to play for a sticker's sound: its audio file, or the sound track of
/// its video (for a video's original sound). Null when it has no sound.
({String path, int startMs, int durationMs})? soundSource(
  LibraryStore? library,
  StickerRecord r,
) {
  final sound = r.sound;
  if (sound == null) return null;
  if (sound.path != null) {
    return (
      path: sound.path!,
      startMs: sound.startMs,
      durationMs: sound.durationMs,
    );
  }
  if (library != null && r.handoffVideo != null) {
    return (
      path: library.file(r.handoffVideo!).path,
      startMs: 0,
      durationMs: sound.durationMs,
    );
  }
  return null;
}
