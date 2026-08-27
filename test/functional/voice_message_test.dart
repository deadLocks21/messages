import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/ui/pages/conversation/conversation.page.dart';
import 'package:messages/ui/pages/conversation/widgets/audio_attachment.widget.dart';

import '../builders/builders.dart';
import '../helpers/test_app.dart';

void main() {
  /// Un fil où Camille a laissé un vocal de 4 secondes, et un second de 9.
  (TestDevice, String) deviceWithVoiceMessages() {
    final device = TestDevice(
      contacts: [
        Build.contact(displayName: 'Camille', addresses: ['0612345678']),
      ],
    );
    final threadId = device.store.threadIdFor([Build.address('+33612345678')]);
    device.store.insert(
      Build.message(
        id: 'vocal-court',
        threadId: threadId,
        body: '',
        attachments: [
          Build.attachment(
            id: 'part-voice-1',
            mimeType: 'audio/amr',
            durationMs: 4000,
          ),
        ],
      ),
    );
    device.store.insert(
      Build.message(
        id: 'vocal-long',
        threadId: threadId,
        body: '',
        attachments: [
          Build.attachment(
            id: 'part-voice-2',
            mimeType: 'audio/amr',
            durationMs: 9000,
          ),
        ],
      ),
    );
    return (device, threadId);
  }

  Finder playButton(String id) => find.byKey(Key('playAttachment_$id'));

  Finder iconIn(String id, IconData icon) => find.descendant(
    of: playButton(id),
    matching: find.byIcon(icon),
  );

  testWidgets('un vocal s\'affiche en lecteur, pas en ligne de fichier', (
    tester,
  ) async {
    final (device, threadId) = deviceWithVoiceMessages();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);

    expect(find.byType(AudioAttachment), findsNWidgets(2));
    // La durée annoncée est là avant toute lecture : c'est elle qui décide
    // d'écouter ou non.
    expect(find.text('00:04'), findsOneWidget);
    expect(find.text('00:09'), findsOneWidget);
    // Ni nom de fichier, ni poids : un vocal ne s'annonce pas comme un PDF.
    expect(find.text('vocal.amr'), findsNothing);
  });

  testWidgets('le bouton bascule en pause et le temps avance', (tester) async {
    final (device, threadId) = deviceWithVoiceMessages();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await tester.tap(playButton('part-voice-1'));
    await tester.pump();

    expect(iconIn('part-voice-1', Icons.pause), findsOneWidget);

    // Surtout pas `pumpAndSettle` : tant qu'un vocal joue, le lecteur publie
    // une position toutes les 100 ms et le fil se repeint sans fin.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:01'), findsOneWidget);

    await tester.tap(playButton('part-voice-1'));
    await tester.pump();
    expect(iconIn('part-voice-1', Icons.play_arrow), findsOneWidget);

    // En pause, le temps écoulé reste affiché : on sait où on avait laissé.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:01'), findsOneWidget);
  });

  testWidgets('le bouton est rond au repos et carré arrondi en lecture', (
    tester,
  ) async {
    // La forme dit l'état autant que l'icône : deux glyphes de 24 px se
    // ressemblent de loin, un disque et un carré arrondi non. C'est la forme
    // *visée* qu'on lit ici — Material se charge de passer de l'une à l'autre.
    final (device, threadId) = deviceWithVoiceMessages();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);

    ShapeBorder? shapeOf(String id) => tester
        .widget<Material>(
          find.descendant(of: playButton(id), matching: find.byType(Material)).first,
        )
        .shape;

    expect(shapeOf('part-voice-1'), isA<CircleBorder>());

    await tester.tap(playButton('part-voice-1'));
    await tester.pump();

    expect(iconIn('part-voice-1', Icons.pause), findsOneWidget);
    expect(shapeOf('part-voice-1'), isA<RoundedRectangleBorder>());

    // La pause la ramène au rond.
    await tester.tap(playButton('part-voice-1'));
    await tester.pump();

    expect(iconIn('part-voice-1', Icons.play_arrow), findsOneWidget);
    expect(shapeOf('part-voice-1'), isA<CircleBorder>());
  });

  testWidgets('lancer un vocal arrête celui qui jouait', (tester) async {
    final (device, threadId) = deviceWithVoiceMessages();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await tester.tap(playButton('part-voice-1'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(playButton('part-voice-2'));
    await tester.pump();

    expect(iconIn('part-voice-2', Icons.pause), findsOneWidget);
    expect(iconIn('part-voice-1', Icons.play_arrow), findsOneWidget);
    // Le premier a tout oublié : il réannonce sa durée, pas sa position.
    expect(find.text('00:04'), findsOneWidget);

    await tester.tap(playButton('part-voice-2'));
    await tester.pump();
  });

  testWidgets('au bout, la bulle est prête à rejouer', (tester) async {
    final (device, threadId) = deviceWithVoiceMessages();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await tester.tap(playButton('part-voice-1'));
    await tester.pump(const Duration(seconds: 5));

    expect(iconIn('part-voice-1', Icons.play_arrow), findsOneWidget);
    // Et non « 00:04 » figé sur la fin : la bulle réannonce la durée.
    expect(find.text('00:04'), findsOneWidget);
    expect(find.text('00:09'), findsOneWidget);
  });

  testWidgets('toucher la piste d\'un vocal jamais lancé le positionne', (
    tester,
  ) async {
    // Le cas qui compte : viser un point sans avoir rien lancé. Demander la
    // position « de la lecture en cours » ne menait nulle part — il n'y en a
    // pas encore.
    final (device, threadId) = deviceWithVoiceMessages();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);

    // Un appui au milieu de la piste du vocal de 4 secondes : la tête se pose
    // autour de 2 secondes, et rien ne démarre.
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('audioTrack_part-voice-1'))),
    );
    await tester.pump();

    expect(find.text('00:02'), findsOneWidget);
    expect(iconIn('part-voice-1', Icons.play_arrow), findsOneWidget);

    // Et la lecture repart de là, pas du début.
    await tester.tap(playButton('part-voice-1'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('00:02'), findsOneWidget);

    await tester.tap(playButton('part-voice-1'));
    await tester.pump();
  });
}
