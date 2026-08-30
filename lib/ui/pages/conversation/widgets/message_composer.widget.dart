import 'package:flutter/material.dart';
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
/// Le compteur de segments SMS ne s'affiche qu'au-delà d'un message — comme
/// l'app d'origine, qui ne montre `n/2` que quand le découpage devient réel.
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.enabled,
    this.onAttach,
    this.onVoice,
    this.hasAttachments = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final bool enabled;
  final VoidCallback? onAttach;

  /// Ouvre le panneau d'enregistrement. Null quand l'app ne sait pas
  /// enregistrer.
  final VoidCallback? onVoice;

  /// Le plateau au-dessus porte-t-il quelque chose ? Une photo seule est un
  /// message valide : le bouton d'envoi doit s'allumer même le champ vide.
  final bool hasAttachments;

  /// Hauteur de la pilule quand le champ tient sur une ligne. C'est aussi la
  /// hauteur de la boîte du bouton « + » et du disque d'envoi : les trois se
  /// mesurent l'un sur l'autre, sinon ils dérivent.
  static const pillHeight = 56.0;

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

class _MessageComposerState extends State<MessageComposer> {
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
            child: Container(
              constraints: const BoxConstraints(
                minHeight: MessageComposer.pillHeight,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.only(left: 6, right: 18),
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
                          textCapitalization: TextCapitalization.sentences,
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
            _VoiceButton(onPressed: widget.enabled ? widget.onVoice : null),
        ],
      ),
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
class _VoiceButton extends StatelessWidget {
  const _VoiceButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final enabled = onPressed != null;

    return Material(
      color: enabled ? colors.voice : colors.surfaceAlt,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('recordVoice'),
        onTap: onPressed,
        child: SizedBox(
          height: MessageComposer.pillHeight,
          width: MessageComposer.pillHeight,
          child: Icon(
            Icons.graphic_eq,
            size: 24,
            color: enabled ? colors.onVoice : colors.textMuted,
            semanticLabel: 'Enregistrer un message vocal',
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
