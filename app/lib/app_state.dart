import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peel_native/peel_native.dart';

import 'library/library_store.dart';
import 'library/sticker_record.dart';
import 'whatsapp/bonus_stickers.dart';
import 'whatsapp/exporter.dart';
import 'whatsapp/pack_store.dart';
import 'whatsapp/whatsapp_bridge.dart';

/// App-wide services, created once.

final nativeProvider = Provider<PeelNativeApi>((ref) => PeelNativeApi());

final bridgeProvider = Provider<WhatsAppBridge>((ref) => WhatsAppBridge());

final bonusProvider = Provider<BonusSource>((ref) => DrawnBonusSource());

final packStoreProvider = FutureProvider<PackStore>(
  (ref) => PackStore.open(bonus: ref.watch(bonusProvider)),
);

final libraryStoreProvider = FutureProvider<LibraryStore>(
  (ref) async => LibraryStore.open(await ref.watch(packStoreProvider.future)),
);

final exporterProvider = FutureProvider<WhatsAppExporter>(
  (ref) async => WhatsAppExporter(
    library: await ref.watch(libraryStoreProvider.future),
    packs: await ref.watch(packStoreProvider.future),
    bridge: ref.watch(bridgeProvider),
  ),
);

/// The user's stickers, newest first.
class LibraryNotifier extends AsyncNotifier<List<StickerRecord>> {
  @override
  Future<List<StickerRecord>> build() async =>
      (await ref.watch(libraryStoreProvider.future)).load();

  Future<void> reload() async {
    final store = await ref.read(libraryStoreProvider.future);
    state = AsyncData(await store.load());
  }

  /// Hides a sticker straight away (for "Undo"), without deleting it.
  void hide(String id) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.where((r) => r.id != id).toList());
  }
}

final libraryProvider =
    AsyncNotifierProvider<LibraryNotifier, List<StickerRecord>>(
      LibraryNotifier.new,
    );

StickerRecord? findSticker(WidgetRef ref, String id) =>
    ref.read(libraryProvider).value?.where((r) => r.id == id).firstOrNull;
