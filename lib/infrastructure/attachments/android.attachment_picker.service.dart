import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/services/attachment_picker.service.dart';
import 'package:messages/infrastructure/sms/android_sms.channel.dart';

/// [AttachmentPicker] adossé aux sélecteurs d'Android.
///
/// Aucun plugin tiers : l'app tient déjà son propre pont natif, et les
/// sélecteurs (`ACTION_PICK`, `ACTION_IMAGE_CAPTURE`, `ACTION_OPEN_DOCUMENT`)
/// sont des `Activity` à lancer — exactement ce que le pont sait faire pour la
/// demande de rôle SMS.
class AndroidAttachmentPicker implements AttachmentPicker {
  final AndroidSmsChannel _channel;

  const AndroidAttachmentPicker(this._channel);

  @override
  Future<List<AttachmentDraft>> pick(AttachmentSource source) =>
      _channel.pickAttachments(source);
}
