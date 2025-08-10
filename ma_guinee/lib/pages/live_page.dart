// lib/pages/live_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/live_service.dart';
import 'live_room_page.dart';

class LivePage extends StatefulWidget {
  const LivePage({super.key});
  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  final _svc = LiveService();
  List<Map<String, dynamic>> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _rooms = await _svc.fetchLiveRooms();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement lives: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startLive() async {
    try {
      final title = await _askTitle();
      if (title == null) return;

      final id = await _svc.startLive(title: title);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveRoomPage(roomId: id, isHost: true, initialTitle: title),
        ),
      );
      _load(); // refresh au retour
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur démarrage live: $e')),
      );
    }
  }

  Future<String?> _askTitle() async {
    final ctrl = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Titre du live'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'ex. “Concert live”'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim().isEmpty ? 'Live' : ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _goHome() {
    // revient à la navigation déjà ouverte (première route)
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
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
        title: const Text('Lives'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _rooms.isEmpty
                  ? const Center(child: Text('Aucun live pour le moment'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _rooms.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final r = _rooms[i];
                        final live = r['is_live'] == true;
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              live ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                              color: live ? Colors.redAccent : null,
                            ),
                            title: Text((r['title'] ?? 'Live') as String),
                            subtitle: Text('👀 ${r['viewers_count'] ?? 0}   ❤️ ${r['likes_count'] ?? 0}'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () async {
                              final me = Supabase.instance.client.auth.currentUser?.id;
                              final isHost = me != null && me == r['host_id'];
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LiveRoomPage(
                                    roomId: r['id'] as String,
                                    isHost: isHost,
                                    initialTitle: (r['title'] as String?) ?? 'Live',
                                  ),
                                ),
                              );
                              _load();
                            },
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: user == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _startLive,
              icon: const Icon(Icons.videocam),
              label: const Text('Démarrer'),
            ),
    );
  }
}
