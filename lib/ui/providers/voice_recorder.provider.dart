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

/// **Qui montre l'enregistrement** — ce n'est pas la même question que « où en
/// est le micro », à laquelle répond [VoiceRecording].
///
/// L'app d'origine a deux gestes pour un même micro, et deux surfaces pour les
/// porter : un appui bref ouvre le panneau, un appui **maintenu** transforme le
/// champ de rédaction lui-même. Le port, lui, ne connaît qu'un enregistrement.
enum VoiceRecorderSurface {
  /// Rien : le champ de rédaction est intact.
  none,

  /// Le panneau sous le champ, ouvert d'un appui bref.
  panel,

  /// Le doigt tient le disque : le champ devient la barre
  /// « Faire glisser pour annuler », et lever le doigt joint le vocal.
  hold,
}

/// Ce que montre l'enregistreur : par où, et y a-t-il un vocal prêt à joindre ?
///
/// Le reste — le compteur, la piste, la suppression du bruit — vient du port,
/// pas d'ici : ce contrôleur ne tient pas le micro, il tient le geste.
class VoiceRecorderState {
  final VoiceRecorderSurface surface;

  /// Le vocal enregistré, tant qu'il n'est ni joint ni jeté. C'est lui que le
  /// panneau donne à réécouter.
  final AttachmentDraftDto? recorded;

  const VoiceRecorderState({
    this.surface = VoiceRecorderSurface.none,
    this.recorded,
  });

  static const closed = VoiceRecorderState();

  /// Le micro est-il montré quelque part ? C'est ce qui décide s'il faut le
  /// refermer en quittant le fil, quelle que soit la surface qui l'affiche.
  bool get isOpen => surface != VoiceRecorderSurface.none;

  bool get isPanel => surface == VoiceRecorderSurface.panel;
  bool get isHeld => surface == VoiceRecorderSurface.hold;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceRecorderState &&
          runtimeType == other.runtimeType &&
          surface == other.surface &&
          recorded?.id == other.recorded?.id;

  @override
  int get hashCode => Object.hash(surface, recorded?.id);
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

  /// Qui montre l'enregistrement ? Doublé de l'état parce qu'`onDispose` ne
  /// peut pas le lire : un rappel de cycle de vie n'a plus le droit de toucher
  /// au `Ref` ni aux providers voisins.
  VoiceRecorderSurface _surface = VoiceRecorderSurface.none;

  bool get _isOpen => _surface != VoiceRecorderSurface.none;

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
      if (!recording.isRecorded || !_isOpen || _draft != null) return;
      // Le panneau relève le brouillon et attend « Joindre ». L'appui
      // maintenu, lui, n'a plus de doigt à attendre : le vocal part sur le
      // plateau comme s'il venait d'être relâché — laisser une barre à
      // compteur figé sous un doigt qui ne commande plus rien serait pire.
      if (_surface == VoiceRecorderSurface.hold) {
        release();
      } else {
        stop();
      }
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
    _surface = next.surface;
    state = next;
  }

  /// Ouvre le panneau, sans rien enregistrer : c'est l'écran
  /// « appuyez pour enregistrer » de l'app d'origine.
  ///
  /// Le micro ne s'ouvre qu'au geste suivant — la permission se demande là où
  /// l'utilisateur comprend pourquoi on la lui demande.
  void open() {
    if (state.isOpen) return;
    _publish(const VoiceRecorderState(surface: VoiceRecorderSurface.panel));
  }

  /// **Appui maintenu** : le micro s'ouvre dans le même geste, sans passer par
  /// le panneau, et c'est le champ de rédaction qui devient la barre.
  ///
  /// La surface est publiée **avant** d'ouvrir le micro, et non après : entre
  /// les deux il y a une permission à demander, et un doigt levé pendant ce
  /// temps doit trouver un enregistrement à annuler — sinon [release] ne
  /// reconnaît pas le geste qu'il termine et le micro reste ouvert.
  ///
  /// Rend `false` quand l'appui n'a rien à prendre : le panneau tient déjà le
  /// micro, et deux surfaces pour un même enregistrement se contrediraient.
  /// Propage le refus du micro : c'est la page qui sait le dire.
  Future<bool> hold() async {
    if (state.isOpen) return false;
    _publish(const VoiceRecorderState(surface: VoiceRecorderSurface.hold));
    try {
      await record();
    } catch (_) {
      _publish(VoiceRecorderState.closed);
      rethrow;
    }
    return true;
  }

  /// Le doigt a glissé sur le **cadenas** : l'enregistrement continue sans lui.
  ///
  /// Le panneau prend le relais — il porte déjà « stop », « Recommencer » et
  /// « Joindre », et c'est exactement ce qu'un enregistrement sans doigt
  /// réclame. Le micro, lui, n'a rien vu passer : verrouiller n'est pas une
  /// opération d'enregistrement mais un changement de main.
  void lock() {
    if (!state.isHeld) return;
    _publish(const VoiceRecorderState(surface: VoiceRecorderSurface.panel));
  }

  /// Le doigt s'est **levé** : le micro se referme et le vocal part sur le
  /// plateau dans le même geste — l'app d'origine ne fait pas relire ce qu'on
  /// vient de dire, elle le pose.
  ///
  /// Trop court pour être un message, il ne reste rien : le champ redevient
  /// simplement lui-même. Un appui malheureux ne laisse pas de trace.
  Future<void> release() async {
    if (!state.isHeld) return;
    await stop();
    if (_draft == null) {
      _publish(VoiceRecorderState.closed);
      return;
    }
    await attach();
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
          // La surface ne change pas en s'arrêtant : c'est le panneau qui
          // relève le brouillon, ou la barre qui finit son geste.
          surface: _surface,
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
    _publish(const VoiceRecorderState(surface: VoiceRecorderSurface.panel));
    await ref.read(recordVoiceMessageUseCaseProvider).discard();
  }

  /// « Annuler », et le glissé vers la **corbeille** : même abandon, mais la
  /// surface se referme. Les deux gestes disent la même chose — ce qui vient
  /// d'être dit ne partira pas.
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
        .addReady(draft);
  }
}
