import 'package:messages/core/domain/services/wallpaper.repository.dart';
import 'package:messages/infrastructure/sms/android_sms.channel.dart';

/// La copie est faite côté natif : c'est lui qui sait ouvrir un `content://`.
class AndroidWallpaperRepository implements WallpaperRepository {
  final AndroidSmsChannel _channel;

  const AndroidWallpaperRepository(this._channel);

  @override
  Future<String?> save({required String threadId, required String uri}) =>
      _channel.saveWallpaper(threadId: threadId, uri: uri);
}
