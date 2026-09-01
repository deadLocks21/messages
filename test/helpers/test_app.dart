import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:messages/core/domain/model/contact.dart';
import 'package:messages/core/domain/model/sms_access.dart';
import 'package:messages/infrastructure/attachments/in_memory.attachment_opener.service.dart';
import 'package:messages/infrastructure/attachments/in_memory.attachment_picker.service.dart';
import 'package:messages/infrastructure/attachments/in_memory.media_downloader.service.dart';
import 'package:messages/infrastructure/attachments/in_memory.mms_configuration.service.dart';
import 'package:messages/infrastructure/gif/in_memory.gif_catalog.service.dart';
import 'package:messages/infrastructure/preferences/in_memory.emoji_history.repository.dart';
import 'package:messages/infrastructure/audio/in_memory.audio_recorder.service.dart';
import 'package:messages/infrastructure/contacts/in_memory.contact.repository.dart';
import 'package:messages/infrastructure/notifications/in_memory.notification.gateway.dart';
import 'package:messages/infrastructure/permissions/in_memory.sms_permissions.service.dart';
import 'package:messages/infrastructure/preferences/in_memory.conversation_preferences.repository.dart';
import 'package:messages/infrastructure/preferences/in_memory.draft.repository.dart';
import 'package:messages/infrastructure/preferences/in_memory.reaction_preferences.repository.dart';
import 'package:messages/infrastructure/preferences/in_memory.theme.repository.dart';
import 'package:messages/infrastructure/providers/infra_providers.dart';
import 'package:messages/infrastructure/providers/repository_providers.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';
import 'package:messages/ui/router/app_router.dart';
import 'package:messages/ui/theme/app_theme_data.dart';

/// Le « téléphone » des tests : un stock SMS, un carnet d'adresses et des
/// réglages, tous en mémoire.
///
/// Sans lui, `useNativeSmsStack` verrait `TargetPlatform.android` (valeur par
/// défaut de `flutter_test`) et tenterait d'appeler un canal natif inexistant.
class TestDevice {
  final InMemorySmsStore store;
  final InMemoryContactRepository contacts;
  final InMemoryDraftRepository drafts;
  final InMemoryConversationPreferencesRepository preferences;
  final InMemorySmsPermissionsService permissions;
  final InMemoryThemeRepository theme;
  final InMemoryNotificationGateway notifications;

  /// Sélecteur de pièces jointes : c'est par lui qu'un test fait « choisir une
  /// photo » ou « refermer le sélecteur sans rien prendre ».
  ///
  /// Il dépose ce qu'il fabrique dans le stock de *ce* device — d'où
  /// l'initialisation dans le corps, une fois [store] construit.
  late final InMemoryAttachmentPicker attachments = InMemoryAttachmentPicker(
    store,
  );

  /// Ce à quoi l'app confie ce qu'elle ne sait pas montrer — un PDF, une
  /// vidéo. Les tests y lisent ce qui a été passé, et peuvent simuler un
  /// appareil qui n'a rien pour l'ouvrir.
  final InMemoryAttachmentOpener opener = InMemoryAttachmentOpener();

  /// Le micro : c'est par lui qu'un test enregistre un vocal, ou simule un
  /// micro refusé.
  late final InMemoryAudioRecorderService voice = InMemoryAudioRecorderService(
    store,
  );

  /// La configuration de l'opérateur. Modifiable pour rejouer le cas d'un
  /// opérateur avare — c'est elle qui décide de la longueur d'un vocal, et de
  /// la finesse d'un GIF.
  final InMemoryMmsConfiguration carrier = InMemoryMmsConfiguration();

  /// Le catalogue de GIF : c'est par lui qu'un test lit ce qui a été cherché,
  /// ou rend le catalogue muet.
  final InMemoryGifCatalog gifs = InMemoryGifCatalog();

  /// Les emoji récemment utilisés. Modifiable pour ouvrir le panneau sur une
  /// section des récents déjà remplie.
  final InMemoryEmojiHistoryRepository emojiHistory =
      InMemoryEmojiHistoryRepository();

