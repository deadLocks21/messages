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

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          widget.forwardedBody == null ? 'Nouvelle conversation' : 'Transférer à',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              key: const Key('recipientField'),
              controller: _query,
              autofocus: true,
              keyboardType: TextInputType.text,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'À : nom ou numéro',
                prefixIcon: Icon(Icons.person_add_alt),
              ),
            ),
          ),
          if (widget.forwardedBody != null)
            _ForwardPreview(body: widget.forwardedBody!),
          Expanded(
            child: suggestionsAsync.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Erreur : $error')),
              data: (contacts) => contacts.isEmpty
                  ? _NoContacts(hasQuery: _query.text.trim().isNotEmpty)
                  : ListView.builder(
                      itemCount: contacts.length,
                      itemBuilder: (context, index) => ContactTile(
                        contact: contacts[index],
                        onTap: () => _pick(contacts[index]),
                      ),
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

class _ForwardPreview extends StatelessWidget {
  const _ForwardPreview({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
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
              style: TextStyle(color: colors.textMuted, fontSize: 13),
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
