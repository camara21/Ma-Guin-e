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

  @override
  void dispose() {
    _channel?.unsubscribe();
    _searchCtrl.dispose();
    super.dispose();
  }

  // -------------------- LOAD --------------------
  Future<void> _loadConversations() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    // Récupère tous les messages pertinents (via le service)
    final messages = await _messageService.fetchUserConversations(user.id);

    // Grouper par conversation (contexte + cible + autre participant)
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
          DateTime.parse(msg['date_envoi'])
              .isAfter(DateTime.parse(existing['date_envoi']))) {
        grouped[key] = msg;
      }
    }

    // Noms/prénoms des participants
    if (participantIds.isNotEmpty) {
      final users = await Supabase.instance.client
          .from('utilisateurs')
          .select('id, nom, prenom')
          .inFilter('id', participantIds.toList());
      _utilisateurs = {for (var u in users) u['id']: Map<String, dynamic>.from(u)};
    }

    setState(() {
      _conversations = grouped.values.toList()
        ..sort((a, b) =>
            DateTime.parse(b['date_envoi']).compareTo(DateTime.parse(a['date_envoi'])));
      _loading = false;
    });
  }

  // -------------------- REALTIME --------------------
  void _listenRealtime() {
    _channel = Supabase.instance.client
        .channel('messages_publication')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (_) {
            if (mounted) _loadConversations();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (_) {
            if (mounted) _loadConversations();
          },
        )
        .subscribe();
  }

  // -------------------- READ FLAG --------------------
  /// Marque tous les messages **reçus** de ce fil comme lus (dans Supabase),
  /// puis enlève immédiatement la pastille côté UI et notifie le badge global.
  Future<void> _markThreadAsRead({
    required Map<String, dynamic> convo,
    required String otherId,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final isAnnonce = convo['contexte'] == 'annonce';

      await Supabase.instance.client
          .from('messages')
          .update({'lu': true})
          .eq('contexte', convo['contexte'])
          .eq(
            isAnnonce ? 'annonce_id' : 'prestataire_id',
            isAnnonce ? convo['annonce_id'] : convo['prestataire_id'],
          )
          .eq('receiver_id', user.id) // seulement les messages que j'ai reçus
          .eq('sender_id', otherId)
          .eq('lu', false);

      // Optimiste: on enlève la pastille tout de suite dans la liste locale
      final idx = _conversations.indexOf(convo);
      if (idx != -1 && mounted) {
        setState(() {
          _conversations[idx] = {
            ..._conversations[idx],
            'lu': true,
          };
        });
      }

      // 🔔 Prévenir le MainNavigationPage pour mettre à jour le badge
      _messageService.unreadChanged.add(null);
    } catch (e) {
      debugPrint('markAsRead error: $e');
    }
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final filter = _searchCtrl.text.toLowerCase();

    final list = _conversations.where((m) {
      final contenu = (m['contenu'] ?? '').toString().toLowerCase();
      final otherId = (m['sender_id'] == user?.id) ? m['receiver_id'] : m['sender_id'];
      final u = _utilisateurs[otherId];
      final nom = ((u?['prenom'] ?? '') + ' ' + (u?['nom'] ?? '')).toLowerCase().trim();
      return contenu.contains(filter) || nom.contains(filter);
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
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final m = list[i];
                          final isAnnonce = m['contexte'] == 'annonce';
                          final isUnread =
                              m['lu'] == false && m['receiver_id'] == user?.id;

                          final otherId = (m['sender_id'] == user?.id)
                              ? m['receiver_id']
                              : m['sender_id'];

                          final utilisateur = _utilisateurs[otherId];
                          final title = (utilisateur != null)
                              ? "${utilisateur['prenom'] ?? ''} ${utilisateur['nom'] ?? ''}"
                                  .trim()
                              : (isAnnonce ? "Annonceur" : "Prestataire");

                          final subtitle = m['contenu']?.toString() ?? '';
                          final date =
                              m['date_envoi']?.toString().split('T').first ?? '';

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
                            trailing:
                                Text(date, style: const TextStyle(fontSize: 12)),
                            onTap: () async {
                              // 1) Marquer comme lu immédiatement (optimiste)
                              await _markThreadAsRead(convo: m, otherId: otherId);

                              // 2) Ouvrir la page de discussion
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

                              // 3) Au retour, recharge pour être 100% synchro
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
