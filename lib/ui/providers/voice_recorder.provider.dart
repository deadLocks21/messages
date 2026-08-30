import 'package:messages/core/application/dtos/attachment.dto.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/model/voice_recording.dart';
import 'package:messages/infrastructure/providers/service_providers.dart';
import 'package:messages/ui/providers/attachment_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'voice_recorder.provider.g.dart';

/// Enregistrement en cours, tel que le panneau le peint.
///
/// Un seul flux pour tout l'écran, comme pour la lecture : le micro n'existe
/// qu'en un exemplaire, et rien ne servirait d'ouvrir un abonnement par
/// panneau.
@riverpod
Stream<VoiceRecording> voiceRecording(Ref ref) =>
    ref.watch(recordVoiceMessageUseCaseProvider).recording;

/// Ce que montre le panneau : est-il ouvert, et y a-t-il un vocal prêt à
/// joindre ?
///
/// Le reste — le compteur, la piste, la suppression du bruit — vient du port,
/// pas d'ici : ce contrôleur ne tient pas le micro, il tient le geste.
class VoiceRecorderState {
  final bool isOpen;

  /// Le vocal enregistré, tant qu'il n'est ni joint ni jeté. C'est lui que le
  /// panneau donne à réécouter.
  final AttachmentDraftDto? recorded;

  const VoiceRecorderState({this.isOpen = false, this.recorded});

  static const closed = VoiceRecorderState();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceRecorderState &&
          runtimeType == other.runtimeType &&
          isOpen == other.isOpen &&
          recorded?.id == other.recorded?.id;

  @override
  int get hashCode => Object.hash(isOpen, recorded?.id);
}

/// Le panneau d'enregistrement d'un fil : son ouverture, et le vocal qu'il
/// détient entre l'arrêt et « Joindre ».
///
/// Indexé par `threadId` comme le plateau : c'est vers *ce* plateau-là que
/// partira le vocal, et un panneau qui suivrait l'utilisateur d'un fil à
/// l'autre poserait son enregistrement chez le mauvais destinataire.
///
/// Le brouillon du **domaine** reste privé : le panneau n'en voit que le DTO,
/// exactement comme le plateau.
@riverpod
class VoiceRecorder extends _$VoiceRecorder {
  AttachmentDraft? _draft;

  /// Le panneau est-il ouvert ? Doublé de l'état parce qu'`onDispose` ne peut
  /// pas le lire : un rappel de cycle de vie n'a plus le droit de toucher au
  /// `Ref` ni aux providers voisins.
  bool _isOpen = false;

  /// Un arrêt est-il déjà en cours ?
  ///
  /// Arrêter le micro fait passer le port en [VoiceRecordingPhase.recorded], ce
  /// que le veilleur ci-dessous prend pour un arrêt spontané et à quoi il
  /// répond par un second [stop]. Sans ce verrou, ce second arrêt aboutirait
  /// **après** « Joindre » et rouvrirait le panneau qu'on venait de refermer.
  bool _stopping = false;

  @override
  VoiceRecorderState build(String threadId) {
    // Capturé pendant le build, pour la même raison.
    final voice = ref.read(recordVoiceMessageUseCaseProvider);

    ref.listen(voiceRecordingProvider, (_, next) {
      // Le micro s'est refermé tout seul : le budget de l'opérateur est
      // atteint. Le brouillon attend d'être relevé — sans cela le panneau
      // resterait sur un compteur figé, avec un « Joindre » qui ne joindrait
      // rien.
      final recording = next.value;
      if (recording == null) return;
      // `stop` porte son propre verrou : l'arrêt qu'on vient de demander ne
      // se rejoue pas ici.
      if (recording.isRecorded && _isOpen && _draft == null) stop();
    });
    ref.onDispose(() {
      // Quitter le fil ne laisse pas un micro ouvert derrière soi.
      if (_isOpen) voice.discard();
    });
    return VoiceRecorderState.closed;
  }

  /// Un seul endroit pour publier : l'état et son double ne peuvent pas
  /// diverger.
  void _publish(VoiceRecorderState next) {
    _isOpen = next.isOpen;
    state = next;
  }

  /// Ouvre le panneau, sans rien enregistrer : c'est l'écran
  /// « appuyez pour enregistrer » de l'app d'origine.
  ///
  /// Le micro ne s'ouvre qu'au geste suivant — la permission se demande là où
  /// l'utilisateur comprend pourquoi on la lui demande.
  void open() {
    if (state.isOpen) return;
    _publish(const VoiceRecorderState(isOpen: true));
  }

  /// Ouvre le micro. Propage le refus : c'est la page qui sait le dire.
  Future<void> record() => ref.read(recordVoiceMessageUseCaseProvider).start();

  /// Referme le micro et garde ce qui a été dit, prêt à réécouter.
  Future<void> stop() async {
    if (_stopping) return;
    _stopping = true;
    try {
      final draft = await ref.read(recordVoiceMessageUseCaseProvider).stop();
      _draft = draft;
      // Le panneau a pu se refermer entre-temps — un « Annuler » pendant que
      // l'arrêt était en vol. Il ne se rouvre pas pour autant.
      if (!_isOpen) return;
      _publish(
        VoiceRecorderState(
          isOpen: true,
          recorded: draft == null ? null : AttachmentDraftDto.fromDomain(draft),
        ),
      );
    } finally {
      _stopping = false;
    }
  }

  /// « Recommencer » : le panneau reste ouvert et repart de rien, dans les deux
  /// états où le bouton existe — pendant l'enregistrement comme après.
  Future<void> restart() async {
    _draft = null;
    _publish(const VoiceRecorderState(isOpen: true));
    await ref.read(recordVoiceMessageUseCaseProvider).discard();
  }

  /// « Annuler » : même abandon, mais le panneau se referme.
  Future<void> close() async {
    _draft = null;
    _publish(VoiceRecorderState.closed);
    await ref.read(recordVoiceMessageUseCaseProvider).discard();
  }

  /// « Joindre » pendant qu'on parle : l'app d'origine ne demande pas d'appuyer
  /// d'abord sur « stop ». Le micro se referme et le vocal part sur le plateau
  /// dans le même geste.
  ///
  /// Un enregistrement trop court ne joint rien et laisse le panneau ouvert :
  /// il n'y a rien à envoyer, et le refermer effacerait un geste sans rien
  /// dire.
  Future<void> stopAndAttach() async {
    await stop();
    await attach();
  }

  /// « Joindre » : le vocal passe sur le plateau et le panneau se referme.
  ///
  /// Le brouillon **change de mains** — c'est le plateau qui décidera de son
  /// sort, et l'enregistreur n'a plus à l'effacer.
  Future<void> attach() async {
    final draft = _draft;
    if (draft == null) return;
    _draft = null;
    _publish(VoiceRecorderState.closed);
    await ref
        .read(attachmentTrayProvider(threadId).notifier)
        .addRecording(draft);
  }
}
