// lib/pages/messages_prestataire_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/message_service.dart';

class MessagesPrestatairePage extends StatefulWidget {
  final String prestataireId; // id du prestataire (contexte)
  final String prestataireNom; // titre AppBar
  final String receiverId; // id de l'autre utilisateur (peut être vide/obsolète)
  final String senderId; // mon id

  const MessagesPrestatairePage({
    super.key,
    required this.prestataireId,
    required this.prestataireNom,
    required this.receiverId,
    required this.senderId,
  });

  @override
  State<MessagesPrestatairePage> createState() =>
      _MessagesPrestatairePageState();
}

class _MessagesPrestatairePageState extends State<MessagesPrestatairePage> {
  final _svc = MessageService();
  final _sb = Supabase.instance.client;

  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  List<Map<String, dynamic>> _msgs = <Map<String, dynamic>>[];
  bool _loading = true;

  RealtimeChannel? _channel;

  // Résolution du destinataire (source de vérité = prestataires.utilisateur_id)
  String? _resolvedReceiverId;
  bool _peerMissing =
      false; // pas de compte lié => envoi désactivé
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap(); // résout receiver + charge messages
    _listenRealtime(); // abonnement realtime
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Lit toujours `prestataires.utilisateur_id` (certain trigger l'exige),
  /// puis charge l'historique et marque *lu*.
  Future<void> _bootstrap() async {
    try {
      final row = await _sb
          .from('prestataires')
          .select('utilisateur_id')
          .eq('id', widget.prestataireId)
          .maybeSingle();

      final dbUid = (row?['utilisateur_id'] as String?)?.trim();

      if (dbUid == null || dbUid.isEmpty) {
        _peerMissing = true; // pas de compte lié -> interdire l’envoi
        _resolvedReceiverId = null;
      } else {
        _resolvedReceiverId = dbUid; // on s’aligne sur la base
      }

      await _loadAndMarkRead();
    } finally {
      if (mounted) setState(() => _ready = true);
    }
  }

  // Realtime: insert + update filtrés sur ce prestataire
  void _listenRealtime() {
    _channel?.unsubscribe();
    _channel = _sb
        .channel('public:messages:prestataire:${widget.prestataireId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final r = payload.newRecord ?? const <String, dynamic>{};
            if ((r['contexte'] == 'prestataire') &&
                (r['prestataire_id']?.toString() == widget.prestataireId)) {
              _loadAndMarkRead();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final r = (payload.newRecord ?? payload.oldRecord) ??
                const <String, dynamic>{};
            if ((r['contexte'] == 'prestataire') &&
                (r['prestataire_id']?.toString() == widget.prestataireId)) {
              _loadAndMarkRead();
            }
          },
        )
        .subscribe();
  }

  // Charger l'historique VISIBLE POUR MOI + marquer *lu*
  Future<void> _loadAndMarkRead() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final msgs = await _svc.fetchMessagesForPrestataireVisibleTo(
        viewerUserId: widget.senderId,
        prestataireId: widget.prestataireId,
      );

      // marquer *lu* les messages reçus par moi
      final idsAValider = <String>[
        for (final m in msgs)
          if ((m['receiver_id']?.toString() == widget.senderId) &&
              (m['lu'] == false || m['lu'] == null))
            m['id']?.toString() ?? ''
      ]..removeWhere((e) => e.isEmpty);

      if (idsAValider.isNotEmpty) {
        // supabase_flutter v2 => inFilter()
        await _sb
            .from('messages')
            .update({'lu': true}).inFilter('id', idsAValider);
        _svc.unreadChanged.add(null);
      }

      if (!mounted) return;
      setState(() {
        _msgs = msgs;
        _loading = false;
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur de chargement : $e")),
      );
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  // Envoi message
  Future<void> _envoyer() async {
    final texte = _ctrl.text.trim();
    if (texte.isEmpty) return;

    // Ne jamais tenter l'insert si pas de compte relié (évite P0001)
    if (_peerMissing ||
        _resolvedReceiverId == null ||
        _resolvedReceiverId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Ce prestataire n'a pas encore de compte relié.")),
      );
      return;
    }

    _ctrl.clear();

    // affichage optimiste
    setState(() {
      _msgs.add({
        'id': -1,
        'sender_id': widget.senderId,
        'receiver_id': _resolvedReceiverId,
        'contenu': texte,
        'lu': true,
        'date_envoi': DateTime.now().toIso8601String(),
      });
    });
    _scrollToEnd();

    try {
      await _svc.sendMessageToPrestataire(
        senderId: widget.senderId,
        receiverId: _resolvedReceiverId!, // résolu depuis la base
        prestataireId: widget.prestataireId,
        prestataireName: widget.prestataireNom,
        contenu: texte,
      );
      // le realtime rafraîchira l’écran
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erreur d'envoi : $e")));
    }
  }

  // Soft delete du fil pour MOI (masquer la conversation)
  Future<void> _masquerConversationPourMoi() async {
    try {
      await _svc.hideThread(
        userId: widget.senderId,
        contexte: 'prestataire',
        prestataireId: widget.prestataireId,
        peerUserId: _resolvedReceiverId ?? widget.receiverId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Conversation masquée.')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  // Bulle
  Widget _bulleMessage(Map<String, dynamic> m) {
    const bleu = Color(0xFF113CFC);
    const prestataireColor = Color(0xFF10B981); // *** Couleur prestataire ***

    final moi = m['sender_id']?.toString() == widget.senderId;
    final bg = moi ? bleu : prestataireColor;
    final fg = Colors.white;

    return Align(
      alignment: moi ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(moi ? 16 : 6),
            bottomRight: Radius.circular(moi ? 6 : 16),
          ),
          boxShadow: [
            if (moi)
              BoxShadow(
                  color: Colors.blue.shade100,
                  blurRadius: 2,
                  offset: const Offset(0, 1)),
          ],
        ),
        child: Text(
          (m['contenu'] ?? '').toString(),
          style: TextStyle(color: fg, fontSize: 15),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bleu = Color(0xFF113CFC);

    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final inputEnabled = !_peerMissing &&
        (_resolvedReceiverId != null && _resolvedReceiverId!.isNotEmpty);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: bleu),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.prestataireNom,
          style: const TextStyle(color: bleu, fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'hide') _masquerConversationPourMoi();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'hide', child: Text('Masquer cette conversation')),
            ],
          ),
        ],
        iconTheme: const IconThemeData(color: bleu),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Aperçu carte + avatar du prestataire
            _PrestatairePreviewHeader(prestataireId: widget.prestataireId),

