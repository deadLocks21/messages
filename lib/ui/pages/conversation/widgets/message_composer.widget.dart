import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:messages/ui/pages/conversation/widgets/voice_hold_bar.widget.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Champ de rédaction : une pilule pleine — pièce jointe et texte — flanquée
/// du disque rond, comme dans Google Messages.
///
/// **Le disque de droite n'est pas toujours le même bouton.** Tant qu'il n'y a
/// rien à envoyer, c'est celui du **message vocal** ; dès qu'il y a un texte ou
/// une pièce jointe, il devient le bouton d'**envoi**. C'est ce que fait l'app
/// d'origine, et c'est ce qui rend le vocal atteignable sans rien encombrer :
/// il occupe la place d'un bouton d'envoi qui, de toute façon, n'aurait rien à
/// envoyer.
///
/// **Et ce disque-là porte deux gestes**, comme dans l'app d'origine :
///
/// | Geste | Ce qui arrive |
/// |---|---|
/// | Appui bref | Le panneau d'enregistrement s'ouvre sous le champ. |
/// | Appui **maintenu** | Le micro s'ouvre tout de suite ; la pilule devient la barre « Faire glisser pour annuler », le disque gonfle et rougit, et une pastille cadenas apparaît au-dessus. |
/// | Relâcher | Le vocal est **joint** — pas envoyé : l'app d'origine laisse ajouter une légende. |
/// | Glisser vers la corbeille | Annulé, et rien n'a existé. |
/// | Glisser vers le cadenas | L'enregistrement continue sans le doigt, et le panneau prend le relais. |
///
/// C'est le geste rapide de la messagerie : dire trois mots ne demande alors
/// qu'un appui, là où le panneau en demande trois.
///
/// Le compteur de segments SMS ne s'affiche qu'au-delà d'un message — comme
/// l'app d'origine, qui ne montre `n/2` que quand le découpage devient réel.
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.enabled,
    this.onAttach,
    this.onEmoji,
    this.emojiOpen = false,
    this.onVoice,
    this.onVoiceHold,
    this.onVoiceCancel,
    this.onVoiceLock,
    this.onVoiceRelease,
    this.hasAttachments = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final bool enabled;
  final VoidCallback? onAttach;

  /// Ouvre — ou referme — le panneau des emoji et des GIF.
  ///
  /// C'est le **même bouton dans les deux sens**, comme dans l'app d'origine
  /// où son libellé d'accessibilité passe de « Afficher » à « Masquer » : la
  /// main est déjà là, et c'est le geste le plus court pour récupérer le
  /// clavier.
  final VoidCallback? onEmoji;

  /// Le panneau est-il ouvert ? Le bouton le dit en se remplissant, comme le
  /// « + » se remplit quand le plateau porte quelque chose.
  final bool emojiOpen;

  /// Ouvre le panneau d'enregistrement. Null quand l'app ne sait pas
  /// enregistrer.
  final VoidCallback? onVoice;

  /// Ouvre le micro sous le doigt qui maintient le disque.
  ///
  /// Rend `false` quand il ne s'est pas ouvert — micro refusé, encodeur
  /// occupé, panneau déjà en train de tenir le micro : le champ n'a alors
  /// **pas de barre à peindre**, et c'est la page qui dira pourquoi. Peindre
  /// la barre avant de savoir reviendrait à promettre un enregistrement qui
  /// n'a pas commencé.
  final Future<bool> Function()? onVoiceHold;

  /// Le doigt a glissé jusqu'à la corbeille.
  final VoidCallback? onVoiceCancel;

  /// Le doigt a glissé jusqu'au cadenas.
  final VoidCallback? onVoiceLock;

  /// Le doigt s'est levé.
  final VoidCallback? onVoiceRelease;

  /// Le plateau au-dessus porte-t-il quelque chose ? Une photo seule est un
  /// message valide : le bouton d'envoi doit s'allumer même le champ vide.
  final bool hasAttachments;

  /// Hauteur de la pilule quand le champ tient sur une ligne. C'est aussi la
  /// hauteur de la boîte du bouton « + » et du disque d'envoi : les trois se
  /// mesurent l'un sur l'autre, sinon ils dérivent.
  static const pillHeight = 56.0;

  /// Le disque sous le doigt qui enregistre. Relevé sur l'appareil : 152 px
  /// de diamètre contre 132 au repos, soit un huitième de plus — juste assez
  /// pour qu'on sente le bouton répondre, pas assez pour qu'il saute.
  ///
  /// Il **déborde** de sa boîte plutôt que de l'agrandir : une pilule qui
  /// changerait de hauteur pousserait tout le fil de quatre pixels au moment
  /// précis où l'utilisateur ne regarde que son doigt.
  static const heldButtonSize = 64.0;

  /// Ce qu'il faut glisser vers la gauche pour annuler, et vers le haut pour
  /// verrouiller. Deux distances différentes parce que les deux gestes ne se
  /// valent pas : annuler jette ce qui vient d'être dit et se mérite, tandis
  /// que verrouiller ne fait que changer de main.
  static const cancelDistance = 96.0;
  static const lockDistance = 72.0;

  /// Taille d'un SMS mono-partie (alphabet GSM 7 bits).
  static const segmentLength = 160;

  /// Taille utile d'une partie quand le message est découpé (l'en-tête de
  /// concaténation ampute chaque segment).
  static const concatenatedSegmentLength = 153;

  /// Nombre de SMS que produira [body].
  static int segmentsFor(String body) {
    if (body.length <= segmentLength) return 1;
    return (body.length / concatenatedSegmentLength).ceil();
  }

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

