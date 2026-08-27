import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/application/usecases/pick_attachments.usecase.dart';
import 'package:messages/core/application/usecases/send_message.usecase.dart';
import 'package:messages/core/application/usecases/start_conversation.usecase.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/model/log_level.dart';
import 'package:messages/core/domain/services/attachment_picker.service.dart';
import 'package:messages/infrastructure/attachments/in_memory.attachment_compressor.service.dart';
import 'package:messages/infrastructure/attachments/in_memory.attachment_picker.service.dart';
import 'package:messages/infrastructure/attachments/in_memory.mms_configuration.service.dart';
import 'package:messages/infrastructure/logger/in_memory.logger.service.dart';
import 'package:messages/infrastructure/preferences/in_memory.draft.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.conversation.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.message.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';

/// Ce que l'app raconte d'elle-même.
///
/// Un log n'a ni écran ni utilisateur pour signaler sa disparition : supprimer
/// une ligne de journalisation ne casse rien de visible, et l'oubli ne se
/// découvre que le jour où l'on cherche la trace qui manque. Ces tests tiennent
/// donc les quelques enregistrements sur lesquels on compte vraiment pour
/// comprendre un envoi qui échoue.
void main() {
  late InMemorySmsStore store;
  late InMemoryLoggerService sink;
  late LoggerApplicationService logger;

  setUp(() {
    store = InMemorySmsStore();
    sink = InMemoryLoggerService();
    logger = LoggerApplicationService(sink);
  });

  tearDown(() => store.dispose());

  LoggedRecord recordNamed(String message) =>
      sink.records.firstWhere((r) => r.message == message);

  group('envoi', () {
    late SendMessageUseCase usecase;

    setUp(() {
      usecase = SendMessageUseCase(
        messages: InMemoryMessageRepository(store),
        drafts: InMemoryDraftRepository(),
        configuration: InMemoryMmsConfiguration(),
        logger: logger,
      );
    });

    test('un SMS parti se dit, sans dire ce qu\'il contient', () async {
      await usecase.execute(recipients: ['+33612345678'], body: 'Coucou');

      final record = recordNamed('message.send');
      expect(record.level, LogLevel.info);
      expect(record.attributes['message.transport'], 'sms');
      expect(record.attributes['recipients.count'], 1);
      expect(record.attributes['body.length'], 6);
      // Le texte et le numéro n'ont rien à faire dans un journal de
      // production : c'est leur longueur et leur nombre qui sont utiles.
      final serialised = record.attributes.values.join(' ');
      expect(serialised, isNot(contains('Coucou')));
      expect(serialised, isNot(contains('612345678')));
    });

    test('un refus du domaine ressort en erreur, avec l\'exception', () async {
      await expectLater(
        usecase.execute(recipients: ['+33612345678'], body: '   '),
        throwsA(isA<MessageSendFailedException>()),
      );

      final record = recordNamed('message.send_failed');
      expect(record.level, LogLevel.error);
      expect(record.error, isA<MessageSendFailedException>());
      expect(record.attributes['recipients.count'], 1);
    });

    test('une pièce jointe fait basculer le transport annoncé', () async {
      final draft = AttachmentDraft(
        id: 'a1',
        uri: 'content://photo',
        mimeType: 'image/jpeg',
        fileName: 'photo.jpg',
        byteSize: 1024,
      );

      await usecase.execute(
        recipients: ['+33612345678'],
        body: '',
        attachments: [draft],
      );

      final record = recordNamed('message.send');
      expect(record.attributes['message.transport'], 'mms');
      expect(record.attributes['attachments.bytes'], 1024);
      expect(record.attributes['attachment.mime'], 'image/jpeg');
    });
  });

  test('une pièce jointe refusée dit pourquoi', () async {
    final usecase = PickAttachmentsUseCase(
      picker: InMemoryAttachmentPicker(store),
      compressor: InMemoryAttachmentCompressor(store),
      configuration: InMemoryMmsConfiguration(),
      logger: logger,
    );
    final limits = await InMemoryMmsConfiguration().limits();

    // Une vidéo ne s'allège pas : au-delà du budget, elle est refusée net.
    final video = AttachmentDraft(
      id: 'v1',
      uri: 'content://video',
      mimeType: 'video/mp4',
      fileName: 'film.mp4',
      byteSize: limits.contentBytes * 2,
    );

    await expectLater(
      usecase.fitToBudget([video]),
      throwsA(isA<AttachmentTooLargeException>()),
    );

    final record = recordNamed('attachment.rejected');
    expect(record.level, LogLevel.warn);
    expect(record.attributes['attachment.reason'], 'incompressible');
    expect(record.attributes['attachment.mime'], 'video/mp4');
  });

  test('une sélection annulée ne journalise rien', () async {
    final picker = InMemoryAttachmentPicker(store, cancelNext: true);
    final usecase = PickAttachmentsUseCase(
      picker: picker,
      compressor: InMemoryAttachmentCompressor(store),
      configuration: InMemoryMmsConfiguration(),
      logger: logger,
    );

    await usecase.execute(AttachmentSource.gallery);

    // Un non-événement ne fait pas de bruit — sinon le journal se remplit de
    // gestes annulés et les vraies lignes deviennent illisibles.
    expect(sink.records, isEmpty);
  });

  test('un fil qu\'on n\'arrive pas à ouvrir laisse une trace', () async {
    final usecase = StartConversationUseCase(
      InMemoryConversationRepository(store),
      logger: logger,
    );

    await expectLater(
      usecase.execute(const ['  ']),
      throwsA(isA<MessageSendFailedException>()),
    );

    final record = recordNamed('conversation.start_failed');
    expect(record.level, LogLevel.warn);
    expect(record.attributes['reason'], 'no_valid_recipient');
  });

  test('le contexte dynamique se pose sur chaque ligne', () async {
    var route = '/';
    final contextual = LoggerApplicationService(
      sink,
      resolveContext: () => {'app.route': route},
    );

    await contextual.info('app.started');
    route = '/thread/:id';
    await contextual.warn('message.send_blocked');

    // Le résolveur est rappelé à *chaque* émission : c'est ce qui permet à
    // l'instance de survivre aux changements d'écran tout en portant l'écran
    // courant.
    expect(sink.records.first.attributes['app.route'], '/');
    expect(sink.records.last.attributes['app.route'], '/thread/:id');
  });

  test('un résolveur qui lève ne fait pas tomber le log', () async {
    final contextual = LoggerApplicationService(
      sink,
      resolveContext: () => throw StateError('identité indisponible'),
    );

    await contextual.error('dart.uncaught');

    expect(sink.records.single.message, 'dart.uncaught');
    expect(sink.records.single.attributes, isEmpty);
  });
}