  /// Le repli des réactions, actif comme sur un téléphone neuf.
  final InMemoryReactionPreferencesRepository reactionPreferences =
      InMemoryReactionPreferencesRepository();

  /// Le rapatriement d'un GIF choisi. Il dépose ses octets dans le stock de
  /// *ce* device — d'où l'initialisation dans le corps.
  late final InMemoryMediaDownloader downloads = InMemoryMediaDownloader(store);

  TestDevice({
    List<Contact> contacts = const [],
    SmsAccess access = SmsAccess.full,

    /// Ce qu'accordera la prochaine demande de permissions. Permet de simuler
    /// un refus, y compris définitif.
    SmsAccess? grantedOnRequest,
  }) : store = InMemorySmsStore(),
       contacts = InMemoryContactRepository(contacts),
       drafts = InMemoryDraftRepository(),
       preferences = InMemoryConversationPreferencesRepository(),
       permissions = InMemorySmsPermissionsService(
         initial: access,
         grantedOnRequest: grantedOnRequest,
       ),
       theme = InMemoryThemeRepository(),
       notifications = InMemoryNotificationGateway();
}

/// Monte [home] dans un `MaterialApp` thémé, sur le device fourni.
///
/// Pour les écrans qui ne naviguent pas — c'est le cas de la plupart, les
/// actions de navigation étant testées par `messaging_flow_test`.
Future<void> pumpPage(
  WidgetTester tester,
  Widget home, {
  required TestDevice device,
}) => _pump(
  tester,
  device,
  MaterialApp(theme: AppThemeData.buildLightTheme(), home: home),
);

/// Monte l'application complète, routeur compris, pour les parcours qui vont
/// d'un écran à l'autre.
Future<void> pumpApp(WidgetTester tester, {required TestDevice device}) => _pump(
  tester,
  device,
  Consumer(
    builder: (context, ref, _) => MaterialApp.router(
      theme: AppThemeData.buildLightTheme(),
      routerConfig: ref.watch(goRouterProvider),
    ),
  ),
);

/// Le `ProviderScope` est écrit ici, à l'intérieur même de `pumpWidget` : sorti
/// dans une fonction qui le retournerait, `riverpod_lint` le prendrait pour un
/// scope imbriqué et réclamerait des `dependencies`.
Future<void> _pump(WidgetTester tester, TestDevice device, Widget child) async {
  // Ce que fait `main()` avant `runApp` : libellés de date en français, et pas
  // de téléchargement de police (l'appel réseau échouerait en test).
  GoogleFonts.config.allowRuntimeFetching = false;
  await initializeDateFormatting('fr_FR');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        useNativeSmsStackProvider.overrideWithValue(false),
        inMemorySmsStoreProvider.overrideWithValue(device.store),
        inMemoryContactsProvider.overrideWithValue(device.contacts),
        draftRepositoryProvider.overrideWithValue(device.drafts),
        conversationPreferencesRepositoryProvider.overrideWithValue(
          device.preferences,
        ),
        themeRepositoryProvider.overrideWithValue(device.theme),
        smsPermissionsServiceProvider.overrideWithValue(device.permissions),
        notificationGatewayProvider.overrideWithValue(device.notifications),
        inMemoryAttachmentPickerProvider.overrideWithValue(device.attachments),
        inMemoryAttachmentOpenerProvider.overrideWithValue(device.opener),
        inMemoryAudioRecorderProvider.overrideWithValue(device.voice),
        mmsConfigurationProvider.overrideWithValue(device.carrier),
        inMemoryGifCatalogProvider.overrideWithValue(device.gifs),
        emojiHistoryRepositoryProvider.overrideWithValue(device.emojiHistory),
        reactionPreferencesRepositoryProvider.overrideWithValue(
          device.reactionPreferences,
        ),
        inMemoryMediaDownloaderProvider.overrideWithValue(device.downloads),
      ],
      child: child,
    ),
  );
  await tester.pumpAndSettle();
}
