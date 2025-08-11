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

  // --- helpers ---
  DateTime _asDate(dynamic v) {
    if (v is DateTime) return v;
    if (v is String) {
      final d = DateTime.tryParse(v);
      if (d != null) return d;
    }
    // fallback très ancien si null / invalide
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _dateLabel(dynamic v) {
    final d = _asDate(v);
    // format yyyy-mm-dd simple
    return d.toIso8601String().split('T').first;
  }

  // -------------------- LOAD --------------------
  Future<void> _loadConversations() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    // 1) Récupérer tous les messages où je suis sender/receiver
    final messages = await _messageService.fetchUserConversations(user.id);

    // 2) Grouper par conversation (contexte + cible + autre participant)
    final Map<String, Map<String, dynamic>> grouped = {};
    final Set<String> participantIds = {};

    for (final msg in messages) {
      final otherId = (msg['sender_id'] == user.id)
          ? (msg['receiver_id']?.toString() ?? '')
          : (msg['sender_id']?.toString() ?? '');

      final key = [
        msg['contexte'] ?? '',
        (msg['annonce_id'] ?? msg['prestataire_id'] ?? '').toString(),
        otherId,
      ].join('-');

      if (otherId.isNotEmpty) {
        participantIds.add(otherId);
      }

      final existing = grouped[key];
      if (existing == null ||
          _asDate(msg['date_envoi']).isAfter(_asDate(existing['date_envoi']))) {
        grouped[key] = msg;
      }
    }

    // 3) Noms/prénoms des participants
    if (participantIds.isNotEmpty) {
      final users = await Supabase.instance.client
          .from('utilisateurs')
          .select('id, nom, prenom')
          .inFilter('id', participantIds.toList());
      _utilisateurs = {
        for (final u in (users as List))
          u['id'] as String: Map<String, dynamic>.from(u as Map)
      };
    } else {
      _utilisateurs = {};
    }

    // 4) Ordonner par date_envoi (robuste)
    final list = grouped.values.toList()
      ..sort((a, b) => _asDate(b['date_envoi']).compareTo(_asDate(a['date_envoi'])));

    if (!mounted) return;
    setState(() {
      _conversations = list;
      _loading = false;
    });
  }

  // -------------------- REALTIME --------------------
  void _listenRealtime() {
    _channel?.unsubscribe();
    _channel = Supabase.instance.client
        .channel('public:messages')
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
          .eq('receiver_id', user.id)
          .eq('sender_id', otherId); // pas de filtre sur lu

      // Optimiste
      final idx = _conversations.indexOf(convo);
      if (idx != -1 && mounted) {
        setState(() {
          _conversations[idx] = {..._conversations[idx], 'lu': true};
        });
      }

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
      final otherId =
          (m['sender_id'] == user?.id) ? m['receiver_id'] : m['sender_id'];
      final u = _utilisateurs[otherId];
      final nom =
          ("${u?['prenom'] ?? ''} ${u?['nom'] ?? ''}").toLowerCase().trim();
      return contenu.contains(filter) || nom.contains(filter);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        // 🔙 ton thème d’avant
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF113CFC)),
        title: const Text(
          "Messages",
          style: TextStyle(
            color: Color(0xFF113CFC),
            fontWeight: FontWeight.w600,
          ),
        ),
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
                              (m['receiver_id'] == user?.id) && (m['lu'] != true);

                          final otherId = (m['sender_id'] == user?.id)
                              ? m['receiver_id']
                              : m['sender_id'];

                          final utilisateur = _utilisateurs[otherId];
                          final title = (utilisateur != null)
                              ? "${utilisateur['prenom'] ?? ''} ${utilisateur['nom'] ?? ''}"
                                  .trim()
                              : (isAnnonce ? "Annonceur" : "Prestataire");

                          final subtitle = (m['contenu'] ?? '').toString();
                          final dateLabel = _dateLabel(m['date_envoi']);

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
                            trailing: Text(dateLabel, style: const TextStyle(fontSize: 12)),
                            onTap: () async {
                              await _markThreadAsRead(convo: m, otherId: otherId);

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
