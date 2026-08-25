import 'package:flutter/material.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Champ de rédaction : pièce jointe, texte, envoi.
///
/// Le bouton d'envoi n'apparaît qu'une fois quelque chose tapé, et le compteur
/// de segments SMS ne s'affiche qu'au-delà d'un message — comme Google
/// Messages, qui ne montre `n/2` que quand le découpage devient réel.
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.enabled,
    this.onAttach,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final bool enabled;
  final VoidCallback? onAttach;

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
    final canSend = widget.enabled && text.trim().isNotEmpty;
    final segments = MessageComposer.segmentsFor(text);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              key: const Key('composerAttach'),
              tooltip: 'Joindre',
              icon: const Icon(Icons.add),
              color: colors.textMuted,
              onPressed: widget.onAttach,
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                      style: TextStyle(color: colors.textPrimary, fontSize: 16),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        hintText: widget.enabled
                            ? 'Message texte'
                            : 'Envoi indisponible',
                        hintStyle: TextStyle(color: colors.textMuted),
                      ),
                    ),
                    if (segments > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${segments * MessageComposer.concatenatedSegmentLength - text.length}/$segments',
                          key: const Key('segmentCounter'),
                          style: TextStyle(fontSize: 11, color: colors.textMuted),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            _SendButton(
              enabled: canSend,
              onPressed: () => widget.onSend(widget.controller.text),
            ),
          ],
        ),
      ),
    );
  }
}

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
          height: 48,
          width: 48,
          child: Icon(
            Icons.send,
            size: 20,
            color: enabled ? colors.onAccent : colors.textMuted,
          ),
        ),
      ),
    );
  }
}