            if (_peerMissing)
              Container(
                width: double.infinity,
                color: Colors.amber.shade100,
                padding: const EdgeInsets.all(12),
                child: const Text(
                  "Ce prestataire n'a pas encore de compte relié. "
                  "L'envoi de messages est temporairement désactivé.",
                  style: TextStyle(fontSize: 13),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_msgs.isEmpty
                      ? Center(
                          child: Text(
                            "Aucune discussion.\nÉcrivez un message pour commencer.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          itemCount: _msgs.length,
                          itemBuilder: (_, i) => _bulleMessage(_msgs[i]),
                        )),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container
                      (
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F5FA),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _ctrl,
                        decoration: InputDecoration(
                          hintText: inputEnabled
                              ? "Écrire un message…"
                              : "Envoi indisponible pour ce prestataire",
                          border: InputBorder.none,
                        ),
                        minLines: 1,
                        maxLines: 5,
                        onSubmitted: (_) => _envoyer(),
                        enabled: inputEnabled,
                        readOnly: !inputEnabled,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: inputEnabled ? _envoyer : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: bleu,
                      disabledBackgroundColor: Colors.grey.shade400,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(14),
                    ),
                    child:
                        const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget: aperçu du prestataire (photo + infos)
class _PrestatairePreviewHeader extends StatefulWidget {
  const _PrestatairePreviewHeader({required this.prestataireId});
  final String prestataireId;

  @override
  State<_PrestatairePreviewHeader> createState() =>
      _PrestatairePreviewHeaderState();
}

class _PrestatairePreviewHeaderState extends State<_PrestatairePreviewHeader> {
  final _sb = Supabase.instance.client;

  static const String _avatarBucket = 'profile-photos';

  String? _publicUrl(String bucket, String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final objectPath =
        path.startsWith('$bucket/') ? path.substring(bucket.length + 1) : path;
    return _sb.storage.from(bucket).getPublicUrl(objectPath);
  }

  Map<String, dynamic>? _row;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _sb
          .from('prestataires')
          .select('nom, metier, ville, avatar_path')
          .eq('id', widget.prestataireId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _row = r;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bleu = Color(0xFF113CFC);
    if (_loading) {
      return const SizedBox(
        height: 88,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_row == null) return const SizedBox.shrink();

    final avatarUrl =
        _publicUrl(_avatarBucket, _row!['avatar_path'] as String?);
    final title = (_row!['nom'] ?? 'Prestataire').toString();
    final subtitleParts = <String>[
      if ((_row!['metier'] ?? '').toString().trim().isNotEmpty) _row!['metier'],
      if ((_row!['ville'] ?? '').toString().trim().isNotEmpty) _row!['ville'],
    ];
    final subtitle = subtitleParts.join(' • ');

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 58,
              height: 58,
              color: const Color(0xFFF3F5FA),
              child: avatarUrl == null
                  ? const Icon(Icons.person, size: 34, color: Colors.grey)
                  : Image.network(avatarUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: bleu,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    )),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: bleu),
        ],
      ),
    );
  }
}
