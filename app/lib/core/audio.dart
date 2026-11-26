import 'package:audio_session/audio_session.dart';

/// Plays sound through the speaker, even with the ring/silent switch on
/// silent, since the user tapped play. Call after recording, which leaves
/// iOS in a record-and-play mode that routes sound to the earpiece.
Future<void> useSpeakerForPlayback() async {
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } catch (_) {
    // Sound still plays, just maybe quieter; not worth failing for.
  }
}
