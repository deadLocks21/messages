import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/infrastructure/sms/android.conversation.repository.dart';
import 'package:messages/infrastructure/sms/android_sms.channel.dart';

/// Un fil ouvert depuis le sélecteur doit rester un fil dans lequel on peut
/// écrire, même quand le stock système ne sait pas relire ses destinataires.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('fr.dtfh.messages/sms');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mock({required List<String> storeRecipients}) {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      switch (call.method) {
        case 'resolveThreadId':
          return '42';
        case 'recipientsOf':
          return storeRecipients;
        case 'deleteThread':
          return null;
      }
      return null;
    });
  }

  tearDown(() => messenger.setMockMethodCallHandler(methodChannel, null));

  AndroidConversationRepository repository() => AndroidConversationRepository(
    const AndroidSmsChannel(channel: methodChannel),
  );

  test('garde les destinataires résolus quand le stock ne les relit pas',
      () async {
    mock(storeRecipients: const []);
    final repo = repository();

    final threadId = await repo.resolveThreadId([Address.parse('0612345678')]);
    final recipients = await repo.recipientsOf(threadId);

    expect(recipients.map((a) => a.raw), ['0612345678']);
  });

  test('préfère ce que dit le stock quand il répond', () async {
    mock(storeRecipients: const ['+33612345678']);
    final repo = repository();

    await repo.resolveThreadId([Address.parse('0612345678')]);

    expect((await repo.recipientsOf('42')).map((a) => a.raw), [
      '+33612345678',
    ]);
  });

  test('oublie un fil supprimé', () async {
    mock(storeRecipients: const []);
    final repo = repository();

    await repo.resolveThreadId([Address.parse('0612345678')]);
    await repo.delete('42');

    expect(await repo.recipientsOf('42'), isEmpty);
  });

  test('ne fabrique rien pour un fil inconnu', () async {
    mock(storeRecipients: const []);
    expect(await repository().recipientsOf('7'), isEmpty);
  });
}
