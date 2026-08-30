import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/application/usecases/record_voice_message.usecase.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/model/voice_recording.dart';
import 'package:messages/infrastructure/attachments/in_memory.mms_configuration.service.dart';
import 'package:messages/infrastructure/audio/in_memory.audio_recorder.service.dart';
import 'package:messages/infrastructure/logger/in_memory.logger.service.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';

import '../helpers/test_logger.dart';

void main() {
  group('Longueur d\'un vocal', () {
    test('la limite vient de l\'opérateur, pas d\'une constante', () {
      // Un vocal ne s'allège pas : la seule façon de le faire tenir dans un
      // MMS est de le raccourcir. C'est donc le budget de l'opérateur, lu et
      // non deviné, qui dit combien de temps on peut parler.
      const avare = MmsLimits(maxTotalBytes: 64 * 1024);
      const genereux = MmsLimits(maxTotalBytes: 600 * 1024);

      expect(
        VoiceRecording.maxDurationIn(avare),
        lessThan(VoiceRecording.maxDurationIn(genereux)),
      );
    });

    test('le repli AOSP laisse plus de trois minutes', () {
      // 300 Ko d'AOSP, moins l'enveloppe, à 12,2 kbit/s.
      final duration = VoiceRecording.maxDurationIn(MmsLimits.fallback);
      expect(duration.inSeconds, greaterThan(180));
      expect(duration, lessThan(VoiceRecording.ceiling));
    });

    test('un opérateur généreux ne fait pas un vocal de dix minutes', () {
      // La borne haute est la nôtre : au-delà, ce n'est plus un message mais
      // un enregistrement, et personne ne l'écoutera.
      const enorme = MmsLimits(maxTotalBytes: 5 * 1024 * 1024);
      expect(VoiceRecording.maxDurationIn(enorme), VoiceRecording.ceiling);
    });
  });

  group('RecordVoiceMessageUseCase', () {
    late InMemorySmsStore store;
    late InMemoryAudioRecorderService recorder;
    late InMemoryMmsConfiguration carrier;
    late InMemoryLoggerService logs;
    late RecordVoiceMessageUseCase usecase;

    setUp(() {
      store = InMemorySmsStore();
      recorder = InMemoryAudioRecorderService(store);
      carrier = InMemoryMmsConfiguration();
      logs = InMemoryLoggerService();
      usecase = RecordVoiceMessageUseCase(
        recorder: recorder,
        configuration: carrier,
        logger: testLogger(logs),
      );
    });

    tearDown(() => recorder.dispose());

    /// Laisse tourner le micro simulé le temps demandé.
    Future<void> speak(Duration duration) async {
      final ticks =
          duration.inMilliseconds ~/
          InMemoryAudioRecorderService.tick.inMilliseconds;
      for (var i = 0; i < ticks; i++) {
        await Future<void>.delayed(InMemoryAudioRecorderService.tick);
      }
    }

    test('un vocal enregistré porte sa durée et son poids', () async {
      await usecase.start();
      await speak(const Duration(seconds: 1));
      final draft = await usecase.stop();

      expect(draft, isNotNull);
      expect(draft!.kind, AttachmentKind.audio);
      // La durée n'est pas remesurée : c'est nous qui tenions le micro.
      expect(draft.duration, isNotNull);
      expect(draft.duration!.inMilliseconds, greaterThanOrEqualTo(900));
      expect(draft.byteSize, greaterThan(0));
    });

    test('un appui malheureux ne produit pas de vocal muet', () async {
      // Micro ouvert puis refermé dans la foulée : il n'y a rien à envoyer, et
      // ce n'est pas une erreur.
      await usecase.start();
      final draft = await usecase.stop();

      expect(draft, isNull);
      final discarded = logs.records
          .where((r) => r.message == 'voice.record_discarded')
          .single;
      expect(discarded.attributes['voice.reason'], 'too_short');
    });

    test('le micro refusé se dit, et se journalise', () async {
      recorder.denyNext = true;

      await expectLater(
        usecase.start(),
        throwsA(isA<MicrophoneDeniedException>()),
      );
      final names = logs.records.map((r) => r.message);
      expect(names, contains('voice.record_refused'));
      // Rien n'a démarré : la ligne de départ ne doit pas être écrite.
      expect(names, isNot(contains('voice.record_started')));
    });

    test('le micro se referme tout seul au budget de l\'opérateur', () async {
      // Un opérateur qui n'accepterait qu'un vocal d'une seconde : à la
      // seconde, le micro s'arrête et ce qui a été dit reste joignable.
      carrier.value = const MmsLimits(
        maxTotalBytes: MmsLimits.envelopeBytes + VoiceRecording.bytesPerSecond,
      );

      await usecase.start();
      await speak(const Duration(milliseconds: 1600));

      final draft = await usecase.stop();
      expect(draft, isNotNull);
      expect(draft!.duration!.inMilliseconds, lessThan(1400));
      // Et il tient dans le budget, ce qui est tout l'objet de la manœuvre.
      expect(draft.byteSize, lessThanOrEqualTo(carrier.value.contentBytes));
    });

    test('« Recommencer » ne laisse rien derrière lui', () async {
      await usecase.start();
      await speak(const Duration(seconds: 1));
      final jete = await usecase.stop();
      await usecase.discard();

      // Le contenu du brouillon abandonné n'est plus servi à personne.
      expect(store.draftBytesOf(jete!.id), isNull);
      expect(store.soundDurationOf(jete.uri), isNull);
    });
  });
}
