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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MessageService _messageService = MessageService();

  late final _subscription;
  List<Map<String, dynamic>> messages = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _subscribeToMessages();
  }

  // Fetch all messages for this specific annonce
  Future<void> _fetchMessages() async {
    setState(() => loading = true);
    try {
      final msgs = await _messageService.fetchMessagesForAnnonce(widget.annonceId);
      setState(() {
        messages = msgs;
        loading = false;
      });
      _scrollDown();

      // Mark messages as read if they are for the current user (receiver)
      for (var msg in msgs) {
        if (msg['receiver_id'] == widget.senderId && !(msg['lu'] ?? true)) {
          await _messageService.markMessageAsRead(msg['id']);
        }
      }
    } catch (e) {
      setState(() {
        messages = [];
        loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur chargement messages : $e")),
      );
    }
  }

  // Subscribe to any new incoming messages for this annonce
  void _subscribeToMessages() {
    _subscription = _messageService.subscribeToAnnonceMessages(widget.annonceId, () {
      _fetchMessages();
    });
  }

  // Scroll to the bottom after a message is sent or new messages arrive
  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  // Send a message to the annonce
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final tempMessage = {
      'sender_id': widget.senderId,
      'contenu': text,
    };
    setState(() {
      messages.add(tempMessage); // Message temporaire local
    });
    _scrollDown();
    _messageController.clear();
    try {
      // Send message to Supabase
      await _messageService.sendMessageToAnnonce(
        senderId: widget.senderId,
        receiverId: widget.receiverId,
        annonceId: widget.annonceId,
        contenu: text,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur envoi message : $e")),
      );
    }
  }

  // Build a message widget to display messages
  Widget _buildMessage(Map<String, dynamic> msg) {
    final bool isMe = msg['sender_id'] == widget.senderId;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 8,
          bottom: 4,
          left: isMe ? 50 : 4,
          right: isMe ? 4 : 50,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF113CFC) : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 16),
          ),
        ),
        child: Text(
          msg['contenu'],
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 15.3,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _subscription.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1.4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF113CFC)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.annonceTitre,
            style: const TextStyle(color: Color(0xFF113CFC), fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
                      itemCount: messages.length,
                      itemBuilder: (_, idx) => _buildMessage(messages[idx]),
                    ),
                  ),
                  _buildInputBar(),
                ],
              ),
      ),
    );
  }

  // Build the input bar to send messages
  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F5FA),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "Écrivez un message...",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 7),
          ElevatedButton(
            onPressed: _sendMessage,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF113CFC),
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
            ),
            child: const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
