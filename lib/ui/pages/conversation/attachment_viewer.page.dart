import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messages/core/application/dtos/attachment.dto.dart';
import 'package:messages/core/application/dtos/message.dto.dart';
import 'package:messages/ui/providers/attachment_providers.dart';
import 'package:messages/ui/utils/date_format.dart';

/// Une image de MMS en grand, par-dessus le fil.
///
/// La vignette d'une bulle n'est qu'un aperçu : recadrée à la largeur de la
/// bulle, et décodée à cette taille-là. L'ouvrir rend l'image entière — cadrée
/// pour tenir à l'écran, décodée à sa définition réelle, sur fond noir pour que
/// rien ne dispute l'attention à la photo.
///
/// Ce n'est pas une route du `GoRouter` : un aperçu ne se partage pas par une
/// URL et ne survit pas au fil qui l'a ouvert. C'est une route locale du
/// `Navigator`, comme les feuilles d'actions.
class AttachmentViewerPage extends ConsumerStatefulWidget {
  const AttachmentViewerPage({
    super.key,
    required this.attachment,
    required this.message,
  });

  final AttachmentDto attachment;

  /// Le message qui la portait : de qui, et quand — la seule chose que la
  /// photo elle-même ne dit pas.
  final MessageDto message;

  /// Étiquette du vol entre la vignette et le plein écran. Définie ici pour
  /// que les deux extrémités ne puissent pas diverger.
  static String heroTagFor(String attachmentId) => 'viewer_$attachmentId';

  static Future<void> open(
    BuildContext context, {
    required AttachmentDto attachment,
    required MessageDto message,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) =>
            AttachmentViewerPage(attachment: attachment, message: message),
        // Un fondu, pas un glissement : c'est la vignette qui porte le
        // mouvement, le reste ne fait que s'éteindre derrière elle.
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  ConsumerState<AttachmentViewerPage> createState() =>
      _AttachmentViewerPageState();
}

class _AttachmentViewerPageState extends ConsumerState<AttachmentViewerPage>
    with SingleTickerProviderStateMixin {
  final TransformationController _transform = TransformationController();

  late final AnimationController _zoom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _zoomFlight;

  /// Le double-appui grossit ce qu'on a montré du doigt, pas le centre de
  /// l'écran : sur une photo de groupe, c'est un visage qu'on vise.
  Offset _doubleTapAt = Offset.zero;

  /// La barre du haut s'efface au premier appui — une photo se regarde sans
  /// rien autour — et revient au suivant.
  bool _chromeVisible = true;

  static const _doubleTapScale = 2.5;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(() {
      final flight = _zoomFlight;
      if (flight != null) _transform.value = flight.value;
    });
  }

  @override
  void dispose() {
    _zoom.dispose();
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bytes = ref.watch(attachmentBytesProvider(widget.attachment.id));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Fond noir : les icônes du système doivent passer en clair, sinon elles
      // disparaissent le temps de l'aperçu.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        key: const Key('attachmentViewer'),
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _chromeVisible = !_chromeVisible),
              onDoubleTapDown: (details) =>
                  _doubleTapAt = details.localPosition,
              onDoubleTap: _toggleZoom,
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: 1,
                maxScale: 5,
                child: Center(child: _content(bytes)),
              ),
            ),
            Positioned(top: 0, left: 0, right: 0, child: _topBar(context)),
          ],
        ),
      ),
    );
  }

  Widget _content(AsyncValue<Uint8List?> bytes) {
    final data = bytes.value;
    if (data == null) {
      return bytes.isLoading
          ? const CircularProgressIndicator(color: Colors.white70)
          : const _Unavailable();
    }
    return Hero(
      tag: AttachmentViewerPage.heroTagFor(widget.attachment.id),
      child: Image.memory(
        data,
        key: Key('viewerImage_${widget.attachment.id}'),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        // Pas de `cacheWidth` ici, à l'inverse de la vignette : le détail est
        // précisément ce qu'on est venu chercher. Le coût reste borné — une
        // partie de MMS a passé le plafond de l'opérateur avant d'arriver.
        errorBuilder: (_, _, _) => const _Unavailable(),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final message = widget.message;
    // Le nom n'est connu que là où il apporte quelque chose : « Vous » sur un
    // envoi, l'expéditeur dans un fil de groupe. Ailleurs, la date suffit —
    // l'interlocuteur est déjà en titre du fil, juste derrière.
    final who = message.isOutgoing ? 'Vous' : message.senderName;
    final when = MessagesDateFormat.full(message.sentAt);

    return AnimatedOpacity(
      opacity: _chromeVisible ? 1 : 0,
      duration: const Duration(milliseconds: 160),
      child: IgnorePointer(
        ignoring: !_chromeVisible,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            // Un dégradé plutôt qu'une barre pleine : sur une photo claire, le
            // blanc du titre a besoin d'un fond ; sur une photo sombre, une
            // barre opaque couperait l'image en deux.
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 16),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('closeAttachmentViewer'),
                    tooltip: 'Fermer',
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          who ?? when,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (who != null)
                          Text(
                            when,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Va-et-vient entre l'image entière et un agrandissement centré sur le
  /// point touché — le geste qu'on fait sans y penser sur une photo.
  void _toggleZoom() {
    final zoomedIn = _transform.value.getMaxScaleOnAxis() > 1.01;
    // Garder fixe le point touché : `échelle × p + t = p`, donc
    // `t = -p × (échelle - 1)`.
    final target = zoomedIn
        ? Matrix4.identity()
        : (Matrix4.diagonal3Values(_doubleTapScale, _doubleTapScale, 1)
            ..setTranslationRaw(
              -_doubleTapAt.dx * (_doubleTapScale - 1),
              -_doubleTapAt.dy * (_doubleTapScale - 1),
              0,
            ));

    _zoomFlight = Matrix4Tween(begin: _transform.value, end: target).animate(
      CurvedAnimation(parent: _zoom, curve: Curves.easeOutCubic),
    );
    _zoom.forward(from: 0);
  }
}

/// Ce qu'on montre quand les octets manquent ou ne se décodent pas : une image
/// de MMS peut avoir été effacée du stock, ou n'avoir jamais été téléchargée.
class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
        SizedBox(height: 12),
        Text(
          'Image indisponible',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}
