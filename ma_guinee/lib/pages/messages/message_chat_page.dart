import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/user_provider.dart';
import '../../models/utilisateur_model.dart';

class MessageChatPage extends StatefulWidget {
  const MessageChatPage({
    super.key,
    required this.peerUserId,     // destinataire (propriétaire du bien)
    required this.title,          // ex: titre du logement
    this.contextType = 'logement',
    required this.contextId,      // id du logement
  });

  final String peerUserId;
  final String title;
  final String contextType;
  final String contextId;

  @override
  State<MessageChatPage> createState() => _MessageChatPageState();
}

class _MessageChatPageState extends State<MessageChatPage> {
  final _sb = Supabase.instance.client;

  final _text = TextEditingController();
  final _scroll = ScrollController();

  late Stream<List<_Msg>> _stream;
  bool _sending = false;

  String? _myId() {
    try {
      final u = context.read<UserProvider?>()?.utilisateur;
      final id = (u as UtilisateurModel?)?.id;
      if (id != null && id.toString().isNotEmpty) return id.toString();
    } catch (_) {}
    return _sb.auth.currentUser?.id;
  }

  @override
  void initState() {
    super.initState();
    // stream par polling léger (2s). Tu peux passer en Realtime plus tard.
    _stream = Stream.periodic(const Duration(seconds: 2))
        .asyncMap((_) => _fetchThread());
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<List<_Msg>> _fetchThread() async {
    final me = _myId();
    if (me == null) return [];

    final orFilter =
        'and(from_id.eq.$me,to_id.eq.${widget.peerUserId}),and(from_id.eq.${widget.peerUserId},to_id.eq.$me)';

    final rows = await _sb
        .from('messages')
        .select('id, from_id, to_id, body, context_type, context_id, created_at, read_at')
        .or(orFilter)
        .eq('context_type', widget.contextType)
        .eq('context_id', widget.contextId)
        .order('created_at', ascending: true);

    return (rows as List)
        .map((e) => _Msg.fromMap(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> _send() async {
    final me = _myId();
    final body = _text.text.trim();
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour envoyer un message.')),
      );
      return;
    }
    if (body.isEmpty) return;

    setState(() => _sending = true);
    try {
      await _sb.from('messages').insert({
        'from_id': me,
        'to_id': widget.peerUserId,
        'body': body,
        'context_type': widget.contextType,
        'context_id': widget.contextId,
      });
      _text.clear();
      // petit délai pour laisser le stream se rafraîchir puis scroll en bas
      await Future.delayed(const Duration(milliseconds: 200));
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur envoi: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _myId();

    return Scaffold(
      appBar: AppBar(title: Text('Message • ${widget.title}')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<_Msg>>(
              stream: _stream,
              builder: (context, snap) {
                final items = snap.data ?? const <_Msg>[];
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final m = items[i];
                    final isMine = (m.fromId == me);
                    return _Bubble(
                      isMine: isMine,
                      body: m.body,
                      time: _fmtTime(context, m.createdAt),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Écrire un message…',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                    label: const Text('Envoyer'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtTime(BuildContext ctx, DateTime dt) {
    final t = TimeOfDay.fromDateTime(dt.toLocal());
    return t.format(ctx);
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.isMine, required this.body, required this.time});
  final bool isMine;
  final String body;
  final String time;

  @override
  Widget build(BuildContext context) {
    final bgMine = Theme.of(context).colorScheme.primary;
    final fgMine = Theme.of(context).colorScheme.onPrimary;
    final bgOther = Theme.of(context).colorScheme.surfaceVariant;
    final fgOther = Theme.of(context).colorScheme.onSurface;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMine ? bgMine : bgOther,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body, style: TextStyle(color: isMine ? fgMine : fgOther)),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 10,
                  color: (isMine ? fgMine : fgOther).withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Msg {
  final String id;
  final String fromId;
  final String toId;
  final String body;
  final DateTime createdAt;

  _Msg({required this.id, required this.fromId, required this.toId, required this.body, required this.createdAt});

  factory _Msg.fromMap(Map<String, dynamic> m) => _Msg(
        id: m['id'].toString(),
        fromId: m['from_id'].toString(),
        toId: m['to_id'].toString(),
        body: (m['body'] ?? '').toString(),
        createdAt: DateTime.parse(m['created_at'].toString()),
      );
}
