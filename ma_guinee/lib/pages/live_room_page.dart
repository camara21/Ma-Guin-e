// lib/pages/live_room_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/live_service.dart';

class LiveRoomPage extends StatefulWidget {
  const LiveRoomPage({
    super.key,
    required this.roomId,
    required this.isHost,
    this.initialTitle,
  });

  final String roomId;
  final bool isHost;
  final String? initialTitle;

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends State<LiveRoomPage> {
  final _svc = LiveService();

  RealtimeChannel? _msgCh;
  RealtimeChannel? _metaCh;

  final _msgCtrl = TextEditingController();
  final _scroll = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;

  // meta
  bool _isLive = true;
  int _viewers = 0;
  int _likes = 0;
  String _title = 'Live';

  @override
  void initState() {
    super.initState();
    _title = widget.initialTitle ?? 'Live';
    _bootstrap();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scroll.dispose();
    _unsubscribe();
    _leave();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      // Rejoindre (présence + compteur soft)
      await _svc.join(widget.roomId);

      // Historique messages
      _messages = await _svc.listMessages(widget.roomId);

      // Abonnements realtime (sans filter param — filtrage dans callback)
      _msgCh = _svc.subscribeMessages(widget.roomId, (row) {
        setState(() => _messages.add(row));
        _scrollToBottom();
      });
      _metaCh = _svc.subscribeRoomMeta(widget.roomId, (row) {
        setState(() {
          _isLive = row['is_live'] == true;
          _viewers = (row['viewers_count'] ?? 0) as int;
          _likes = (row['likes_count'] ?? 0) as int;
          _title = (row['title'] ?? _title) as String;
        });
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur Live: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _unsubscribe() {
    if (_msgCh != null) _svc.unsubscribe(_msgCh!);
    if (_metaCh != null) _svc.unsubscribe(_metaCh!);
    _msgCh = null;
    _metaCh = null;
  }

  Future<void> _leave() async {
    try {
      await _svc.leave(widget.roomId);
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final txt = _msgCtrl.text.trim();
    if (txt.isEmpty) return;
    try {
      await _svc.sendMessage(widget.roomId, txt);
      _msgCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur envoi: $e')),
      );
    }
  }

  Future<void> _like() async {
    try {
      final n = await _svc.like(widget.roomId);
      if (mounted) setState(() => _likes = n);
    } catch (_) {}
  }

  Future<void> _endLive() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Terminer le live ?'),
        content: const Text('Les spectateurs ne pourront plus rejoindre.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Terminer')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _svc.endLive(widget.roomId);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur fin de live: $e')),
      );
    }
  }

  void _goHome() {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 54,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: GestureDetector(
            onTap: _goHome,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70, width: 1),
              ),
              child: Image.asset('assets/logo_guinee.png', height: 22),
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isLive ? Colors.redAccent.withOpacity(0.2) : Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    _isLive ? Icons.wifi_tethering : Icons.stop_circle_outlined,
                    color: _isLive ? Colors.redAccent : Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isLive ? 'EN DIRECT' : 'TERMINE',
                    style: TextStyle(color: _isLive ? Colors.redAccent : Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _title,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                const Icon(Icons.remove_red_eye, size: 18),
                const SizedBox(width: 4),
                Text('$_viewers'),
                const SizedBox(width: 10),
                const Icon(Icons.favorite, size: 18),
                const SizedBox(width: 4),
                Text('$_likes'),
                const SizedBox(width: 8),
              ],
            ),
          ),
          if (widget.isHost)
            TextButton.icon(
              onPressed: _endLive,
              icon: const Icon(Icons.stop, color: Colors.redAccent),
              label: const Text('Terminer', style: TextStyle(color: Colors.redAccent)),
            ),
          const SizedBox(width: 6),
        ],
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                const Expanded(child: _LivePlaceholderVideo()),
                // Chat
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    border: Border(top: BorderSide(color: Colors.white10)),
                  ),
                  height: 280,
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) {
                            final m = _messages[i];
                            final me = Supabase.instance.client.auth.currentUser?.id;
                            final isMe = me != null && me == (m['sender_id'] as String?);
                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.white24 : Colors.white12,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  (m['message'] ?? '').toString(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _msgCtrl,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'Message…',
                                  hintStyle: TextStyle(color: Colors.white54),
                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                                ),
                                onSubmitted: (_) => _send(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(onPressed: _send, icon: const Icon(Icons.send, color: Colors.white)),
                            const SizedBox(width: 4),
                            IconButton(onPressed: _like, icon: const Icon(Icons.favorite, color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Placeholder vidéo (surface sombre). Remplace par un vrai player HLS/DASH plus tard.
class _LivePlaceholderVideo extends StatelessWidget {
  const _LivePlaceholderVideo();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.videocam, color: Colors.white24, size: 72),
          SizedBox(height: 12),
          Text('Live en cours…', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}
