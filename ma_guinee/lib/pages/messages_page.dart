// lib/pages/messages_page.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/message_service.dart';
import 'messages_annonce_page.dart'; // ANNONCES
import 'messages/message_chat_page.dart'; // LOGEMENT & PRESTATAIRE

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final _searchCtrl = TextEditingController();
  final _sb = Supabase.instance.client;
  final MessageService _messageService = MessageService();

  static const String _avatarBucket = 'profile-photos';

  List<Map<String, dynamic>> _conversations = [];
  Map<String, Map<String, dynamic>> _utilisateurs = {};
  bool _loading = true;

  final Map<String, String> _avatarCache = {};
  RealtimeChannel? _channel;

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
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  String _initials(Map<String, dynamic>? u) {
    final p = (u?['prenom'] ?? '').toString().trim();
    final n = (u?['nom'] ?? '').toString().trim();
    final s =
        '${p.isNotEmpty ? p[0] : ''}${n.isNotEmpty ? n[0] : ''}'.toUpperCase();
    return s.isNotEmpty ? s : '·';
  }

  String? _rawUrl(Map<String, dynamic>? u) {
    if (u == null) return null;
    final url = u['photo_url']?.toString();
    return (url != null && url.startsWith('http')) ? url : null;
  }

  String? _rawPath(Map<String, dynamic>? u) {
    if (u == null) return null;
    for (final k in const [
      'photo_path',
      'photo_url',
      'image_url',
      'avatar_url',
      'photo'
    ]) {
      final v = u[k]?.toString();
      if (v != null && v.isNotEmpty && !v.startsWith('http')) return v;
    }
    return null;
  }

  String _publicUrl(String pathInBucket) =>
      _sb.storage.from(_avatarBucket).getPublicUrl(pathInBucket);

  Future<String?> _resolveAvatarForUser(String userId) async {
    final cached = _avatarCache[userId];
    if (cached != null) return cached;

    final u = _utilisateurs[userId];
    final direct = _rawUrl(u);
    if (direct != null) {
      _avatarCache[userId] = direct;
      return direct;
    }

    String? path = _rawPath(u);
    if (path != null) {
      if (path.startsWith('$_avatarBucket/')) {
        path = path.substring(_avatarBucket.length + 1);
      }
      final url = _publicUrl(path);
      _avatarCache[userId] = url;
      return url;
    }

    for (final ext in const ['jpg', 'png', 'jpeg']) {
      final guess = 'u/$userId.$ext';
      final url = _publicUrl(guess);
      _avatarCache[userId] = url;
      return url;
    }
  }

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

  String _threadKey(String contexte, dynamic ctxId, String otherId) =>
      '$contexte-${ctxId ?? ''}-$otherId';

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
      final hiddenKeys = await _messageService.fetchHiddenThreadKeys(me.id);

      final grouped = <String, Map<String, dynamic>>{};
      final participantIds = <String>{};

      for (final raw in messages) {
        final msg = Map<String, dynamic>.from(raw as Map);

        final otherId = (msg['sender_id'] == me.id)
            ? (msg['receiver_id']?.toString() ?? '')
            : (msg['sender_id']?.toString() ?? '');
        if (otherId.isNotEmpty) participantIds.add(otherId);

        final ctx = (msg['contexte'] ?? '').toString();
        final ctxId = (ctx == 'prestataire')
            ? (msg['prestataire_id'] ?? '')
            : (msg['annonce_id'] ?? '');

        if (hiddenKeys.contains(_threadKey(ctx, ctxId, otherId))) continue;

        final gkey = '$ctx-$ctxId-$otherId';
        if (!grouped.containsKey(gkey) ||
            _asDate(msg['date_envoi'])
                .isAfter(_asDate(grouped[gkey]!['date_envoi']))) {
          grouped[gkey] = msg;
        }
      }

      // Récup infos interlocuteurs (robuste aux colonnes manquantes)
      List users;
      try {
        users = await _sb
            .from('utilisateurs')
            .select(
                'id,nom,prenom,photo_url,photo_path,image_url,avatar_url,photo')
            .inFilter('id', participantIds.toList());
      } catch (_) {
        try {
          users = await _sb
              .from('utilisateurs')
              .select('id,nom,prenom,photo_url,image_url,avatar_url,photo')
              .inFilter('id', participantIds.toList());
        } catch (_) {
          users = await _sb
              .from('utilisateurs')
              .select('id,nom,prenom,photo_url')
              .inFilter('id', participantIds.toList());
        }
      }

      _utilisateurs = {
        for (final u in (users as List? ?? const []))
          u['id'].toString(): Map<String, dynamic>.from(u as Map)
      };
      for (final id in participantIds) {
        unawaited(_resolveAvatarForUser(id));
      }

      final list = grouped.values.toList()
        ..sort((a, b) =>
            _asDate(b['date_envoi']).compareTo(_asDate(a['date_envoi'])));

      if (!mounted) return;
      setState(() {
        _conversations = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('loadConversations error: $e');
      setState(() {
        _conversations = [];
        _utilisateurs = {};
        _loading = false;
      });
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
            callback: (_) => _loadConversations())
        .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'messages',
            callback: (_) => _loadConversations())
        .subscribe();
  }

  Future<void> _markThreadAsRead({
    required Map<String, dynamic> convo,
    required String otherId,
  }) async {
    final me = _sb.auth.currentUser;
    if (me == null) return;

    try {
      final ctx = (convo['contexte'] ?? '').toString();
      final isAnnonceOrLogement = (ctx == 'annonce' || ctx == 'logement');
      await _sb
          .from('messages')
          .update({'lu': true})
          .eq('contexte', ctx)
          .eq(
              isAnnonceOrLogement ? 'annonce_id' : 'prestataire_id',
              isAnnonceOrLogement
                  ? convo['annonce_id']
                  : convo['prestataire_id'])
          .eq('receiver_id', me.id)
          .eq('sender_id', otherId);

      final idx = _conversations.indexOf(convo);
      if (idx != -1 && mounted) {
        setState(
            () => _conversations[idx] = {..._conversations[idx], 'lu': true});
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
            title: const Text('Supprimer la conversation ?'),
            content: const Text(
                "Elle sera supprimée pour vous (l’autre personne la verra toujours)."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Supprimer')),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteConversation({
    required Map<String, dynamic> convo,
    required String otherId,
  }) async {
    final me = _sb.auth.currentUser?.id;
    if (me == null) return;

    final ctx = (convo['contexte'] ?? '').toString();
    final ctxId = ((ctx == 'annonce' || ctx == 'logement')
            ? convo['annonce_id']
            : convo['prestataire_id'])
        ?.toString();

    try {
      await _messageService.hideThread(
        userId: me,
        contexte: ctx,
        annonceId: (ctx == 'annonce' || ctx == 'logement') ? ctxId : null,
        prestataireId: (ctx == 'prestataire') ? ctxId : null,
        peerUserId: otherId,
      );

      if (!mounted) return;
      setState(() => _conversations.remove(convo));
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation supprimée.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2563EB);    // messagesPrimary
    const onPrimary = Color(0xFFFFFFFF);  // messagesOnPrimary
    const secondary = Color(0xFF93C5FD);  // messagesSecondary

    final me = _sb.auth.currentUser;
    final filter = _searchCtrl.text.toLowerCase();

    final list = _conversations.where((m) {
      final contenu = (m['contenu'] ?? '').toString().toLowerCase();
      final otherId =
          (m['sender_id'] == me?.id) ? m['receiver_id'] : m['sender_id'];
      final u = _utilisateurs[otherId];
      final nom =
          ("${u?['prenom'] ?? ''} ${u?['nom'] ?? ''}").toLowerCase().trim();
      return contenu.contains(filter) || nom.contains(filter);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: primary),
        title: const Text(
          "Messages",
          style: TextStyle(color: primary, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher…',
                prefixIcon: const Icon(Icons.search, color: primary),
                filled: true,
                fillColor: secondary.withOpacity(0.12),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: secondary.withOpacity(0.6)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: primary, width: 1.6),
                ),
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
                          final interlocutorName = (utilisateur != null)
                              ? "${utilisateur['prenom'] ?? ''} ${utilisateur['nom'] ?? ''}"
                                  .trim()
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
                            (m['contexte'] ?? '').toString(),
                            (m['annonce_id'] ?? m['prestataire_id'] ?? '')
                                .toString(),
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child:
                                  const Icon(Icons.delete, color: Colors.white),
                            ),
                            child: ListTile(
                              onLongPress: () async {
                                final ok = await _confirmDelete();
                                if (ok) {
                                  await _deleteConversation(
                                      convo: m, otherId: userId);
                                }
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
                                        backgroundColor: primary,
                                      ),
                                    ),
                                ],
                              ),
                              title: Text(
                                interlocutorName,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                dateLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              onTap: () async {
                                await _markThreadAsRead(
                                    convo: m, otherId: userId);

                                final contexte =
                                    (m['contexte'] ?? '').toString();

                                if (contexte == 'annonce') {
                                  // Chat d'ANNONCE
                                  final annonceId =
                                      (m['annonce_id'] ?? '').toString();
                                  final annonceTitre =
                                      ((m['annonce_titre'] ?? '') as String)
                                              .trim()
                                              .isNotEmpty
                                          ? (m['annonce_titre'] as String)
                                          : 'Annonce';

                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MessagesAnnoncePage(
                                        annonceId: annonceId,
                                        annonceTitre: annonceTitre,
                                        receiverId: userId,
                                        senderId: _sb.auth.currentUser!.id,
                                      ),
                                    ),
                                  );
                                } else if (contexte == 'logement') {
                                  // Chat de LOGEMENT (ouvre une carte logement)
                                  final logementId = (m['annonce_id'] ?? '')
                                      .toString(); // réutilise annonce_id
                                  final logementTitre =
                                      ((m['annonce_titre'] ?? '') as String)
                                              .trim()
                                              .isNotEmpty
                                          ? (m['annonce_titre'] as String)
                                          : 'Logement';

                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MessageChatPage(
                                        peerUserId: userId,
                                        title: logementTitre,
                                        contextType: 'logement',
                                        contextId: logementId,
                                        contextTitle: logementTitre,
                                      ),
                                    ),
                                  );
                                } else {
                                  // Chat PRESTATAIRE (générique)
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MessageChatPage(
                                        peerUserId: userId,
                                        title: interlocutorName,
                                        contextType: 'prestataire',
                                        contextId: (m['prestataire_id'] ?? '')
                                            .toString(),
                                        contextTitle: interlocutorName,
                                      ),
                                    ),
                                  );
                                }

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
        color: const Color(0xFF2563EB), // messagesPrimary
        alignment: Alignment.center,
        child: Text(
          initials,
          style: const TextStyle(
            color: Color(0xFFFFFFFF), // onPrimary
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
