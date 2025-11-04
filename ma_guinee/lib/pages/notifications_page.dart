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
  final _sb = Supabase.instance.client;

  String _userId = '';
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  // garde en mémoire ce qu’on vient de marquer lu (pour éviter tout “revert” visuel)
  final Set<String> _justRead = {};

  @override
  void initState() {
    super.initState();
    _userId = _sb.auth.currentUser?.id ?? '';
    _load();
  }

  Future<void> _load() async {
    if (_userId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final rows = await _sb
          .from('notifications')
          .select(
              'id, type, title, titre, contenu, lu, is_read, created_at, date_creation, utilisateur_id, user_id')
          .or('utilisateur_id.eq.${_userId},user_id.eq.${_userId}')
          .neq('type', 'message')
          .order('date_creation', ascending: false)
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(rows);
      list.sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));

      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      // on reste silencieux ici, mais tu peux logger si besoin
    }
  }

  // -------------------- helpers --------------------
  String _titleOf(Map<String, dynamic> n) =>
      (n['title'] ?? n['titre'] ?? '').toString();

  bool _isRead(Map<String, dynamic> n) =>
      (n['lu'] == true) || (n['is_read'] == true) || _justRead.contains(n['id'].toString());

  DateTime _dateOf(Map<String, dynamic> n) {
    final d1 = DateTime.tryParse((n['date_creation'] ?? '').toString());
    if (d1 != null) return d1;
    final d2 = DateTime.tryParse((n['created_at'] ?? '').toString());
    return d2 ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatDate(DateTime d) {
    final local = d.toLocal();
    final y = '${local.year}'.padLeft(4, '0');
    final m = '${local.month}'.padLeft(2, '0');
    final day = '${local.day}'.padLeft(2, '0');
    final hh = '${local.hour}'.padLeft(2, '0');
    final mm = '${local.minute}'.padLeft(2, '0');
    return '$day/$m/$y • $hh:$mm';
  }

  Icon _iconForType(String? type) {
    switch ((type ?? '').toLowerCase()) {
      case 'payment':
      case 'paiement':
        return const Icon(Icons.payment, color: Colors.green, size: 22);
      case 'alerte':
      case 'warning':
        return const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22);
      case 'success':
        return const Icon(Icons.check_circle, color: Colors.green, size: 22);
      case 'info':
      case 'system':
        return const Icon(Icons.info, color: Colors.blue, size: 22);
      case 'admin':
        return const Icon(Icons.verified_user, color: Colors.deepPurple, size: 22);
      case 'reservation':
      case 'rdv':
        return const Icon(Icons.event, color: Colors.teal, size: 22);
      case 'order':
        return const Icon(Icons.receipt_long, color: Colors.indigo, size: 22);
      case 'hotel':
        return const Icon(Icons.hotel, color: Colors.brown, size: 22);
      case 'restaurant':
        return const Icon(Icons.restaurant, color: Colors.orange, size: 22);
      case 'event':
        return const Icon(Icons.confirmation_number, color: Colors.pink, size: 22);
      case 'welcome':
        return const Icon(Icons.waving_hand, color: Colors.blueGrey, size: 22);
      default:
        return const Icon(Icons.notifications, color: Colors.blueGrey, size: 22);
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

  // -------------------- actions --------------------
  Future<void> _markAsRead(String id, int index) async {
    // 1) met à jour l’UI instantanément
    _justRead.add(id);
    if (index >= 0 && index < _items.length) {
      final n = _items[index];
      _items[index] = {...n, 'lu': true, 'is_read': true};
    }
    setState(() {});

    // 2) push en base
    try {
      await _sb
          .from('notifications')
          .update({'lu': true, 'is_read': true})
          .eq('id', id);
    } catch (_) {
      // si l’update échoue, on peut (optionnel) revert
      // pour l’instant on laisse lu pour éviter le clignotement
    }
  }

  Future<void> _open(Map<String, dynamic> n, int index) async {
    final id = n['id'].toString();
    await _markAsRead(id, index);

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _iconForType(n['type']?.toString()),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _titleOf(n),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _formatDate(_dateOf(n)),
                style: const TextStyle(color: Colors.black54),
              ),
              const Divider(height: 24),
              Text(
                (n['contenu'] ?? '').toString(),
                style: const TextStyle(fontSize: 16, height: 1.35),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _refresh() => _load();

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0.6,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('Aucune notification.'))
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(18),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final n = _items[index];
                      final lu = _isRead(n);

                      return ListTile(
                        key: ValueKey(n['id']),
                        onTap: () => _open(n, index),
                        leading: _leadingWithDot(
                          _iconForType(n['type']?.toString()),
                          lu,
                        ),
                        title: Text(
                          _titleOf(n),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: lu ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          (n['contenu'] ?? '').toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          _formatDate(_dateOf(n)),
                          style: const TextStyle(fontSize: 12, color: Colors.black45),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
