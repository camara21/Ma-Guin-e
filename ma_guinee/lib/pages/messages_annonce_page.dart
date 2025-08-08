import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/message_service.dart';

class MessagesAnnoncePage extends StatefulWidget {
  final String annonceId;
  final String annonceTitre;
  final String receiverId; // id du destinataire
  final String senderId;   // mon id (expéditeur)

  const MessagesAnnoncePage({
    super.key,
    required this.annonceId,
    required this.annonceTitre,
    required this.receiverId,
    required this.senderId,
  });

  @override
  State<MessagesAnnoncePage> createState() => _MessagesAnnoncePageState();
}

class _MessagesAnnoncePageState extends State<MessagesAnnoncePage> {
  final _svc = MessageService();
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  List<Map<String, dynamic>> _msgs = [];
  bool _loading = true;

  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  @override
  void initState() {
    super.initState();
    _loadAndMarkRead();

    // ⚠️ Supabase 2.x : on écoute la table sans .eq/.filter/.order ici
    _sub = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .listen((_) => _loadAndMarkRead());
  }

  Future<void> _loadAndMarkRead() async {
    setState(() => _loading = true);
    try {
      // 1) Récupérer uniquement les messages de CETTE annonce via le service
      final msgs = await _svc.fetchMessagesForAnnonce(widget.annonceId);

      // 2) Marquer comme lus ceux reçus par moi
      final idsToMark = <String>[];
      for (final m in msgs) {
        final isForMe = (m['receiver_id']?.toString() == widget.senderId);
        final notRead = (m['lu'] == false || m['lu'] == null);
        if (isForMe && notRead) {
          final id = m['id']?.toString();
          if (id != null) idsToMark.add(id);
        }
      }

      if (idsToMark.isNotEmpty) {
        await Supabase.instance.client
            .from('messages')
            .update({'lu': true})
            .inFilter('id', idsToMark);

        // 🔔 préviens la nav/badge global(e) qu’il faut recalculer
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
      debugPrint('Erreur load/mark read (annonce): $e');
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

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    _ctrl.clear();

    // UI optimiste
    setState(() {
      _msgs.add({
        'id': -1,
        'sender_id': widget.senderId,
        'receiver_id': widget.receiverId,
        'contenu': text,
        'lu': true,
        'date_envoi': DateTime.now().toIso8601String(),
      });
    });
    _scrollToEnd();

    try {
      await _svc.sendMessageToAnnonce(
        senderId: widget.senderId,
        receiverId: widget.receiverId,
        annonceId: widget.annonceId,
        annonceTitre: widget.annonceTitre,
        contenu: text,
      );
      // Le stream realtime rafraîchira la liste
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l'envoi du message : $e")),
      );
    }
  }

  Widget _bubble(Map<String, dynamic> m) {
    final me = m['sender_id']?.toString() == widget.senderId;
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: EdgeInsets.only(
          top: 7,
          bottom: 7,
          left: me ? 40 : 12,
          right: me ? 12 : 40,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: me ? const Color(0xFF113CFC) : const Color(0xFFF3F5FA),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(me ? 16 : 6),
            bottomRight: Radius.circular(me ? 6 : 16),
          ),
          boxShadow: [
            if (me)
              BoxShadow(
                color: Colors.blue.shade100,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Text(
          (m['contenu'] ?? '').toString(),
          style: TextStyle(
            color: me ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bleuMaGuinee = Color(0xFF113CFC);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: bleuMaGuinee),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.annonceTitre,
          style: const TextStyle(
            color: bleuMaGuinee,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        iconTheme: const IconThemeData(color: bleuMaGuinee),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: _msgs.isEmpty
                        ? Center(
                            child: Text(
                              "Aucune discussion pour cette annonce.\nÉcrivez un message pour commencer.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600], fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            itemCount: _msgs.length,
                            itemBuilder: (_, i) => _bubble(_msgs[i]),
                          ),
                  ),
                  _buildInputBar(bleuMaGuinee),
                ],
              ),
      ),
    );
  }

  Widget _buildInputBar(Color bleuMaGuinee) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F5FA),
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  hintText: "Écrire un message…",
                  border: InputBorder.none,
                ),
                minLines: 1,
                maxLines: 5,
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 7),
          ElevatedButton(
            onPressed: _send,
            style: ElevatedButton.styleFrom(
              backgroundColor: bleuMaGuinee,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(13),
              elevation: 2,
            ),
            child: const Icon(Icons.send, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}
