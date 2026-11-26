import 'package:flutter_test/flutter_test.dart';
import 'package:peel/features/lab/encoder_lab_screen.dart';
import 'package:peel/features/lab/whatsapp_lab_section.dart';
import 'package:peel/sticker_engine/sticker_check.dart';

/// The lab encodes on background isolates. These run the real isolate path,
/// which catches closures that accidentally capture widget state (they can't
/// be sent to another isolate).
void main() {
  test('encoder lab job runs on a background isolate', () async {
    final run = await runLabJobInBackground(LabJob.cartoon3);
    expect(run.passes, isTrue, reason: run.problems);
  });

  test('WhatsApp lab moving sticker encodes on a background isolate', () async {
    final bytes = await encodeTestMovingSticker();
    expect(checkSticker(bytes, kind: StickerKind.moving).passes, isTrue);
  });
}
