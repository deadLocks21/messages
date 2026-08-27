import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/application/dtos/attachment.dto.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/model/audio_playback.dart';
import 'package:messages/infrastructure/audio/in_memory.audio_player.service.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';

import '../builders/builders.dart';

void main() {
  group('AudioPlayback', () {
    test('l\'avancement d\'une durée inconnue reste à zéro', () {
      const playback = AudioPlayback(
        attachmentId: 'part-1',
        position: Duration(seconds: 2),
      );
      // Sans durée, 2 secondes ne représentent aucune fraction : la tête de
      // lecture ne doit pas partir au hasard sur la piste.
      expect(playback.progress, 0);
    });

    test('l\'avancement ne dépasse pas la fin', () {
      const playback = AudioPlayback(
        attachmentId: 'part-1',
        position: Duration(seconds: 9),
        duration: Duration(seconds: 4),
      );
      expect(playback.progress, 1);
    });

    test('rien en cours ne se reconnaît dans aucune bulle', () {
      expect(AudioPlayback.idle.isFor('part-1'), isFalse);
    });
  });

  group('durée affichée', () {
    test('se lit en minutes et secondes', () {
      expect(AttachmentDto.formatDuration(const Duration(seconds: 4)), '00:04');
      expect(
        AttachmentDto.formatDuration(const Duration(minutes: 12, seconds: 7)),
        '12:07',
      );
    });

    test('une durée inconnue s\'affiche en tirets, pas en zéros', () {
      const attachment = AttachmentDto(
        id: 'part-1',
        mimeType: 'audio/amr',
        kind: AttachmentKind.audio,
        fileName: 'vocal.amr',
        byteSize: 2048,
      );
      expect(attachment.durationLabel, '--:--');
    });
  });

  group('InMemoryAudioPlayerService', () {
    late InMemorySmsStore store;
    late InMemoryAudioPlayerService player;

    setUp(() {
      store = InMemorySmsStore();
      player = InMemoryAudioPlayerService(store);
      final threadId = store.threadIdFor([Build.address('+33612345678')]);
      store.insert(
        Build.message(
          threadId: threadId,
          body: '',
          attachments: [
            Build.attachment(
              id: 'vocal-1',
              mimeType: 'audio/amr',
              durationMs: 4000,
            ),
            Build.attachment(
              id: 'vocal-2',
              mimeType: 'audio/amr',
              durationMs: 9000,
            ),
          ],
        ),
      );
    });

    tearDown(() => player.dispose());

    /// L'état courant, sans attendre d'avancée : le port le rend à toute
    /// nouvelle écoute.
    Future<AudioPlayback> current() => player.playback.first;

    test('la lecture annonce la durée du vocal demandé', () async {
      await player.play('vocal-1');

      final state = await current();
      expect(state.attachmentId, 'vocal-1');
      expect(state.duration, const Duration(seconds: 4));
      expect(state.isPlaying, isTrue);
      expect(state.position, Duration.zero);
    });

    test('la pause garde la position', () async {
      await player.play('vocal-1');
      await player.seek('vocal-1', const Duration(seconds: 2));
      await player.pause();

      final state = await current();
      expect(state.isPlaying, isFalse);
      expect(state.position, const Duration(seconds: 2));
      expect(state.attachmentId, 'vocal-1');
    });

    test('reprendre repart d\'où la pause a laissé', () async {
      await player.play('vocal-1');
      await player.seek('vocal-1', const Duration(seconds: 2));
      await player.pause();
      await player.play('vocal-1');

      expect((await current()).position, const Duration(seconds: 2));
    });

    test('un autre vocal arrête le premier et repart de zéro', () async {
      await player.play('vocal-1');
      await player.seek('vocal-1', const Duration(seconds: 2));
      await player.play('vocal-2');

      final state = await current();
      expect(state.attachmentId, 'vocal-2');
      expect(state.position, Duration.zero);
      expect(state.duration, const Duration(seconds: 9));
    });

    test('on ne se déplace pas au-delà de la fin', () async {
      await player.play('vocal-1');
      await player.seek('vocal-1', const Duration(seconds: 30));

      expect((await current()).position, const Duration(seconds: 4));
    });

    test('viser un vocal jamais lancé le choisit, sans le lancer', () async {
      await player.seek('vocal-2', const Duration(seconds: 3));

      final state = await current();
      expect(state.attachmentId, 'vocal-2');
      expect(state.position, const Duration(seconds: 3));
      expect(state.duration, const Duration(seconds: 9));
      expect(state.isPlaying, isFalse);
    });

    test('viser un autre vocal arrête celui qui jouait', () async {
      await player.play('vocal-1');
      await player.seek('vocal-2', const Duration(seconds: 3));

      final state = await current();
      expect(state.attachmentId, 'vocal-2');
      expect(state.isPlaying, isFalse);
    });

    test('se déplacer pendant la lecture ne l\'interrompt pas', () async {
      await player.play('vocal-1');
      await player.seek('vocal-1', const Duration(seconds: 1));

      expect((await current()).isPlaying, isTrue);
    });

    test('l\'arrêt oublie tout', () async {
      await player.play('vocal-1');
      await player.stop();

      expect(await current(), AudioPlayback.idle);
    });
  });
}
