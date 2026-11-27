# peel_native

Peel's own Flutter plugin: the native work Dart can't do well on its own.

- **Cut-outs:** ML Kit Subject Segmentation on Android, Vision on iOS.
- **Video:** frame extraction and trimming (Media3 / AVFoundation).
- **WhatsApp:** the sticker pack bridge (ContentProvider on Android,
  pasteboard hand-off on iOS) and the sound-sticker MP4 hand-off.
- **Clipboard:** copying stickers and GIFs.

The Dart ↔ native API is generated with [Pigeon](https://pub.dev/packages/pigeon)
from `pigeon/messages.dart`. After changing it, run from this folder:

```bash
dart run pigeon --input pigeon/messages.dart
```

This package is internal to Peel and not published to pub.dev.
