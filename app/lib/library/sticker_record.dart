import '../sticker_engine/sticker_check.dart';

enum StickerSource { photo, video }

/// Where a sticker's sound came from.
enum SoundOrigin { recording, file, original }

/// The sound attached to a sticker (spec P0-3).
class StickerSound {
  const StickerSound({
    required this.origin,
    required this.startMs,
    required this.durationMs,
    this.path,
    this.label,
  });

  factory StickerSound.fromJson(Map<String, Object?> json) => StickerSound(
    origin: SoundOrigin.values.byName(json['origin']! as String),
    startMs: json['startMs']! as int,
    durationMs: json['durationMs']! as int,
    path: json['path'] as String?,
    label: json['label'] as String?,
  );

  final SoundOrigin origin;

  /// Recording or audio file path; null for a video's original sound.
  final String? path;
  final int startMs;
  final int durationMs;

  /// What to show the user, e.g. "laugh-track.m4a" or "Your voice".
  final String? label;

  Map<String, Object?> toJson() => {
    'origin': origin.name,
    'startMs': startMs,
    'durationMs': durationMs,
    'path': path,
    'label': label,
  };
}

/// One sticker the user made. Users think in stickers, never packs.
class StickerRecord {
  const StickerRecord({
    required this.id,
    required this.kind,
    required this.source,
    required this.createdAt,
    required this.webpFile,
    required this.previewFile,
    this.sound,
    this.handoffVideo,
    this.packIdentifier,
    this.packFile,
    this.sentToWhatsApp = false,
    this.emojis = const ['😀'],
    this.accessibilityText = '',
  });

  factory StickerRecord.fromJson(Map<String, Object?> json) => StickerRecord(
    id: json['id']! as String,
    kind: StickerKind.values.byName(json['kind']! as String),
    source: StickerSource.values.byName(json['source']! as String),
    createdAt: DateTime.parse(json['createdAt']! as String),
    webpFile: json['webpFile']! as String,
    previewFile: json['previewFile']! as String,
    sound: json['sound'] == null
        ? null
        : StickerSound.fromJson((json['sound']! as Map).cast()),
    handoffVideo: json['handoffVideo'] as String?,
    packIdentifier: json['packIdentifier'] as String?,
    packFile: json['packFile'] as String?,
    sentToWhatsApp: (json['sentToWhatsApp'] as bool?) ?? false,
    emojis: ((json['emojis'] as List?) ?? const ['😀']).cast<String>(),
    accessibilityText: (json['accessibilityText'] as String?) ?? '',
  );

  final String id;
  final StickerKind kind;
  final StickerSource source;
  final DateTime createdAt;

  /// File names inside the library folder.
  final String webpFile;

  /// A PNG of the sticker (first frame for moving ones), for sharing,
  /// copying and the sound-sticker video.
  final String previewFile;

  final StickerSound? sound;

  /// The MP4 made for WhatsApp's "Create sticker" (stickers with sound).
  final String? handoffVideo;

  /// Which hidden pack holds it, and its file name there.
  final String? packIdentifier;
  final String? packFile;

  /// True once WhatsApp has received it.
  final bool sentToWhatsApp;

  final List<String> emojis;
  final String accessibilityText;

  bool get hasSound => sound != null;

  StickerRecord copyWith({
    StickerSound? sound,
    String? handoffVideo,
    String? packIdentifier,
    String? packFile,
    bool? sentToWhatsApp,
  }) => StickerRecord(
    id: id,
    kind: kind,
    source: source,
    createdAt: createdAt,
    webpFile: webpFile,
    previewFile: previewFile,
    sound: sound ?? this.sound,
    handoffVideo: handoffVideo ?? this.handoffVideo,
    packIdentifier: packIdentifier ?? this.packIdentifier,
    packFile: packFile ?? this.packFile,
    sentToWhatsApp: sentToWhatsApp ?? this.sentToWhatsApp,
    emojis: emojis,
    accessibilityText: accessibilityText,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'source': source.name,
    'createdAt': createdAt.toIso8601String(),
    'webpFile': webpFile,
    'previewFile': previewFile,
    'sound': sound?.toJson(),
    'handoffVideo': handoffVideo,
    'packIdentifier': packIdentifier,
    'packFile': packFile,
    'sentToWhatsApp': sentToWhatsApp,
    'emojis': emojis,
    'accessibilityText': accessibilityText,
  };
}
