import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../api_wontanara.dart';
import '../models.dart';
import '../realtime_wontanara.dart';

/// Chat Wontanara pour l'ENTRAIDE uniquement (éphémère).
///
/// - [topicId] est OBLIGATOIRE : identifiant de la demande d'aide / room.
/// - Chaque room correspond à une demande d’entraide, un fil de discussion éphémère.
class PageChat extends StatefulWidget {
  const PageChat({
    super.key,
    required this.topicId,
    this.title,
  });

  /// Identifiant de la demande d’entraide / room.
  final String topicId;

  /// Titre affiché dans l’AppBar
  final String? title;

  @override
  State<PageChat> createState() => _PageChatState();
}

class _PageChatState extends State<PageChat> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  late final String _topicId;

  List<Message> _messages = [];
  RealtimeChannel? _channel;

  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _topicId = widget.topicId; // éphémère entraide uniquement
    _initChat();
  }

  Future<void> _initChat() async {
    await _loadMessages();
    await _listenRealtime();
  }

  Future<void> _loadMessages() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // Backend : interpréter _topicId comme room_id / demande_entraide_id
      final res = await ApiChat.listerMessages(_topicId);

      setState(() {
        _messages = res;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = "Impossible de charger les messages.";
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur chargement messages : $e")),
        );
      }
    }
  }

  Future<void> _listenRealtime() async {
    try {
      _channel = await RealtimeWontanara.abonnMessagesZone(
        _topicId, // côté helper, filtrer sur ce room/entraid_id
        (row) {
          final m = Message.fromMap(row);
          if (!mounted) return;

          setState(() {
            // ListView.reverse = true → on ajoute en tête
            _messages.insert(0, m);
          });

          _scrollToLatest();
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur abonnement temps réel : $e")),
        );
      }
    }
  }

  void _scrollToLatest() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendMessage() async {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty || _sending) return;

    FocusScope.of(context).unfocus();
    _ctrl.clear();

    setState(() => _sending = true);

    try {
      // Le realtime ajoutera le message (évite les doublons).
      await ApiChat.envoyerMessageZone(_topicId, txt);
    } catch (e) {
      if (!mounted) return;
      _ctrl.text = txt; // on remet le texte en cas d’erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur envoi message : $e")),
      );
    } finally {
      if (!mounted) return;
      setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? 'Chat entraide éphémère';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessagesArea()),
          const Divider(height: 1),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessagesArea() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loadMessages,
                icon: const Icon(Ionicons.refresh),
                label: const Text("Réessayer"),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "Aucun message pour l’instant.\nExpliquez votre besoin pour obtenir de l’aide 👋",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      reverse: true, // le plus récent en haut
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final m = _messages[i];
        return _MessageBubble(message: m);
      },
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: 'Décrivez votre besoin d’aide…',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              onPressed: _sending ? null : _sendMessage,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Ionicons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.contenu,
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}
