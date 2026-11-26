import '../sticker_engine/sticker_check.dart';

/// One sticker inside a pack, as stored in packs.json.
///
/// The JSON keys are shared with the Android ContentProvider
/// (StickerContentProvider.kt), so change both together.
class StickerEntry {
  const StickerEntry({
    required this.imageFile,
    required this.emojis,
    this.accessibilityText = '',
    this.bonus = false,
  });

  factory StickerEntry.fromJson(Map<String, Object?> json) => StickerEntry(
    imageFile: json['image_file']! as String,
    emojis: (json['emojis']! as List).cast<String>(),
    accessibilityText: (json['accessibility_text'] as String?) ?? '',
    bonus: (json['bonus'] as bool?) ?? false,
  );

  final String imageFile;
  final List<String> emojis;
  final String accessibilityText;

  /// Filler stickers we add so a pack reaches WhatsApp's minimum of 3.
  final bool bonus;

  Map<String, Object?> toJson() => {
    'image_file': imageFile,
    'emojis': emojis,
    'accessibility_text': accessibilityText,
    'bonus': bonus,
  };
}

/// One sticker pack. The user picks which pack a sticker goes into when
/// they add it to WhatsApp.
class PackEntry {
  const PackEntry({
    required this.identifier,
    required this.name,
    required this.publisher,
    required this.kind,
    required this.trayImageFile,
    required this.imageDataVersion,
    required this.stickers,
    this.inWhatsApp = false,
  });

  factory PackEntry.fromJson(Map<String, Object?> json) => PackEntry(
    identifier: json['identifier']! as String,
    name: json['name']! as String,
    publisher: json['publisher']! as String,
    kind: (json['animated_sticker_pack']! as bool)
        ? StickerKind.moving
        : StickerKind.still,
    trayImageFile: json['tray_image_file']! as String,
    imageDataVersion: int.parse(json['image_data_version']! as String),
    stickers: [
      for (final s in json['stickers']! as List)
        StickerEntry.fromJson((s as Map).cast<String, Object?>()),
    ],
    // Older iPhone "batch" packs (…_b1) were only ever made by sending.
    inWhatsApp:
        (json['in_whatsapp'] as bool?) ??
        RegExp(r'_b\d+$').hasMatch(json['identifier']! as String),
  );

  final String identifier;
  final String name;
  final String publisher;
  final StickerKind kind;
  final String trayImageFile;

  /// Bumped on every change so WhatsApp refreshes its cached copy.
  final int imageDataVersion;
  final List<StickerEntry> stickers;

  /// True once WhatsApp has accepted this pack.
  final bool inWhatsApp;

  bool get animated => kind == StickerKind.moving;

  List<StickerEntry> get userStickers =>
      stickers.where((s) => !s.bonus).toList();

  int get bonusCount => stickers.where((s) => s.bonus).length;

  PackEntry copyWith({
    String? name,
    String? trayImageFile,
    int? imageDataVersion,
    List<StickerEntry>? stickers,
    bool? inWhatsApp,
  }) => PackEntry(
    identifier: identifier,
    name: name ?? this.name,
    publisher: publisher,
    kind: kind,
    trayImageFile: trayImageFile ?? this.trayImageFile,
    imageDataVersion: imageDataVersion ?? this.imageDataVersion,
    stickers: stickers ?? this.stickers,
    inWhatsApp: inWhatsApp ?? this.inWhatsApp,
  );

  Map<String, Object?> toJson() => {
    'identifier': identifier,
    'name': name,
    'publisher': publisher,
    'animated_sticker_pack': animated,
    'tray_image_file': trayImageFile,
    'image_data_version': '$imageDataVersion',
    'stickers': [for (final s in stickers) s.toJson()],
    'in_whatsapp': inWhatsApp,
  };
}

class PackManifest {
  const PackManifest({
    required this.packs,
    this.androidPlayStoreLink = '',
    this.iosAppStoreLink = '',
  });

  factory PackManifest.fromJson(Map<String, Object?> json) => PackManifest(
    packs: [
      for (final p in json['packs']! as List)
        PackEntry.fromJson((p as Map).cast<String, Object?>()),
    ],
    androidPlayStoreLink: (json['android_play_store_link'] as String?) ?? '',
    iosAppStoreLink: (json['ios_app_store_link'] as String?) ?? '',
  );

  static const empty = PackManifest(packs: []);

  final List<PackEntry> packs;
  final String androidPlayStoreLink;
  final String iosAppStoreLink;

  Map<String, Object?> toJson() => {
    'packs': [for (final p in packs) p.toJson()],
    'android_play_store_link': androidPlayStoreLink,
    'ios_app_store_link': iosAppStoreLink,
  };
}
