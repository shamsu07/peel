/// Route paths, one per screen on the design canvas.
abstract final class Routes {
  static const home = '/';
  static const peeling = '/photo/peeling';
  static const photo = '/photo';
  static const photoText = '/photo/text';
  static const video = '/video';
  static const videoText = '/video/text';
  static const making = '/video/making';
  static const noWhatsApp = '/no-whatsapp';
  static const settings = '/settings';
  static const privacy = '/settings/privacy';
  static const soundHelp = '/settings/sound-help';
  static const rulesHelp = '/settings/rules';

  static String ready(String id) => '/sticker/$id/ready';
  static String sent(String id) => '/sticker/$id/sent';
  static String sound(String id) => '/sticker/$id/sound';
  static String noWhatsAppFor(String id) => '$noWhatsApp?id=$id';

  /// Phase 0 encoder test screen. Remove before launch.
  static const lab = '/lab';
}
