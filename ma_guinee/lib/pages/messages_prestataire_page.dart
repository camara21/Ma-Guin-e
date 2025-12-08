// lib/pages/messages_prestataire_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/message_service.dart';

class MessagesPrestatairePage extends StatefulWidget {
  final String prestataireId; // id du prestataire (contexte)
  final String prestataireNom; // titre AppBar
  final String receiverId; // id de l'autre utilisateur (peer)
  final String senderId; // mon id (fallback si auth.currentUser absent)

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

  // Polling périodique
  Timer? _pollTimer;

  // Id de l’utilisateur courant (auth) avec fallback sur senderId
  String get _meId => _sb.auth.currentUser?.id ?? widget.senderId;

  // L’autre utilisateur du fil (peer)
  String get _peerId => widget.receiverId;

  // ===== Helpers temps =====
  DateTime _asDate(dynamic v) {
    if (v is DateTime) return v.toLocal();
    if (v is String) {
      final d = DateTime.tryParse(v);
      if (d != null) return d.toLocal();
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _timeLabel(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void initState() {
    super.initState();
    _loadAndMarkRead(initial: true);
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadAndMarkRead(initial: false);
    });
  }

  // Charger l'historique VISIBLE POUR MOI + marquer *lu*
  Future<void> _loadAndMarkRead({bool initial = false}) async {
    if (!mounted) return;
    final viewerId = _meId;
    if (viewerId.isEmpty) return;

    if (initial) {
      setState(() => _loading = true);
    }

    try {
      final previousLastId =
          _msgs.isNotEmpty ? _msgs.last['id']?.toString() : null;

      // On récupère tous les messages pour ce prestataire visibles pour moi
      final all = await _svc.fetchMessagesForPrestataireVisibleTo(
        viewerUserId: viewerId,
        prestataireId: widget.prestataireId,
      );

      // On ne garde QUE le fil entre moi et _peerId
      final peerId = _peerId;
      final msgs = all.where((m) {
        final s = (m['sender_id'] ?? '').toString();
        final r = (m['receiver_id'] ?? '').toString();
        if (peerId.isEmpty) {
          // cas dégradé: on ne connaît pas le peer → on montre tout
          return true;
        }
        return (s == viewerId && r == peerId) || (s == peerId && r == viewerId);
      }).toList();

      // marquer *lu* les messages reçus par moi dans CE fil
      final idsAValider = <String>[
        for (final m in msgs)
          if ((m['receiver_id']?.toString() == viewerId) &&
              (m['lu'] == false || m['lu'] == null))
            m['id']?.toString() ?? ''
      ]..removeWhere((e) => e.isEmpty);

      if (idsAValider.isNotEmpty) {
        await _sb
            .from('messages')
            .update({'lu': true}).inFilter('id', idsAValider);
        _svc.unreadChanged.add(null);
      }

      if (!mounted) return;
      setState(() {
        // ordre fourni par le service (id ASC) → ne bouge plus
        _msgs = msgs;
        if (initial) _loading = false;
      });

      final newLastId = _msgs.isNotEmpty ? _msgs.last['id']?.toString() : null;
      if (initial || previousLastId != newLastId) {
        _scrollToEnd();
      }
    } catch (e) {
      if (!mounted) return;
      if (initial) {
        setState(() => _loading = false);
      }
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

  // Envoi message (client OU prestataire)
  Future<void> _envoyer() async {
    final texte = _ctrl.text.trim();
    if (texte.isEmpty) return;

    final meId = _meId;
    final peerId =
        _peerId; // l'autre utilisateur du fil (client ou prestataire)

    if (meId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Connectez-vous pour envoyer un message.")),
      );
      return;
    }

    _ctrl.clear();

    // affichage optimiste (toujours à la fin)
    setState(() {
      _msgs.add({
        'id': -1,
        'sender_id': meId,
        'receiver_id': peerId,
        'contenu': texte,
        'lu': true,
        'date_envoi': DateTime.now().toIso8601String(),
      });
    });
    _scrollToEnd();

    try {
      // Utilise le service central (qui déclenche push-send côté serveur)
      await _svc.sendMessageToPrestataire(
        senderId: meId,
        receiverId:
            peerId, // NON vide → le service ne renverra plus vers moi-même
        prestataireId: widget.prestataireId,
        prestataireName: widget.prestataireNom,
        contenu: texte,
      );

      // le polling rattrape, mais on force un refresh rapide
      await _loadAndMarkRead(initial: false);
    } catch (e) {
      if (!mounted) return;

      var msg = "Erreur d'envoi : $e";
      if (e.toString().contains("n'a pas de propriétaire")) {
        msg = "Ce prestataire n'a pas encore de compte relié.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  // Soft delete du fil pour MOI (masquer/supprimer la conversation)
  Future<void> _masquerConversationPourMoi() async {
    final me = _sb.auth.currentUser;
    final myId = me?.id ?? widget.senderId;

    final bool ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Supprimer la discussion ?'),
            content: const Text(
              "Cette discussion sera masquée pour vous. "
              "L'historique ne s'affichera plus dans vos messages, "
              "mais vous pourrez toujours écrire à nouveau à ce prestataire.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Supprimer la discussion'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    final peerId = _peerId;

    try {
      await _svc.hideThread(
        userId: myId,
        contexte: 'prestataire',
        prestataireId: widget.prestataireId,
        annonceId: null,
        peerUserId: peerId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversation supprimée.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  // Bulle (style cohérent avec MessagesAnnoncePage / Facebook-like)
  Widget _bulleMessage(Map<String, dynamic> m) {
    const bleu = Color(0xFF113CFC);
    const gris = Color(0xFFF3F5FA);

    final meId = _meId;
    final moi = m['sender_id']?.toString() == meId;

    final bg = moi ? bleu : gris;
    final textColor = moi ? Colors.white : Colors.black87;

    final dt = _asDate(m['date_envoi']);
    final time = _timeLabel(dt);

    return Align(
      alignment: moi ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: EdgeInsets.only(
          top: 6,
          bottom: 6,
          left: moi ? 40 : 12,
          right: moi ? 12 : 40,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(moi ? 18 : 8),
            bottomRight: Radius.circular(moi ? 8 : 18),
          ),
          boxShadow: [
            if (moi)
              BoxShadow(
                color: Colors.blue.shade100,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (m['contenu'] ?? '').toString(),
              style: TextStyle(color: textColor, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 10,
                  color: textColor.withOpacity(moi ? 0.8 : 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bleu = Color(0xFF113CFC);

    final inputEnabled = _sb.auth.currentUser != null;

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
                value: 'hide',
                child: Text('Supprimer cette conversation'),
              ),
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

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_msgs.isEmpty
                      ? Center(
                          child: Text(
                            "Aucune discussion.\nÉcrivez un message pour commencer.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
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
                    child: Container(
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
                              : "Envoi indisponible (connectez-vous)",
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
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: bleu,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
