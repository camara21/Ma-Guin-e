// lib/pages/messages_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/message_service.dart';
import 'messages/message_chat_page.dart'; // le chat est dans /pages/messages/

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final _searchCtrl = TextEditingController();
  final _sb = Supabase.instance.client;
  final MessageService _messageService = MessageService();

  // 🪣 bucket public utilisé pour les avatars (comme ta Home)
  static const String _avatarBucket = 'profile-photos';

  List<Map<String, dynamic>> _conversations = [];
  Map<String, Map<String, dynamic>> _utilisateurs = {}; // userId -> user map
  bool _loading = true;

  // cache: userId -> url http
  final Map<String, String> _avatarCache = {};

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

  // ───────── helpers ─────────
  DateTime _asDate(dynamic v) {
    if (v is DateTime) return v;
    if (v is String) {
      final d = DateTime.tryParse(v);
      if (d != null) return d;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _dateLabel(dynamic v) {
    final d = _asDate(v).toLocal();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$day/$m/$y';
  }

  String _initials(Map<String, dynamic>? u) {
    final p = (u?['prenom'] ?? '').toString().trim();
    final n = (u?['nom'] ?? '').toString().trim();
    final i1 = p.isNotEmpty ? p[0] : '';
    final i2 = n.isNotEmpty ? n[0] : '';
    final s = (i1 + i2).toUpperCase();
    return s.isNotEmpty ? s : '·';
  }

  // URL http déjà stockée (prioritaire, comme dans la Home)
  String? _rawUrl(Map<String, dynamic>? u) {
    if (u == null) return null;
    final url = u['photo_url']?.toString();
    if (url != null && url.startsWith('http')) return url;
    return null;
  }

  // Chemin storage éventuel
  String? _rawPath(Map<String, dynamic>? u) {
    if (u == null) return null;
    for (final k in const ['photo_path', 'photo_url', 'image_url', 'avatar_url', 'photo']) {
      final v = u[k]?.toString();
      if (v != null && v.isNotEmpty && !v.startsWith('http')) return v;
    }
    return null;
  }

  String _publicUrl(String pathInBucket) {
    return _sb.storage.from(_avatarBucket).getPublicUrl(pathInBucket);
  }

  Future<String?> _resolveAvatarForUser(String userId) async {
    final cached = _avatarCache[userId];
    if (cached != null) return cached;

    final u = _utilisateurs[userId];

    // 1) URL http déjà en base
    final direct = _rawUrl(u);
    if (direct != null) {
      _avatarCache[userId] = direct;
      return direct;
    }

    // 2) chemin storage
    String? path = _rawPath(u);
    if (path != null) {
      if (path.startsWith('$_avatarBucket/')) {
        path = path.substring(_avatarBucket.length + 1);
      }
      final url = _publicUrl(path);
      _avatarCache[userId] = url;
      return url;
    }

    // 3) fallback: deviner u/<userId>.ext (comme beaucoup de projets)
    for (final ext in const ['jpg', 'png', 'jpeg']) {
      final guess = 'u/$userId.$ext';
      final url = _publicUrl(guess);
      _avatarCache[userId] = url; // Image.network gérera un éventuel 404
      return url;
    }
    return null;
  }

  // ───────── data ─────────
  Future<void> _loadConversations() async {
    final me = _sb.auth.currentUser;
    if (me == null) {
      setState(() {
        _conversations = [];
        _utilisateurs = {};
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);

    try {
      final messages = await _messageService.fetchUserConversations(me.id);

      final Map<String, Map<String, dynamic>> grouped = {};
      final Set<String> participantIds = {};

      for (final raw in messages) {
        final msg = Map<String, dynamic>.from(raw as Map);

        final otherId = (msg['sender_id'] == me.id)
            ? (msg['receiver_id']?.toString() ?? '')
            : (msg['sender_id']?.toString() ?? '');

        final key = [
          msg['contexte'] ?? '',
          (msg['annonce_id'] ?? msg['prestataire_id'] ?? '').toString(),
          otherId,
        ].join('-');

        if (otherId.isNotEmpty) participantIds.add(otherId);

        final existing = grouped[key];
        if (existing == null ||
            _asDate(msg['date_envoi']).isAfter(_asDate(existing['date_envoi']))) {
          grouped[key] = msg;
        }
      }

      // 🔎 Récupérer les interlocuteurs avec FALLBACK si colonnes manquantes
      if (participantIds.isNotEmpty) {
        List users;
        try {
          users = await _sb
              .from('utilisateurs')
              .select('id, nom, prenom, photo_url, photo_path, image_url, avatar_url, photo')
              .inFilter('id', participantIds.toList());
        } catch (_) {
          try {
            users = await _sb
                .from('utilisateurs')
                .select('id, nom, prenom, photo_url, image_url, avatar_url, photo')
                .inFilter('id', participantIds.toList());
          } catch (_) {
            users = await _sb
                .from('utilisateurs')
                .select('id, nom, prenom, photo_url')
                .inFilter('id', participantIds.toList());
          }
        }

        _utilisateurs = {
          for (final u in users)
            u['id'].toString(): Map<String, dynamic>.from(u as Map)
        };

        // pré-résolution (non bloquante)
        for (final id in participantIds) {
          unawaited(_resolveAvatarForUser(id));
        }
      } else {
        _utilisateurs = {};
      }

      final list = grouped.values.toList()
        ..sort((a, b) => _asDate(b['date_envoi']).compareTo(_asDate(a['date_envoi'])));

      if (!mounted) return;
      setState(() {
        _conversations = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _conversations = [];
        _utilisateurs = {};
        _loading = false;
      });
      debugPrint('loadConversations error: $e');
    }
  }

  void _listenRealtime() {
    _channel?.unsubscribe();
    _channel = _sb
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

  Future<void> _markThreadAsRead({
    required Map<String, dynamic> convo,
    required String otherId,
  }) async {
    final me = _sb.auth.currentUser;
    if (me == null) return;

    try {
      final isAnnonce = convo['contexte'] == 'annonce';
      await _sb
          .from('messages')
          .update({'lu': true})
          .eq('contexte', convo['contexte'])
          .eq(isAnnonce ? 'annonce_id' : 'prestataire_id',
              isAnnonce ? convo['annonce_id'] : convo['prestataire_id'])
          .eq('receiver_id', me.id)
          .eq('sender_id', otherId);

      final idx = _conversations.indexOf(convo);
      if (idx != -1 && mounted) {
        setState(() => _conversations[idx] = {..._conversations[idx], 'lu': true});
      }
      _messageService.unreadChanged.add(null);
    } catch (e) {
      debugPrint('markAsRead error: $e');
    }
  }

  Future<bool> _confirmDelete() async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Supprimer'),
            content: const Text('Supprimer cette conversation ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
            ],
          ),
        ) ??
        false;
  }

  /// Suppression robuste: SELECT des ids (double IN), puis DELETE IN(id).
  Future<void> _deleteConversation({
    required Map<String, dynamic> convo,
    required String otherId,
  }) async {
    final me = _sb.auth.currentUser?.id;
    if (me == null) return;

    try {
      final isAnnonce = convo['contexte'] == 'annonce';
      final ctxCol = isAnnonce ? 'annonce_id' : 'prestataire_id';
      final ctxVal = isAnnonce ? convo['annonce_id'] : convo['prestataire_id'];

      final rows = await _sb
          .from('messages')
          .select('id')
          .eq('contexte', convo['contexte'])
          .eq(ctxCol, ctxVal)
          .inFilter('sender_id', [me, otherId])
          .inFilter('receiver_id', [me, otherId]);

      final ids = (rows as List)
          .map((e) => (e as Map)['id']?.toString())
          .whereType<String>()
          .toList();

      if (ids.isEmpty) return;

      await _sb.from('messages').delete().inFilter('id', ids);

      if (!mounted) return;
      setState(() {
        _conversations.remove(convo);
      });
      _messageService.unreadChanged.add(null);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Conversation supprimée.')));
    } catch (e) {
      // fallback: suppression une par une si la policy bloque le IN
      try {
        final rows = await _sb
            .from('messages')
            .select('id')
            .eq('contexte', convo['contexte'])
            .eq(isAnnonce(convo) ? 'annonce_id' : 'prestataire_id',
                isAnnonce(convo) ? convo['annonce_id'] : convo['prestataire_id'])
            .inFilter('sender_id', [me, otherId])
            .inFilter('receiver_id', [me, otherId]);
        final ids = (rows as List)
            .map((e) => (e as Map)['id']?.toString())
            .whereType<String>()
            .toList();
        for (final id in ids) {
          await _sb.from('messages').delete().eq('id', id);
        }
        if (mounted) {
          setState(() => _conversations.remove(convo));
          _messageService.unreadChanged.add(null);
        }
      } catch (_) {}
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur suppression: $e')));
    }
  }

  bool isAnnonce(Map<String, dynamic> m) => (m['contexte'] == 'annonce');

  // ───────── UI ─────────
  @override
  Widget build(BuildContext context) {
    final me = _sb.auth.currentUser;
    final filter = _searchCtrl.text.toLowerCase();

    final list = _conversations.where((m) {
      final contenu = (m['contenu'] ?? '').toString().toLowerCase();
      final otherId =
          (m['sender_id'] == me?.id) ? m['receiver_id'] : m['sender_id'];
      final u = _utilisateurs[otherId];
      final nom = ("${u?['prenom'] ?? ''} ${u?['nom'] ?? ''}").toLowerCase().trim();
      return contenu.contains(filter) || nom.contains(filter);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF113CFC)),
        title: const Text(
          "Messages",
          style: TextStyle(color: Color(0xFF113CFC), fontWeight: FontWeight.w600),
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

                          final isUnread =
                              (m['receiver_id'] == me?.id) && (m['lu'] != true);

                          final otherId = (m['sender_id'] == me?.id)
                              ? m['receiver_id']
                              : m['sender_id'];

                          final utilisateur = _utilisateurs[otherId];
                          final title = (utilisateur != null)
                              ? "${utilisateur['prenom'] ?? ''} ${utilisateur['nom'] ?? ''}".trim()
                              : "Utilisateur";

                          final subtitle = (m['contenu'] ?? '').toString();
                          final dateLabel = _dateLabel(m['date_envoi']);

                          final userId = (otherId ?? '').toString();
                          final initials = _initials(utilisateur);

                          final photoUrl = _avatarCache[userId];
                          if (photoUrl == null) {
                            unawaited(_resolveAvatarForUser(userId).then((_) {
                              if (mounted) setState(() {});
                            }));
                          }

                          final convKey = ValueKey<String>([
                            m['contexte'] ?? '',
                            (m['annonce_id'] ?? m['prestataire_id'] ?? '').toString(),
                            userId,
                          ].join('-'));

                          return Dismissible(
                            key: convKey,
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) => _confirmDelete(),
                            onDismissed: (_) =>
                                _deleteConversation(convo: m, otherId: userId),
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            child: ListTile(
                              onLongPress: () async {
                                final ok = await _confirmDelete();
                                if (ok) await _deleteConversation(convo: m, otherId: userId);
                              },
                              leading: Stack(
                                children: [
                                  ClipOval(
                                    child: SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: (photoUrl == null)
                                          ? _initialsAvatar(initials)
                                          : Image.network(
                                              photoUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  _initialsAvatar(initials),
                                            ),
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
                                await _markThreadAsRead(convo: m, otherId: userId);

                                final contextTypeStr =
                                    (m['contexte'] ?? '').toString(); // 'annonce' | 'prestataire'
                                final contextIdStr = contextTypeStr == 'annonce'
                                    ? (m['annonce_id'] ?? '').toString()
                                    : (m['prestataire_id'] ?? '').toString();

                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MessageChatPage(
                                      peerUserId: userId,
                                      title: title,
                                      contextType: contextTypeStr,
                                      contextId: contextIdStr,
                                    ),
                                  ),
                                );

                                _loadConversations();
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _initialsAvatar(String initials) => Container(
        color: const Color(0xFF113CFC),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      );
}
