import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/message_service.dart';

class MessagesAnnoncePage extends StatefulWidget {
  final String annonceId;
  final String annonceTitre;
  final String receiverId;
  final String senderId;

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
    _loadMessages();
    _sub = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .listen((_) => _loadMessages());
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    final msgs = await _svc.fetchMessagesForAnnonce(widget.annonceId);
    for (var m in msgs) {
      if (m['receiver_id'].toString() == widget.senderId && m['lu'] == false) {
        await _svc.markMessageAsRead(m['id'].toString());
      }
    }
    setState(() {
      _msgs = msgs;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    setState(() {
      _msgs.add({
        'sender_id': widget.senderId,
        'contenu': text,
        'lu': true,
        'id': -1,
        'date_envoi': DateTime.now().toIso8601String(),
      });
    });
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);

    try {
      await _svc.sendMessageToAnnonce(
        senderId: widget.senderId,
        receiverId: widget.receiverId,
        annonceId: widget.annonceId,
        annonceTitre: widget.annonceTitre,
        contenu: text,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l'envoi du message : $e")),
      );
    }
  }

  Widget _bubble(Map<String, dynamic> m) {
    final me = m['sender_id'] == widget.senderId;
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
          m['contenu'] ?? '',
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
    final bleuMaGuinee = const Color(0xFF113CFC);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF113CFC)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.annonceTitre,
          style: const TextStyle(
              color: Color(0xFF113CFC), fontWeight: FontWeight.bold, fontSize: 17),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF113CFC)),
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