/// Où en est l'appui maintenu.
///
/// [opening] existe parce que le micro ne s'ouvre pas dans le même battement
/// que l'appui : il y a une permission à demander, et un doigt peut se lever
/// pendant ce temps-là. Sans cet état intermédiaire, la barre apparaîtrait
/// sous un doigt déjà parti.
enum _Hold { none, opening, held }

class _MessageComposerState extends State<MessageComposer> {
  _Hold _hold = _Hold.none;

  /// De combien le doigt s'est éloigné de son point d'appui, borné aux deux
  /// distances qui mènent quelque part. C'est de la géométrie d'écran, pas de
  /// l'enregistrement : elle ne remonte jamais plus haut que ce champ.
  Offset _drag = Offset.zero;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  double get _cancelProgress =>
      (-_drag.dx / MessageComposer.cancelDistance).clamp(0.0, 1.0);

  double get _lockProgress =>
      (-_drag.dy / MessageComposer.lockDistance).clamp(0.0, 1.0);

  /// Le doigt s'installe : on ouvre le micro, puis seulement on peint.
  Future<void> _onHoldStart(LongPressStartDetails _) async {
    final open = widget.onVoiceHold;
    if (open == null || !widget.enabled) return;

    _hold = _Hold.opening;
    _drag = Offset.zero;
    final opened = await open();
    if (!mounted) return;

    if (!opened) {
      _hold = _Hold.none;
      return;
    }
    // Le doigt s'est levé pendant que le micro s'ouvrait : ce qui a été
    // enregistré tient dans un battement de cil, et le port le traitera comme
    // l'appui trop court qu'il est.
    if (_hold != _Hold.opening) {
      widget.onVoiceRelease?.call();
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _hold = _Hold.held);
  }

  void _onHoldMove(LongPressMoveUpdateDetails details) {
    if (_hold != _Hold.held) return;
    final offset = details.offsetFromOrigin;
    final up = -offset.dy;
    final left = -offset.dx;

    // Le geste dominant l'emporte : un glissé en diagonale doit décider, pas
    // hésiter entre les deux.
    if (up >= MessageComposer.lockDistance && up >= left) {
      _finishHold(widget.onVoiceLock);
      return;
    }
    if (left >= MessageComposer.cancelDistance) {
      _finishHold(widget.onVoiceCancel);
      return;
    }

    setState(() {
      _drag = Offset(
        offset.dx.clamp(-MessageComposer.cancelDistance, 0.0),
        offset.dy.clamp(-MessageComposer.lockDistance, 0.0),
      );
    });
  }

  void _onHoldEnd(LongPressEndDetails _) => _onHoldStopped();

  /// Le geste s'est terminé autrement qu'en levant le doigt — un appel qui
  /// prend l'écran, un autre pointeur. Ce qui a été dit ne se perd pas pour
  /// autant : c'est un relâchement comme un autre.
  void _onHoldCancelled() => _onHoldStopped();

