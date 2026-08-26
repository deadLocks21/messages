import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:messages/core/application/dtos/contact.dto.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/infrastructure/providers/service_providers.dart';
import 'package:messages/ui/pages/new_conversation/widgets/contact_tile.widget.dart';
import 'package:messages/ui/providers/conversation_providers.dart';
import 'package:messages/ui/router/app_router.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Sélecteur de destinataire : on tape un nom ou un numéro, on choisit, le fil
/// s'ouvre.
///
/// Sert aussi de destination au transfert d'un message : [forwardedBody] est
/// alors déposé comme brouillon du fil choisi, qui l'affiche à l'ouverture.
class NewConversationPage extends ConsumerStatefulWidget {
  const NewConversationPage({super.key, this.forwardedBody});

  final String? forwardedBody;

  @override
  ConsumerState<NewConversationPage> createState() =>
      _NewConversationPageState();
}

class _NewConversationPageState extends ConsumerState<NewConversationPage> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final suggestionsAsync = ref.watch(contactSuggestionsProvider(_query.text));
    final searching = _query.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        toolbarHeight: 64,
        title: Text(
          widget.forwardedBody == null ? 'Nouveau chat' : 'Transférer à',
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 4),
          _RecipientField(
            controller: _query,
            onChanged: (_) => setState(() {}),
          ),
          if (widget.forwardedBody != null)
            _ForwardPreview(body: widget.forwardedBody!),
          Expanded(
            child: suggestionsAsync.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Erreur : $error')),
              data: (contacts) => contacts.isEmpty
                  ? _NoContacts(hasQuery: searching)
                  : _ContactList(
                      contacts: contacts,
                      // Les intertitres alphabétiques n'ont de sens que sur le
                      // carnet entier : une recherche rend déjà une liste
                      // courte, l'app d'origine les masque alors.
                      grouped: !searching,
                      onPick: _pick,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(ContactDto contact) async {
    if (contact.addresses.isEmpty) return;
    try {
      final threadId = await ref
          .read(startConversationUseCaseProvider)
          .execute([contact.addresses.first]);

      // Le message transféré arrive dans le fil comme un brouillon : rien n'est
      // envoyé tant que l'utilisateur n'a pas confirmé.
      final forwarded = widget.forwardedBody;
      if (forwarded != null) {
        await ref.read(saveDraftUseCaseProvider).execute(threadId, forwarded);
      }
      if (!mounted) return;
      ref.invalidate(draftProvider(threadId));
      context.pushReplacement(AppRoutes.thread(threadId));
    } on SmsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// Le champ « À : » de l'app d'origine — une pilule pleine, le libellé collé
/// devant la saisie.
class _RecipientField extends StatelessWidget {
  const _RecipientField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Text(
              'À :',
              style: TextStyle(color: colors.textPrimary, fontSize: 17),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                key: const Key('recipientField'),
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.text,
                onChanged: onChanged,
                style: TextStyle(color: colors.textPrimary, fontSize: 17),
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Saisissez un nom ou un numéro',
                  hintStyle: TextStyle(color: colors.textMuted, fontSize: 17),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le carnet, éventuellement coupé par des intertitres alphabétiques.
class _ContactList extends StatelessWidget {
  const _ContactList({
    required this.contacts,
    required this.grouped,
    required this.onPick,
  });

  final List<ContactDto> contacts;
  final bool grouped;
  final ValueChanged<ContactDto> onPick;

  /// Les accents ne créent pas de section à part : « Émile » se range sous E,
  /// comme dans le carnet Android.
  static const _accents = {
    'À': 'A', 'Á': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A', 'Å': 'A',
    'Ç': 'C',
    'È': 'E', 'É': 'E', 'Ê': 'E', 'Ë': 'E',
    'Ì': 'I', 'Í': 'I', 'Î': 'I', 'Ï': 'I',
    'Ñ': 'N',
    'Ò': 'O', 'Ó': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
    'Ù': 'U', 'Ú': 'U', 'Û': 'U', 'Ü': 'U',
    'Ý': 'Y', 'Ÿ': 'Y',
  };

  static String _fold(String value) => value
      .toUpperCase()
      .split('')
      .map((c) => _accents[c] ?? c)
      .join();

  /// Lettre de classement d'un contact. Tout ce qui ne commence pas par une
  /// lettre — les numéros courts, les expéditeurs numériques — tombe sous
  /// « # », en fin de liste comme dans le carnet Android.
  static String _sectionOf(ContactDto contact) {
    final name = _fold(contact.displayName.trim());
    if (name.isEmpty) return '#';
    final letter = name[0];
    return RegExp(r'[A-Z]').hasMatch(letter) ? letter : '#';
  }

  /// Ordre alphabétique, « # » relégué en fin de liste : sans ça les
  /// intertitres se répéteraient au fil du carnet.
  static int _byName(ContactDto a, ContactDto b) {
    final sectionA = _sectionOf(a);
    final sectionB = _sectionOf(b);
    if (sectionA != sectionB) {
      if (sectionA == '#') return 1;
      if (sectionB == '#') return -1;
    }
    return _fold(a.displayName).compareTo(_fold(b.displayName));
  }

  @override
  Widget build(BuildContext context) {
    if (!grouped) {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: contacts.length,
        itemBuilder: (context, index) => ContactTile(
          contact: contacts[index],
          onTap: () => onPick(contacts[index]),
        ),
      );
    }

    // Une liste plate d'entrées déjà résolues : la section n'est écrite que
    // lorsqu'elle change, ce qui évite de reconstruire des sous-listes.
    final sorted = [...contacts]..sort(_byName);
    final rows = <Widget>[];
    String? section;
    for (final contact in sorted) {
      final current = _sectionOf(contact);
      if (current != section) {
        section = current;
        rows.add(_SectionHeader(current, key: Key('contactSection_$current')));
      }
      rows.add(ContactTile(contact: contact, onTap: () => onPick(contact)));
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: rows,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.letter, {super.key});

  final String letter;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 24, 8),
      child: Text(
        letter,
        style: TextStyle(color: colors.textPrimary, fontSize: 15),
      ),
    );
  }
}

class _ForwardPreview extends StatelessWidget {
  const _ForwardPreview({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.forward_outlined, size: 18, color: colors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textMuted, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoContacts extends StatelessWidget {
  const _NoContacts({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          hasQuery
              ? 'Aucun contact ne correspond.'
              : 'Aucun contact. Saisissez un numéro pour démarrer une '
                    'conversation.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textMuted),
        ),
      ),
    );
  }
}
