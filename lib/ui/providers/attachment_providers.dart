import 'dart:typed_data';

import 'package:messages/core/application/dtos/attachment.dto.dart';
import 'package:messages/core/application/dtos/message.dto.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/services/attachment_picker.service.dart';
import 'package:messages/infrastructure/providers/repository_providers.dart';
import 'package:messages/infrastructure/providers/service_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'attachment_providers.g.dart';

/// Plateau de pièces jointes d'un fil en cours de rédaction.
///
/// Le contrôleur garde les brouillons du **domaine** et n'expose que des DTO :
/// c'est lui qui fait la frontière, pour que ni la page ni le champ de
/// rédaction n'aient à manipuler un `AttachmentDraft`. C'est aussi lui qui
/// envoie — le message et ses pièces jointes partent ensemble, et le plateau se
/// vide au même moment.
///
/// L'état est indexé par `threadId` : passer d'un fil à l'autre ne mélange pas
/// les plateaux, et revenir sur un fil retrouve ce qu'on y avait posé.
@riverpod
class AttachmentTray extends _$AttachmentTray {
  final List<AttachmentDraft> _drafts = [];

  @override
  List<AttachmentDraftDto> build(String threadId) => const [];

  /// Ouvre le sélecteur pour [source] et ajoute ce qui en revient.
  ///
  /// Propage les exceptions du domaine (plateau trop lourd, trop de pièces) :
  /// c'est la page qui sait comment le dire à l'utilisateur.
  Future<void> add(AttachmentSource source) async {
    final merged = await ref
        .read(pickAttachmentsUseCaseProvider)
        .execute(source, current: List.unmodifiable(_drafts));
    _replaceWith(merged);
  }

  /// Pose sur le plateau un vocal qu'on vient d'enregistrer.
  ///
  /// Il n'entre pas par [add] : il n'y a pas de sélecteur à ouvrir, et rien à
  /// alléger — un vocal ne se comprime pas, sa longueur a déjà été bornée au
  /// budget de l'opérateur pendant l'enregistrement. Seul le nombre de pièces
  /// jointes reste à vérifier, et c'est la même règle que pour une photo.
  Future<void> addRecording(AttachmentDraft draft) async {
    if (_drafts.length >= MmsLimits.maxCount) {
      throw const TooManyAttachmentsException();
    }
    _replaceWith([..._drafts, draft]);
  }

  /// Retire une vignette du plateau et libère ce qu'elle occupait.
  Future<void> remove(String draftId) async {
    final draft = _drafts.where((d) => d.id == draftId).firstOrNull;
    if (draft == null) return;
    _replaceWith(_drafts.where((d) => d.id != draftId).toList());
    await ref.read(attachmentRepositoryProvider).discardDraft(draft);
  }

  /// Envoie le plateau, puis le vide.
  ///
  /// Plusieurs pièces jointes donnent plusieurs messages, un par pièce — c'est
  /// [SendMessageUseCase] qui découpe. D'où la liste en retour.
  ///
  /// Le plateau n'est vidé qu'**après** un envoi accepté : une erreur laisse
  /// les pièces jointes en place, prêtes pour une nouvelle tentative, comme le
  /// texte que la page remet dans le champ.
  Future<List<MessageDto>> send({
    required List<String> recipients,
    required String body,
  }) async {
    final sent = await ref
        .read(sendMessageUseCaseProvider)
        .execute(
          recipients: recipients,
          body: body,
          attachments: List.unmodifiable(_drafts),
        );
    _replaceWith(const []);
    return sent;
  }

  /// Octets d'une vignette du plateau, pour son aperçu.
  Future<Uint8List?> bytesOf(String draftId) async {
    final draft = _drafts.where((d) => d.id == draftId).firstOrNull;
    if (draft == null) return null;
    return ref.read(attachmentRepositoryProvider).draftBytesOf(draft);
  }

  void _replaceWith(List<AttachmentDraft> drafts) {
    _drafts
      ..clear()
      ..addAll(drafts);
    state = _drafts.map(AttachmentDraftDto.fromDomain).toList();
  }
}

/// Octets d'une pièce jointe **du stock**, pour sa vignette dans une bulle.
///
/// Une famille par identifiant de partie : Riverpod garde le résultat en cache
/// tant que la bulle est à l'écran, et le relit une seule fois même si le fil
/// se reconstruit.
@riverpod
Future<Uint8List?> attachmentBytes(Ref ref, String attachmentId) =>
    ref.watch(attachmentRepositoryProvider).bytesOf(attachmentId);

/// Octets d'une pièce jointe **en cours de rédaction**, pour sa vignette dans
/// le plateau.
@riverpod
Future<Uint8List?> draftAttachmentBytes(
  Ref ref,
  String threadId,
  String draftId,
) {
  // Le plateau est la source : sa recomposition invalide les aperçus qu'il ne
  // porte plus.
  ref.watch(attachmentTrayProvider(threadId));
  return ref.read(attachmentTrayProvider(threadId).notifier).bytesOf(draftId);
}

/// Libellé de repli d'une pièce jointe sans nom, exposé à l'UI pour rester
/// aligné avec ce qu'affiche la liste des conversations.
String attachmentFallbackName(AttachmentKind kind) =>
    AttachmentDto.defaultFileNameFor(kind);
