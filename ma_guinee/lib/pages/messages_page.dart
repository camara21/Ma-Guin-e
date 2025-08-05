import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/message_service.dart';
import 'messages_annonce_page.dart';
import 'messages_prestataire_page.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final _searchCtrl = TextEditingController();
  final MessageService _messageService = MessageService();
  List<Map<String, dynamic>> _conversations = [];
  Map<String, Map<String, dynamic>> _utilisateurs = {}; // id -> {nom, prenom}
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _listenRealtime();
  }

  Future<void> _loadConversations() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    final messages = await _messageService.fetchUserConversations(user.id);

    final Map<String, Map<String, dynamic>> grouped = {};
    final Set<String> participantIds = {};
    for (final msg in messages) {
      final otherId = (msg['sender_id'] == user.id) ? msg['receiver_id'] : msg['sender_id'];
      final key = [
        msg['contexte'],
        msg['annonce_id'] ?? msg['prestataire_id'],
        otherId,
      ].join('-');
      participantIds.add(otherId);

      final existing = grouped[key];
      if (existing == null ||
          DateTime.parse(msg['date_envoi']).isAfter(DateTime.parse(existing['date_envoi']))) {
        grouped[key] = msg;
      }
    }

    if (participantIds.isNotEmpty) {
      final users = await Supabase.instance.client
          .from('utilisateurs')
          .select('id, nom, prenom')
          .inFilter('id', participantIds.toList());

      _utilisateurs = { for (var u in users) u['id']: u };
    }

    setState(() {
      _conversations = grouped.values.toList();
      _loading = false;
    });
  }

  void _listenRealtime() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _channel = Supabase.instance.client
        .channel('messages_publication')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            if (mounted) _loadConversations();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            if (mounted) _loadConversations();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final filter = _searchCtrl.text.toLowerCase();

    final list = _conversations.where((m) {
      final contenu = (m['contenu'] ?? '').toString().toLowerCase();
      return contenu.contains(filter);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages", style: TextStyle(color: Color(0xFF113CFC))),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF113CFC)),
        elevation: 1,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Rechercher…',
                prefixIcon: Icon(Icons.search, color: Color(0xFF113CFC)),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? const Center(child: Text("Aucune conversation."))
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (ctx, i) {
                          final m = list[i];
                          final isAnnonce = m['contexte'] == 'annonce';
                          final isUnread = m['lu'] == false &&
                              m['receiver_id'] == user?.id;

                          final otherId = (m['sender_id'] == user?.id)
                              ? m['receiver_id']
                              : m['sender_id'];

                          final utilisateur = _utilisateurs[otherId];
                          final title = utilisateur != null
                              ? "${utilisateur['prenom'] ?? ''} ${utilisateur['nom'] ?? ''}".trim()
                              : (isAnnonce ? "Annonceur" : "Prestataire");

                          final subtitle = m['contenu'] ?? '';
                          final date = m['date_envoi']?.toString().split('T').first ?? '';

                          return ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isAnnonce
                                      ? const Color(0xFF113CFC)
                                      : const Color(0xFFCE1126),
                                  child: Icon(
                                    isAnnonce ? Icons.campaign : Icons.engineering,
                                    color: Colors.white,
                                  ),
                                ),
                                if (isUnread)
                                  const Positioned(
                                    right: 0,
                                    top: 0,
                                    child: CircleAvatar(
                                      radius: 6,
                                      backgroundColor: Colors.red,
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(title),
                            subtitle: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(date, style: const TextStyle(fontSize: 12)),
                            onTap: () async {
                              if (isAnnonce) {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MessagesAnnoncePage(
                                      annonceId: m['annonce_id'],
                                      annonceTitre: title,
                                      receiverId: otherId,
                                      senderId: user!.id,
                                    ),
                                  ),
                                );
                              } else {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MessagesPrestatairePage(
                                      prestataireId: m['prestataire_id'],
                                      prestataireNom: title,
                                      receiverId: otherId,
                                      senderId: user!.id,
                                    ),
                                  ),
                                );
                              }
                              _loadConversations();
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
