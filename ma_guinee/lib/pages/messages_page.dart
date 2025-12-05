// lib/pages/messages_page.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/message_service.dart';
import 'messages_annonce_page.dart'; // Chat ANNONCES
import 'messages/message_chat_page.dart'; // Chat LOGEMENT & PRESTATAIRE

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

  // Polling périodique
  Timer? _pollTimer;

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
    final now = DateTime.now();
    final isToday =
        d.year == now.year && d.month == now.month && d.day == now.day;
    if (isToday) {
      final hh = d.hour.toString().padLeft(2, '0');
      final mm = d.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
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

  String _threadKey(String contexte, dynamic ctxId, String otherId) =>
      '$contexte-${ctxId ?? ''}-$otherId';

  // ************ CORRECTION IMPORTANTE ************
  // Contexte stabilisé avec fallback message.id pour ANNONCE / LOGEMENT
  String _ctxIdForMessage(Map<String, dynamic> msg) {
    final ctx = (msg['contexte'] ?? '').toString();

    if (ctx == 'prestataire') {
      return (msg['prestataire_id'] ?? '').toString();
    }

    if (ctx == 'logement') {
      final lid = (msg['logement_id'] ?? '').toString();
      if (lid.isNotEmpty) return lid;

      final aid = (msg['annonce_id'] ?? '').toString();
      if (aid.isNotEmpty) return aid;

      return msg['id'].toString(); // fallback
    }

    if (ctx == 'annonce') {
      final aid = (msg['annonce_id'] ?? '').toString();
      if (aid.isNotEmpty) return aid;

      return msg['id'].toString(); // fallback robuste
    }

    return msg['id'].toString(); // sécurité
  }
  // ***********************************************

  @override
  void initState() {
    super.initState();
    _loadConversations(initial: true);
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadConversations(initial: false);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConversations({bool initial = false}) async {
    final me = _sb.auth.currentUser;
    if (me == null) {
      if (mounted) {
        setState(() {
          _conversations = [];
          _utilisateurs = {};
          _loading = false;
        });
      }
      return;
    }

    if (initial) {
      setState(() => _loading = true);
    }

    try {
      final messages = await _messageService.fetchUserConversations(me.id);
      final hiddenKeys = await _messageService.fetchHiddenThreadKeys(me.id);

      final grouped = <String, Map<String, dynamic>>{};
      final participantIds = <String>{};

      for (final raw in messages) {
        final msg = Map<String, dynamic>.from(raw as Map);

        final String senderId = (msg['sender_id'] ?? '').toString();
        final String receiverId = (msg['receiver_id'] ?? '').toString();
        final String myId = me.id;
        final String otherId = (senderId == myId) ? receiverId : senderId;

        if (otherId.isNotEmpty) participantIds.add(otherId);

        final ctx = (msg['contexte'] ?? '').toString();
        final ctxId = _ctxIdForMessage(msg);

        final keyExact = _threadKey(ctx, ctxId, otherId);
        final keyEmpty = _threadKey(ctx, '', otherId);

        final isHidden =
            hiddenKeys.contains(keyExact) || hiddenKeys.contains(keyEmpty);
        if (isHidden) {
          // Fil masqué pour CE user, quel que soit le contexte
          continue;
        }

        final gkey = '$ctx-$ctxId-$otherId';
        if (!grouped.containsKey(gkey) ||
            _asDate(msg['date_envoi'])
                .isAfter(_asDate(grouped[gkey]!['date_envoi']))) {
          grouped[gkey] = msg;
        }
      }

      Map<String, Map<String, dynamic>> usersMap = {};
      if (participantIds.isNotEmpty) {
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

        usersMap = {
          for (final u in (users as List? ?? const []))
            (u['id'] ?? '').toString(): Map<String, dynamic>.from(u as Map)
        };

        for (final id in participantIds) {
          unawaited(_resolveAvatarForUser(id));
        }
      }

      final list = grouped.values.toList()
        ..sort((a, b) =>
            _asDate(b['date_envoi']).compareTo(_asDate(a['date_envoi'])));

      if (!mounted) return;
      setState(() {
        _utilisateurs = usersMap;
        _conversations = list;
        if (initial) _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('loadConversations error: $e');
      if (initial) {
        setState(() {
          _conversations = [];
          _utilisateurs = {};
          _loading = false;
        });
      }
      // si ce n'est pas initial, on garde les anciennes données
    }
  }

  Future<void> _markThreadAsRead({
    required Map<String, dynamic> convo,
    required String otherId,
  }) async {
    final me = _sb.auth.currentUser;
    if (me == null) return;

    try {
      final ctx = (convo['contexte'] ?? '').toString();
      final isAnnOrLog = (ctx == 'annonce' || ctx == 'logement');
      final ctxId = isAnnOrLog
          ? _ctxIdForMessage(convo)
          : (convo['prestataire_id'] ?? '').toString();

      _messageService.decUnreadOptimistic(1);

      try {
        await _messageService.markThreadAsReadInstant(
          viewerUserId: me.id,
          contexte: ctx,
          otherUserId: otherId,
          annonceOrLogementId: isAnnOrLog ? ctxId : null,
          prestataireId: isAnnOrLog ? null : ctxId,
        );
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('42703') || msg.contains('user_id')) {
          if (kDebugMode) debugPrint('markThreadAsReadInstant ignoré: $e');
        } else {
          rethrow;
        }
      }

      final idx = _conversations.indexOf(convo);
      if (idx != -1 && mounted) {
        setState(
            () => _conversations[idx] = {..._conversations[idx], 'lu': true});
      }
    } catch (e) {
      debugPrint('markAsRead error: $e');
    }
  }

  Future<bool> _confirmDelete() async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Confirmer la suppression ?'),
            content: const Text("Voulez-vous supprimer cette conversation ?"),
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
    final ctxId = _ctxIdForMessage(convo);

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
    const primary = Color(0xFF2563EB);
    const secondary = Color(0xFF93C5FD);

    final me = _sb.auth.currentUser;
    final filter = _searchCtrl.text.toLowerCase();

    final list = _conversations.where((m) {
      final contenu = (m['contenu'] ?? '').toString().toLowerCase();

      final myId = me?.id ?? '';
      final otherIdStr = ((m['sender_id'] ?? '').toString() == myId)
          ? (m['receiver_id'] ?? '').toString()
          : (m['sender_id'] ?? '').toString();

      final u = _utilisateurs[otherIdStr];
      final nom =
          ("${u?['prenom'] ?? ''} ${u?['nom'] ?? ''}").toLowerCase().trim();

      final titreAnnonce = (m['annonce_titre'] ?? '').toString().toLowerCase();
      final titrePresta =
          (m['prestataire_name'] ?? '').toString().toLowerCase();
      final titre = titreAnnonce.isNotEmpty ? titreAnnonce : titrePresta;

      return filter.isEmpty ||
          contenu.contains(filter) ||
          nom.contains(filter) ||
          titre.contains(filter);
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

                          final myId = me?.id ?? '';
                          final senderId = (m['sender_id'] ?? '').toString();
                          final receiverId =
                              (m['receiver_id'] ?? '').toString();
                          final otherIdStr =
                              (senderId == myId) ? receiverId : senderId;

                          final isUnread =
                              (receiverId == myId) && (m['lu'] != true);

                          final utilisateur = _utilisateurs[otherIdStr];
                          final interlocutorName = (utilisateur != null)
                              ? "${utilisateur['prenom'] ?? ''} ${utilisateur['nom'] ?? ''}"
                                  .trim()
                              : "Utilisateur";

                          final subtitle = (m['contenu'] ?? '').toString();
                          final dateLabel = _date_label_safe(m['date_envoi']);

                          final userId = otherIdStr;
                          final initials = _initials(utilisateur);

                          final directUrl = _rawUrl(utilisateur);
                          String? photoUrl = directUrl ?? _avatarCache[userId];
                          if (photoUrl == null) {
                            unawaited(_resolveAvatarForUser(userId).then((_) {
                              if (mounted) setState(() {});
                            }));
                          }

                          final convKey = ValueKey<String>([
                            (m['contexte'] ?? '').toString(),
                            _ctxIdForMessage(m),
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
                                        backgroundColor: Colors.red,
                                      ),
                                    ),
                                ],
                              ),
                              title: Text(
                                interlocutorName.isEmpty
                                    ? "Utilisateur"
                                    : interlocutorName,
                                style: TextStyle(
                                  fontWeight: isUnread
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
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
                                  color: isUnread
                                      ? Colors.red
                                      : Colors.grey.shade600,
                                  fontWeight: isUnread
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                              onTap: () async {
                                await _markThreadAsRead(
                                    convo: m, otherId: userId);

                                final contexte =
                                    (m['contexte'] ?? '').toString();

                                if (contexte == 'annonce') {
                                  final annonceId =
                                      (m['annonce_id'] ?? '').toString();
                                  final annonceTitreRaw =
                                      (m['annonce_titre'] ?? '').toString();
                                  final annonceTitre =
                                      annonceTitreRaw.trim().isNotEmpty
                                          ? annonceTitreRaw
                                          : 'Annonce';

                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MessagesAnnoncePage(
                                        annonceId: annonceId,
                                        annonceTitre: annonceTitre,
                                        receiverId: userId,
                                        senderId: myId,
                                      ),
                                    ),
                                  );
                                } else if (contexte == 'logement') {
                                  final logementId = (m['logement_id'] ??
                                          m['annonce_id'] ??
                                          '')
                                      .toString();
                                  final logementTitreRaw =
                                      (m['annonce_titre'] ?? '').toString();
                                  final logementTitre =
                                      logementTitreRaw.trim().isNotEmpty
                                          ? logementTitreRaw
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
                                  final prestataireId =
                                      (m['prestataire_id'] ?? '').toString();
                                  final titre = (m['prestataire_name'] ??
                                          interlocutorName)
                                      .toString();

                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MessageChatPage(
                                        peerUserId: userId,
                                        title: titre,
                                        contextType: 'prestataire',
                                        contextId: prestataireId,
                                        contextTitle: titre,
                                      ),
                                    ),
                                  );
                                }

                                // refresh après retour (sans spinner)
                                _loadConversations(initial: false);
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

  String _date_label_safe(dynamic v) {
    try {
      return _dateLabel(v);
    } catch (_) {
      return '';
    }
  }

  Widget _initialsAvatar(String initials) => Container(
        color: const Color(0xFF2563EB),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
