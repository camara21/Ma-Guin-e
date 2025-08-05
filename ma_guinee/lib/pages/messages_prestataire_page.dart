import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/message_service.dart';

class MessagesPrestatairePage extends StatefulWidget {
  final String prestataireId;
  final String prestataireNom;
  final String receiverId;
  final String senderId;

  const MessagesPrestatairePage({
    super.key,
    required this.prestataireId,
    required this.prestataireNom,
    required this.receiverId,
    required this.senderId,
  });

  @override
  State<MessagesPrestatairePage> createState() => _MessagesPrestatairePageState();
}

class _MessagesPrestatairePageState extends State<MessagesPrestatairePage> {
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
    final msgs = await _svc.fetchMessagesForPrestataire(widget.prestataireId);
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

    // ENVOI avec le nom du prestataire
    await _svc.sendMessageToPrestataire(
      senderId: widget.senderId,
      receiverId: widget.receiverId,
      prestataireId: widget.prestataireId,
      prestataireName: widget.prestataireNom, // <-- INDISPENSABLE pour la table !
      contenu: text,
    );
    // Pas besoin de reload ici, le stream realtime le fera !
  }

  Widget _bubble(Map<String, dynamic> m) {
    final me = m['sender_id'] == widget.senderId;
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: me ? const Color(0xFF113CFC) : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          m['contenu'] ?? '',
          style: TextStyle(color: me ? Colors.white : Colors.black87, fontSize: 15),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF113CFC)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.prestataireNom,
            style: const TextStyle(color: Color(0xFF113CFC), fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      itemCount: _msgs.length,
                      itemBuilder: (_, i) => _bubble(_msgs[i]),
                    ),
                  ),
                  _buildInputBar(),
                ],
              ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
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
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _send,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF113CFC),
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(14),
            ),
            child: const Icon(Icons.send, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}
