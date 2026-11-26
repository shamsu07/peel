import 'package:go_router/go_router.dart';

import '../../features/create/peeling_screen.dart';
import '../../features/export/no_whatsapp_screen.dart';
import '../../features/export/ready_screen.dart';
import '../../features/export/sent_screen.dart';
import '../../features/export/sound_handoff_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/lab/encoder_lab_screen.dart';
import '../../features/photo/photo_editor_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/text/text_editor_screen.dart';
import '../../features/video/making_screen.dart';
import '../../features/video/video_editor_screen.dart';
import 'routes.dart';

GoRouter buildRouter() => GoRouter(
  initialLocation: Routes.home,
  routes: [
    GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
    GoRoute(
      path: Routes.peeling,
      builder: (_, state) => PeelingScreen(imagePath: state.extra! as String),
    ),
    GoRoute(path: Routes.photo, builder: (_, _) => const PhotoEditorScreen()),
    GoRoute(
      path: Routes.photoText,
      builder: (_, _) => const TextEditorScreen(forVideo: false),
    ),
    GoRoute(path: Routes.video, builder: (_, _) => const VideoEditorScreen()),
    GoRoute(
      path: Routes.videoText,
      builder: (_, _) => const TextEditorScreen(forVideo: true),
    ),
    GoRoute(path: Routes.making, builder: (_, _) => const MakingScreen()),
    GoRoute(
      path: '/sticker/:id/ready',
      builder: (_, state) => ReadyScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/sticker/:id/sent',
      builder: (_, state) => SentScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/sticker/:id/sound',
      builder: (_, state) =>
          SoundHandoffScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: Routes.noWhatsApp,
      builder: (_, state) =>
          NoWhatsAppScreen(id: state.uri.queryParameters['id']),
    ),
    GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
    GoRoute(path: Routes.privacy, builder: (_, _) => InfoPage.privacy()),
    GoRoute(path: Routes.soundHelp, builder: (_, _) => InfoPage.soundHelp()),
    GoRoute(path: Routes.rulesHelp, builder: (_, _) => InfoPage.rulesHelp()),
    GoRoute(path: Routes.lab, builder: (_, _) => const EncoderLabScreen()),
  ],
);