  void _onHoldStopped() {
    // Le micro s'ouvre encore : c'est `_onHoldStart` qui conclura, lui seul
    // sait si le micro s'est finalement ouvert.
    if (_hold == _Hold.opening) {
      _hold = _Hold.none;
      return;
    }
    _finishHold(widget.onVoiceRelease);
  }

  /// Fin du geste, quelle qu'en soit l'issue : le champ redevient lui-même, et
  /// l'enregistrement apprend ce qu'il advient de lui.
  void _finishHold(VoidCallback? outcome) {
    if (_hold != _Hold.held) return;
    setState(() {
      _hold = _Hold.none;
      _drag = Offset.zero;
    });
    HapticFeedback.selectionClick();
    outcome?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = widget.controller.text;
    final canSend =
        widget.enabled && (text.trim().isNotEmpty || widget.hasAttachments);
    final segments = MessageComposer.segmentsFor(text);

    // Pas de `SafeArea` ici : le panneau d'enregistrement se pose *sous* le
    // champ, et deux zones sûres empilées ajouteraient deux fois l'encoche du
    // bas. C'est la page qui l'entoure, une seule fois, tout en bas.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            // Tant que le doigt tient le disque, la pilule cède sa place à la
            // barre d'enregistrement — même hauteur, mêmes coins, même fond :
            // c'est la même barre qui change de rôle, et rien ne saute.
            child: _hold == _Hold.held
                ? VoiceHoldBar(cancelProgress: _cancelProgress)
                : Container(
                    constraints: const BoxConstraints(
                      minHeight: MessageComposer.pillHeight,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    // Six de chaque côté : les deux boutons ronds ont leur
                    // propre marge interne, et le champ tombe entre eux.
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // La boîte du bouton fait la hauteur de la pilule : sur une
                        // ligne, « aligné en bas » revient alors à « centré », et
                        // quand le champ grandit le « + » reste en bas, contre la
                        // dernière ligne — c'est le comportement de l'app d'origine.
                        // Sans cela le bouton, haut de 48 px, pendait cinq pixels
                        // sous le centre.
                        SizedBox(
                          height: MessageComposer.pillHeight,
                          child: IconButton(
                            key: const Key('composerAttach'),
                            tooltip: 'Joindre',
                            icon: Icon(
                              widget.hasAttachments
                                  ? Icons.add_circle
                                  : Icons.add_circle_outline,
                              size: 26,
                            ),
                            color: colors.textPrimary,
                            onPressed: widget.onAttach,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                key: const Key('composerField'),
                                controller: widget.controller,
                                enabled: widget.enabled,
                                minLines: 1,
                                maxLines: 5,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                keyboardType: TextInputType.multiline,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 17,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  // Ajusté pour qu'une ligne unique donne très
                                  // exactement `pillHeight` : c'est ce qui fait
                                  // coïncider le centre du champ et celui du « + ».
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  // Avec une pièce jointe posée, le texte n'est
                                  // plus le message mais sa légende : l'app
                                  // d'origine change le libellé pour le dire.
                                  hintText: !widget.enabled
                                      ? 'Envoi indisponible'
                                      : widget.hasAttachments
                                      ? 'Ajouter du texte'
                                      : 'Message texte',
                                  hintStyle: TextStyle(
                                    color: colors.textMuted,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                              if (segments > 1)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '${segments * MessageComposer.concatenatedSegmentLength - text.length}/$segments',
                                    key: const Key('segmentCounter'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.textMuted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Au bout du champ, comme dans l'app d'origine : le
                        // « + » ouvre ce qu'on joint, celui-ci ouvre ce qu'on
                        // écrit.
                        SizedBox(
                          height: MessageComposer.pillHeight,
                          child: IconButton(
                            key: const Key('composerEmoji'),
                            tooltip: widget.emojiOpen
                                ? 'Masquer les emoji'
                                : 'Emoji et GIF',
                            icon: Icon(
                              widget.emojiOpen
                                  ? Icons.sentiment_satisfied
                                  : Icons.sentiment_satisfied_outlined,
                              size: 26,
                            ),
                            color: colors.textPrimary,
                            onPressed: widget.onEmoji,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          // Un seul disque, deux boutons : rien à envoyer, c'est le vocal ;
          // quelque chose à envoyer, c'est l'envoi.
          if (canSend)
            _SendButton(
              enabled: true,
              onPressed: () => widget.onSend(widget.controller.text),
            )
          else
            _voiceDisc(),
        ],
      ),
    );
  }

  /// Le disque vocal, et ce qui flotte au-dessus de lui pendant qu'on parle.
  ///
  /// La pastille du cadenas est **posée hors de la boîte** du disque, dans une
  /// pile qui ne rogne pas : elle se dessine par-dessus le fil, comme dans
  /// l'app d'origine, sans que le champ ait à se réserver la place d'une
  /// pastille qui n'existe qu'un geste sur deux.
  Widget _voiceDisc() {
    final held = _hold == _Hold.held;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (held)
          Positioned(
            bottom: MessageComposer.pillHeight + VoiceLockChip.gap,
            child: VoiceLockChip(progress: _lockProgress),
          ),
        // Le disque suit le doigt, la pastille non : l'une est ce qu'on
        // déplace, l'autre est ce qu'on vise.
        Transform.translate(
          offset: _drag,
          child: GestureDetector(
            onLongPressStart: _onHoldStart,
            onLongPressMoveUpdate: _onHoldMove,
            onLongPressEnd: _onHoldEnd,
            onLongPressCancel: _onHoldCancelled,
            child: _VoiceButton(
              onPressed: widget.enabled ? widget.onVoice : null,
              held: held,
            ),
          ),
        ),
      ],
    );
  }
}

/// Le disque du message vocal, à la place du bouton d'envoi tant qu'il n'y a
/// rien à envoyer.
///
/// La seule chose de l'app peinte dans la palette **tertiaire** : dans l'app
/// d'origine, ce bouton n'a la couleur d'aucun autre — vert sur un appareil
/// pêche, rose sur un appareil bleu. C'est ce qui le fait repérer du premier
/// coup d'œil au bout d'un champ de saisie.
/// Sous le doigt, il devient **rouge et plus gros** : les deux à la fois, parce
/// que ni l'un ni l'autre ne suffit. Le rouge seul se confondrait avec un
/// bouton d'alerte, et la taille seule ne dirait pas que quelque chose est en
/// train d'être enregistré.
///
/// Son glyphe, lui, ne grandit pas — relevé sur l'appareil, où l'icône fait la
/// même largeur dans les deux états. C'est le disque qui gonfle, pas le dessin.
class _VoiceButton extends StatelessWidget {
  const _VoiceButton({required this.onPressed, this.held = false});

  final VoidCallback? onPressed;
  final bool held;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final enabled = onPressed != null;
    final size = held
        ? MessageComposer.heldButtonSize
        : MessageComposer.pillHeight;

    return SizedBox(
      height: MessageComposer.pillHeight,
      width: MessageComposer.pillHeight,
      child: OverflowBox(
        maxHeight: MessageComposer.heldButtonSize,
        maxWidth: MessageComposer.heldButtonSize,
        child: Material(
          color: held
              ? colors.danger
              : enabled
              ? colors.voice
              : colors.surfaceAlt,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('recordVoice'),
            onTap: onPressed,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: size),
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              builder: (context, diameter, child) =>
                  SizedBox(height: diameter, width: diameter, child: child),
              child: Icon(
                Icons.graphic_eq,
                size: 24,
                color: held
                    ? colors.onAccent
                    : enabled
                    ? colors.onVoice
                    : colors.textMuted,
                semanticLabel: 'Enregistrer un message vocal',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Le disque à droite de la pilule. Plein et ambré dès qu'il y a quelque chose
/// à envoyer, effacé sinon.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: enabled ? colors.accent : colors.surfaceAlt,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('sendMessage'),
        onTap: enabled ? onPressed : null,
        child: SizedBox(
          height: MessageComposer.pillHeight,
          width: MessageComposer.pillHeight,
          child: Icon(
            Icons.send,
            size: 22,
            color: enabled ? colors.onAccent : colors.textMuted,
          ),
        ),
      ),
    );
  }
}
