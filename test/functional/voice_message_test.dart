import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/ui/pages/conversation/conversation.page.dart';
import 'package:messages/ui/pages/conversation/widgets/audio_attachment.widget.dart';
import 'package:messages/ui/pages/conversation/widgets/message_composer.widget.dart';
import 'package:messages/ui/pages/conversation/widgets/voice_recorder.widget.dart';

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

  Finder iconIn(String id, IconData icon) =>
      find.descendant(of: playButton(id), matching: find.byIcon(icon));

  testWidgets('un vocal s\'affiche en lecteur, pas en ligne de fichier', (
    tester,
  ) async {
    final (device, threadId) = deviceWithVoiceMessages();

    await pumpPage(
      tester,
      ConversationPage(threadId: threadId),
      device: device,
    );

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

    await pumpPage(
      tester,
      ConversationPage(threadId: threadId),
      device: device,
    );
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

    await pumpPage(
      tester,
      ConversationPage(threadId: threadId),
      device: device,
    );

    ShapeBorder? shapeOf(String id) => tester
        .widget<Material>(
          find
              .descendant(of: playButton(id), matching: find.byType(Material))
              .first,
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

  testWidgets('la piste dessine le relief du son, pas une ligne', (
    tester,
  ) async {
    final (device, threadId) = deviceWithVoiceMessages();

    await pumpPage(
      tester,
      ConversationPage(threadId: threadId),
      device: device,
    );

    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byKey(const Key('audioTrack_part-voice-1')),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter
            as AudioTrackPainter;

    // La bulle a demandé la mesure et l'a transmise : c'est ce chaînage-là qui
    // casserait sans qu'on le voie, la piste retombant sur ses pointillés.
    expect(painter.waveform.isEmpty, isFalse);
    expect(painter.waveform.levels, everyElement(inInclusiveRange(0, 1)));
    // Un relief, pas un plateau.
    expect(painter.waveform.levels.toSet(), hasLength(greaterThan(1)));
  });

  testWidgets('lancer un vocal arrête celui qui jouait', (tester) async {
    final (device, threadId) = deviceWithVoiceMessages();

    await pumpPage(
      tester,
      ConversationPage(threadId: threadId),
      device: device,
    );
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

    await pumpPage(
      tester,
      ConversationPage(threadId: threadId),
      device: device,
    );
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

    await pumpPage(
      tester,
      ConversationPage(threadId: threadId),
      device: device,
    );

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

  group('Enregistrer un vocal', () {
    /// Un fil vide, prêt à recevoir un vocal.
    (TestDevice, String) deviceWithThread() {
      final device = TestDevice(
        contacts: [
          Build.contact(displayName: 'Camille', addresses: ['0612345678']),
        ],
      );
      final threadId = device.store.threadIdFor([
        Build.address('+33612345678'),
      ]);
      device.store.insert(
        Build.message(threadId: threadId, body: 'Tu es là ?'),
      );
      return (device, threadId);
    }

    /// Ouvre le panneau et enregistre [duration].
    ///
    /// Jamais `pumpAndSettle` pendant l'enregistrement : le micro publie un
    /// niveau toutes les 100 ms, et le panneau se repeindrait sans fin.
    Future<void> record(
      WidgetTester tester, {
      Duration duration = const Duration(seconds: 2),
    }) async {
      await tester.tap(find.byKey(const Key('recordVoice')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('voiceRecord')));
      await tester.pump();
      await tester.pump();
      await tester.pump(duration);
    }

    testWidgets(
      'le panneau s\'ouvre sur le geste à faire, sans rien enregistrer',
      (tester) async {
        final (device, threadId) = deviceWithThread();
        await pumpPage(
          tester,
          ConversationPage(threadId: threadId),
          device: device,
        );

        expect(find.byKey(const Key('voiceRecorderPanel')), findsNothing);

        await tester.tap(find.byKey(const Key('recordVoice')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('voiceInvitation')), findsOneWidget);
        // Rien n'est encore enregistré : « Joindre » ne joindrait rien.
        expect(
          tester
              .widget<InkWell>(
                find.descendant(
                  of: find.byKey(const Key('voiceAttach')),
                  matching: find.byType(InkWell),
                ),
              )
              .onTap,
          isNull,
        );
        // Le micro n'a pas été ouvert : la permission se demandera au geste
        // suivant, là où l'utilisateur comprend pourquoi.
        expect(find.byKey(const Key('voiceElapsed')), findsNothing);
      },
    );

    testWidgets('le compteur avance et la piste se remplit', (tester) async {
      final (device, threadId) = deviceWithThread();
      await pumpPage(
        tester,
        ConversationPage(threadId: threadId),
        device: device,
      );

      await record(tester, duration: const Duration(seconds: 2));

      expect(find.text('00:02'), findsOneWidget);

      final painter =
          tester
                  .widget<CustomPaint>(find.byKey(const Key('voiceLevels')))
                  .painter
              as VoiceLevelsPainter;
      // Ce qui se dessine est ce que le micro a relevé, pas une animation :
      // c'est ce chaînage-là qui casserait sans qu'on le voie.
      expect(painter.waveform.isEmpty, isFalse);
      expect(painter.waveform.levels, everyElement(inInclusiveRange(0, 1)));

      // Annoncée parce que l'appareil la sert : sur un appareil qui ne la sert
      // pas, la pastille disparaît sans que la piste bouge.
      expect(find.textContaining('Suppression du bruit'), findsOneWidget);
    });

    testWidgets('l\'arrêt donne un vocal à réécouter, pas encore joint', (
      tester,
    ) async {
      final (device, threadId) = deviceWithThread();
      await pumpPage(
        tester,
        ConversationPage(threadId: threadId),
        device: device,
      );

      await record(tester, duration: const Duration(seconds: 2));
      await tester.tap(find.byKey(const Key('voiceStop')));
      await tester.pump();
      await tester.pump();

      // Le même lecteur que dans une bulle : un vocal s'écoute d'une seule
      // façon, avant comme après l'envoi.
      expect(find.byKey(const Key('voicePreview')), findsOneWidget);
      // Et le plateau est toujours vide : « Joindre » n'a pas encore été
      // touché.
      expect(find.byKey(const Key('attachmentTray')), findsNothing);
    });

    testWidgets('« Recommencer » repart de rien, panneau ouvert', (
      tester,
    ) async {
      final (device, threadId) = deviceWithThread();
      await pumpPage(
        tester,
        ConversationPage(threadId: threadId),
        device: device,
      );

      await record(tester, duration: const Duration(seconds: 2));
      await tester.tap(find.byKey(const Key('voiceStop')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('voiceLeftAction')));
      await tester.pumpAndSettle();

      // Le panneau reste, l'enregistrement non.
      expect(find.byKey(const Key('voiceRecorderPanel')), findsOneWidget);
      expect(find.byKey(const Key('voiceInvitation')), findsOneWidget);
      expect(find.byKey(const Key('voicePreview')), findsNothing);
    });

    testWidgets('« Annuler » referme le panneau', (tester) async {
      final (device, threadId) = deviceWithThread();
      await pumpPage(
        tester,
        ConversationPage(threadId: threadId),
        device: device,
      );

      await tester.tap(find.byKey(const Key('recordVoice')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('voiceLeftAction')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('voiceRecorderPanel')), findsNothing);
      expect(find.byKey(const Key('recordVoice')), findsOneWidget);
    });

    testWidgets('joindre puis envoyer dépose un MMS sonore dans le fil', (
      tester,
    ) async {
      final (device, threadId) = deviceWithThread();
      await pumpPage(
        tester,
        ConversationPage(threadId: threadId),
        device: device,
      );

      await record(tester, duration: const Duration(seconds: 2));
      await tester.tap(find.byKey(const Key('voiceStop')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('voiceAttach')));
      await tester.pumpAndSettle();

      // Le panneau s'efface, le vocal passe sur le plateau — en lecteur, pas
      // en vignette.
      expect(find.byKey(const Key('voiceRecorderPanel')), findsNothing);
      expect(find.byKey(const Key('attachmentTray')), findsOneWidget);
      // Le champ n'attend plus un message mais une légende, et le disque
      // devient celui de l'envoi.
      expect(find.text('Ajouter du texte'), findsOneWidget);
      expect(find.byKey(const Key('sendMessage')), findsOneWidget);

      await tester.tap(find.byKey(const Key('sendMessage')));
      await tester.pumpAndSettle();

      final sent = device.store
          .messagesFor(threadId)
          .where((m) => m.isOutgoing)
          .single;
      final attachment = sent.attachments.single;
      expect(attachment.kind, AttachmentKind.audio);
      // La durée est portée jusque dans la bulle : elle a été mesurée au
      // micro, pas au décodeur.
      expect(attachment.duration, isNotNull);
      expect(find.byKey(const Key('attachmentTray')), findsNothing);
    });

    testWidgets('« Joindre » pendant qu\'on parle arrête et joint', (
      tester,
    ) async {
      // L'app d'origine n'exige pas d'appuyer sur « stop » d'abord : le geste
      // qui dit « c'est bon » suffit.
      final (device, threadId) = deviceWithThread();
      await pumpPage(
        tester,
        ConversationPage(threadId: threadId),
        device: device,
      );

      await record(tester, duration: const Duration(seconds: 2));
      await tester.tap(find.byKey(const Key('voiceAttach')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('voiceRecorderPanel')), findsNothing);
      expect(find.byKey(const Key('attachmentTray')), findsOneWidget);
      expect(find.text('Ajouter du texte'), findsOneWidget);
    });

    testWidgets('un micro refusé se dit, il ne se tait pas', (tester) async {
      final (device, threadId) = deviceWithThread();
      device.voice.denyNext = true;

      await pumpPage(
        tester,
        ConversationPage(threadId: threadId),
        device: device,
      );

      await tester.tap(find.byKey(const Key('recordVoice')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('voiceRecord')));
      await tester.pumpAndSettle();

      expect(find.text('L\'accès au micro a été refusé.'), findsOneWidget);
      // Le panneau reste ouvert : le refus n'est pas définitif, et réessayer
      // ne doit pas coûter un aller-retour de plus.
      expect(find.byKey(const Key('voiceRecorderPanel')), findsOneWidget);
    });
  });

  group('Maintenir le disque pour enregistrer', () {
    /// Un fil vide, prêt à recevoir un vocal.
    (TestDevice, String) deviceWithThread() {
      final device = TestDevice(
        contacts: [
          Build.contact(displayName: 'Camille', addresses: ['0612345678']),
        ],
      );
      final threadId = device.store.threadIdFor([
        Build.address('+33612345678'),
      ]);
      device.store.insert(
        Build.message(threadId: threadId, body: 'Tu es là ?'),
      );
      return (device, threadId);
    }

    /// Maintient le disque, puis parle [duration]. Le doigt reste posé : c'est
    /// à l'appelant de dire comment le geste se termine — relâché, glissé vers
    /// la corbeille ou vers le cadenas.
    ///
    /// Jamais `pumpAndSettle` : le micro publie un niveau toutes les 100 ms, et
    /// la barre se repeindrait sans fin.
    Future<TestGesture> hold(
      WidgetTester tester, {
      Duration duration = const Duration(seconds: 2),
    }) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('recordVoice'))),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      // Le micro s'ouvre en plusieurs allers-retours — la limite de
      // l'opérateur, puis le démarrage — avant que la barre ait quelque chose
      // à peindre.
      await tester.pump();
      await tester.pump();
      await tester.pump(duration);
      return gesture;
    }

    testWidgets('le champ devient la barre, et le disque rougit', (
      tester,
    ) async {
      final (device, threadId) = deviceWithThread();
      await pumpPage(
        tester,
        ConversationPage(threadId: threadId),
        device: device,
      );

      final gesture = await hold(tester);

      // La pilule a cédé la place, sans que le panneau s'en mêle : un micro,
      // une surface.
      expect(find.byKey(const Key('voiceHoldBar')), findsOneWidget);
      expect(find.byKey(const Key('voiceRecorderPanel')), findsNothing);
      expect(find.text('Message texte'), findsNothing);
      // Le compteur avance sous le doigt, et le cadenas annonce qu'on peut le
      // lever sans tout perdre.
      expect(find.text('00:02'), findsOneWidget);
      expect(find.byKey(const Key('voiceLockChip')), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('relâcher joint le vocal, il ne l\'envoie pas', (tester) async {
      // C'est là toute la différence avec un bouton d'envoi : l'app d'origine
      // pose le vocal sur le plateau et laisse ajouter une légende.
      final (device, threadId) = deviceWithThread();
      await pumpPage(
        tester,
        ConversationPage(threadId: threadId),
        device: device,
      );

      final gesture = await hold(tester);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('voiceHoldBar')), findsNothing);
      expect(find.byKey(const Key('attachmentTray')), findsOneWidget);
      expect(find.text('Ajouter du texte'), findsOneWidget);
      // Rien n'est parti : le fil ne porte que le message reçu.
      expect(
        device.store.messagesFor(threadId).where((m) => m.isOutgoing),
        isEmpty,
      );

      await tester.tap(find.byKey(const Key('sendMessage')));
      await tester.pumpAndSettle();

      final sent = device.store
          .messagesFor(threadId)
          .where((m) => m.isOutgoing)
          .single;
      expect(sent.attachments.single.kind, AttachmentKind.audio);
    });

    testWidgets('glisser jusqu\'à la corbeille ne laisse rien', (tester) async {
      final (device, threadId) = deviceWithThread();
      await pumpPage(
        tester,
        ConversationPage(threadId: threadId),
        device: device,
      );

      final gesture = await hold(tester);
      await gesture.moveBy(
        const Offset(-MessageComposer.cancelDistance - 1, 0),
      );
      await tester.pump();

      // Annulé sous le doigt, sans attendre qu'il se lève : « faire glisser
      // pour annuler » annule quand on a glissé.
      expect(find.byKey(const Key('voiceHoldBar')), findsNothing);
      expect(find.byKey(const Key('attachmentTray')), findsNothing);
      expect(find.text('Message texte'), findsOneWidget);

      // Et le doigt qui se lève ensuite ne ressuscite rien.
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('attachmentTray')), findsNothing);
    });

    testWidgets('glisser jusqu\'au cadenas passe la main au panneau', (
      tester,
    ) async {
      // Le doigt s'en va, l'enregistrement continue : c'est le panneau qui
      // porte alors « stop », « Recommencer » et « Joindre ».
      final (device, threadId) = deviceWithThread();
      await pumpPage(
        tester,
        ConversationPage(threadId: threadId),
        device: device,
      );

      final gesture = await hold(tester);
      await gesture.moveBy(const Offset(0, -MessageComposer.lockDistance - 1));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(find.byKey(const Key('voiceHoldBar')), findsNothing);
      expect(find.byKey(const Key('voiceRecorderPanel')), findsOneWidget);
      // Le micro n'a rien vu passer : le compteur repart de là où le doigt
      // l'avait laissé, il ne recommence pas.
      expect(find.byKey(const Key('voiceStop')), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:03'), findsOneWidget);

      await tester.tap(find.byKey(const Key('voiceAttach')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('attachmentTray')), findsOneWidget);
    });

    testWidgets('un appui bref ouvre toujours le panneau', (tester) async {
      // Les deux gestes vivent sur le même disque : celui qu'on n'a pas voulu
      // ne doit pas manger l'autre.
      final (device, threadId) = deviceWithThread();
      await pumpPage(
        tester,
        ConversationPage(threadId: threadId),
        device: device,
      );

      await tester.tap(find.byKey(const Key('recordVoice')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('voiceRecorderPanel')), findsOneWidget);
      expect(find.byKey(const Key('voiceHoldBar')), findsNothing);
      // Et le micro n'a pas été ouvert au passage.
      expect(find.byKey(const Key('voiceInvitation')), findsOneWidget);
    });

    testWidgets('relâché aussitôt, il ne reste rien à joindre', (tester) async {
      // Un appui malheureux ne doit pas produire une pièce jointe muette.
      final (device, threadId) = deviceWithThread();
      await pumpPage(
        tester,
        ConversationPage(threadId: threadId),
        device: device,
      );

      final gesture = await hold(
        tester,
        duration: const Duration(milliseconds: 200),
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('voiceHoldBar')), findsNothing);
      expect(find.byKey(const Key('attachmentTray')), findsNothing);
      expect(find.byKey(const Key('voiceRecorderPanel')), findsNothing);
      expect(find.text('Message texte'), findsOneWidget);
    });

    testWidgets('le panneau ouvert garde la main sur le micro', (tester) async {
      // Les deux surfaces montrent le même enregistrement : les afficher
      // ensemble, c'est afficher deux fois le même micro — et le second
      // compteur resterait à zéro.
      final (device, threadId) = deviceWithThread();
      await pumpPage(
        tester,
        ConversationPage(threadId: threadId),
        device: device,
      );

      await tester.tap(find.byKey(const Key('recordVoice')));
      await tester.pumpAndSettle();

      final gesture = await hold(tester);

      expect(find.byKey(const Key('voiceHoldBar')), findsNothing);
      expect(find.byKey(const Key('voiceRecorderPanel')), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('micro refusé, aucune barre ne se peint', (tester) async {
      // Peindre la barre avant de savoir promettrait un enregistrement qui n'a
      // pas commencé — et le compteur resterait à zéro sans que rien le dise.
      final (device, threadId) = deviceWithThread();
      device.voice.denyNext = true;

      await pumpPage(
        tester,
        ConversationPage(threadId: threadId),
        device: device,
      );

      final gesture = await hold(tester);

      expect(find.byKey(const Key('voiceHoldBar')), findsNothing);
      expect(find.text('L\'accès au micro a été refusé.'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
