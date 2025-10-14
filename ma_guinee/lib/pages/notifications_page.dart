// lib/pages/notifications_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _client = Supabase.instance.client;

  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSub;
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _userId = _client.auth.currentUser?.id ?? '';
    _loadNotifications();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  // Charge uniquement les notifs ADMIN (exclut type='message')
  Future<void> _loadNotifications() async {
    if (_userId.isEmpty) return;
    final data = await _client
        .from('notifications')
        .select()
        .eq('utilisateur_id', _userId)
        .neq('type', 'message') // ← admin only
        .order('date_creation', ascending: false);

    if (!mounted) return;
    setState(() {
      _notifications = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  void _subscribeRealtime() {
    if (_userId.isEmpty) return;
    // Filtre temps réel: user + pas "message"
    _realtimeSub = _client
        .from('notifications:utilisateur_id=eq.${_userId}&type=neq.message')
        .stream(primaryKey: ['id'])
        .listen((rows) {
      // on garde le tri desc par date_creation
      rows.sort((a, b) {
        final da = DateTime.tryParse(a['date_creation']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final db = DateTime.tryParse(b['date_creation']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
      if (!mounted) return;
      setState(() => _notifications = List<Map<String, dynamic>>.from(rows));
    });
  }

  // MAJ optimiste + update BDD
  Future<void> _marquerCommeLue(String id, int index) async {
    if (index >= 0 && index < _notifications.length) {
      setState(() {
        _notifications[index] = {..._notifications[index], 'lu': true};
      });
    }
    try {
      await _client
          .from('notifications')
          .update({'lu': true})
          .eq('id', id)
          .select()
          .maybeSingle();
    } catch (_) {
      // (optionnel) rollback si besoin
    }
  }

  Icon _iconForType(String? type) {
    switch (type) {
      case 'payment':
        return Icon(Icons.payment, color: Colors.green[700], size: 22);
      case 'alerte':
        return Icon(Icons.warning, color: Colors.red[700], size: 22);
      case 'info':
        return Icon(Icons.info, color: Colors.orange[700], size: 22);
      default:
        return Icon(Icons.notifications, color: Colors.blueGrey[600], size: 22);
    }
  }

  Widget _leadingWithDot(Icon icon, bool lu) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        if (!lu)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0.6,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text("Aucune notification."))
              : ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final n = _notifications[index];
                    final lu = n['lu'] == true;

                    return ListTile(
                      onTap: () => _marquerCommeLue(n['id'].toString(), index),
                      leading: _leadingWithDot(_iconForType(n['type']?.toString()), lu),
                      title: Text(
                        (n['title'] ?? '').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: lu ? FontWeight.normal : FontWeight.bold),
                      ),
                      subtitle: Text(
                        (n['contenu'] ?? '').toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
    );
  }
}
