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
import 'package:messages/ui/widgets/avatar.widget.dart';

/// Sélecteur de destinataire : on tape un nom ou un numéro, on choisit, le fil
/// s'ouvre.
///
/// Sert aussi de destination au transfert d'un message : [forwardedBody] est
/// alors déposé comme brouillon du fil choisi, qui l'affiche à l'ouverture.
///
/// Et de « Ajouter des personnes », quand [seedRecipients] est fourni : le même
/// écran, mais choisir n'ouvre plus un fil — ça pose une puce de plus dans le
/// champ, jusqu'à ce qu'on valide. C'est ce que fait l'app d'origine, dont
/// « Créer un groupe » rouvre le sélecteur avec l'interlocuteur courant déjà
/// dedans.
class NewConversationPage extends ConsumerStatefulWidget {
  const NewConversationPage({
    super.key,
    this.forwardedBody,
    this.seedRecipients,
  });

  final String? forwardedBody;

  /// Adresses déjà dans le fil. Non nul ⇒ mode groupe.
  final List<String>? seedRecipients;

  @override
  ConsumerState<NewConversationPage> createState() =>
      _NewConversationPageState();
}

class _NewConversationPageState extends ConsumerState<NewConversationPage> {
  final TextEditingController _query = TextEditingController();

  /// Les destinataires retenus, en mode groupe. Des fiches et non des
  /// adresses : la puce porte un nom, et c'est le nom qu'on relit.
  final List<ContactDto> _picked = [];

  bool get _group => widget.seedRecipients != null;

  @override
  void initState() {
    super.initState();
    final seed = widget.seedRecipients;
    if (seed != null) _resolveSeed(seed);
  }

  /// Les adresses du fil arrivent brutes : c'est le carnet qui leur rend un
  /// nom, et il se lit de façon asynchrone.
  Future<void> _resolveSeed(List<String> addresses) async {
    final picker = ref.read(contactPickerServiceProvider);
    final resolved = <ContactDto>[];
    for (final address in addresses) {
      resolved.add(await picker.forAddress(address));
    }
    if (!mounted) return;
    setState(() => _picked.addAll(resolved));
  }

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
        title: Text(switch ((_group, widget.forwardedBody)) {
          (true, _) => 'Ajouter des personnes',
          (_, null) => 'Nouveau chat',
          _ => 'Transférer à',
        }),
      ),
      // Le bouton de validation n'existe qu'en mode groupe : ailleurs, choisir
      // *est* valider.
      floatingActionButton: _group && _picked.isNotEmpty
          ? FloatingActionButton(
              key: const Key('confirmRecipients'),
              tooltip: 'Démarrer la discussion',
              onPressed: _start,
              child: const Icon(Icons.check),
            )
          : null,
      body: Column(
        children: [
          const SizedBox(height: 4),
          _RecipientField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            picked: _picked,
            onRemove: (contact) => setState(() => _picked.remove(contact)),
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

  /// En mode groupe, choisir pose ou retire une puce ; ailleurs, ça ouvre le
  /// fil sans détour.
  void _pick(ContactDto contact) {
    if (contact.addresses.isEmpty) return;
    if (!_group) {
      _open([contact.addresses.first]);
      return;
    }
    setState(() {
      final existing = _picked.indexWhere((c) => c.id == contact.id);
      if (existing >= 0) {
        _picked.removeAt(existing);
      } else {
        _picked.add(contact);
      }
      // La saisie a servi : la garder filtrerait encore la liste alors que le
      // choix est fait.
      _query.clear();
    });
  }

  void _start() => _open([
    for (final contact in _picked)
      if (contact.addresses.isNotEmpty) contact.addresses.first,
  ]);

  Future<void> _open(List<String> addresses) async {
    if (addresses.isEmpty) return;
    try {
      final threadId = await ref
          .read(startConversationUseCaseProvider)
          .execute(addresses);

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
/// devant la saisie, et les destinataires déjà retenus en puces devant elle.
class _RecipientField extends StatelessWidget {
  const _RecipientField({
    required this.controller,
    required this.onChanged,
    this.picked = const [],
    this.onRemove,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// Destinataires déjà retenus, en mode groupe.
  final List<ContactDto> picked;
  final ValueChanged<ContactDto>? onRemove;

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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        // `Wrap` et non `Row` : à cinq destinataires les puces passent à la
        // ligne, et le champ grandit avec elles.
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(
              'À :',
              style: TextStyle(color: colors.textPrimary, fontSize: 17),
            ),
            const SizedBox(width: 8),
            for (final contact in picked)
              _RecipientChip(
                contact: contact,
                onRemove: onRemove == null ? null : () => onRemove!(contact),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 160),
              child: IntrinsicWidth(
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
                    hintText: picked.isEmpty
                        ? 'Saisissez un nom ou un numéro'
                        : 'Quelqu\'un d\'autre ?',
                    hintStyle: TextStyle(color: colors.textMuted, fontSize: 17),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un destinataire retenu : sa pastille, son nom, et de quoi le retirer.
class _RecipientChip extends StatelessWidget {
  const _RecipientChip({required this.contact, this.onRemove});

  final ContactDto contact;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      key: Key('recipientChip_${contact.id}'),
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Avatar(avatar: contact.avatar, size: 28),
          const SizedBox(width: 8),
          Text(
            contact.displayName,
            style: TextStyle(color: colors.onAccentSoft, fontSize: 15),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            InkResponse(
              onTap: onRemove,
              radius: 16,
              child: Icon(Icons.close, size: 18, color: colors.onAccentSoft),
            ),
          ],
        ],
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
        // Posé à même le fond, comme le champ au-dessus : `surface`, sinon le
        // bloc se confondrait avec lui.
        color: colors.surface,
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
