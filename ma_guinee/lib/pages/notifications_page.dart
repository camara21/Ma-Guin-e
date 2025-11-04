// lib/pages/notifications_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // laissé si tu veux ouvrir un lien + tard

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
    _boot();
  }

  Future<void> _boot() async {
    if (_userId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    await _ensureWelcomeNotification();
    await _loadNotifications();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  // Helpers de mapping (titre/lu/date)
  String _titleOf(Map<String, dynamic> n) =>
      (n['title'] ?? n['titre'] ?? '').toString();

  bool _isRead(Map<String, dynamic> n) =>
      (n['lu'] == true) || (n['is_read'] == true);

  DateTime _dateOf(Map<String, dynamic> n) {
    final d1 = DateTime.tryParse((n['date_creation'] ?? '').toString());
    if (d1 != null) return d1;
    final d2 = DateTime.tryParse((n['created_at'] ?? '').toString());
    return d2 ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatDate(dynamic iso) {
    final d = DateTime.tryParse(iso?.toString() ?? '') ?? DateTime.now();
    final local = d.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$day/$m/$y • $hh:$mm';
  }

  /// Crée un "Bienvenue" si absent (remplit title + titre, lu + is_read, user_id + utilisateur_id)
  Future<void> _ensureWelcomeNotification() async {
    try {
      final existing = await _client
          .from('notifications')
          .select('id')
          .eq('utilisateur_id', _userId)
          .eq('type', 'welcome')
          .limit(1)
          .maybeSingle();

      if (existing == null) {
        await _client.from('notifications').insert({
          'utilisateur_id': _userId,
          'user_id': _userId, // pour compat multi-colonnes
          'type': 'welcome',
          'title': 'Bienvenue 👋',
          'titre': 'Bienvenue 👋',
          'contenu':
              "Ravi de vous compter parmi nous ! Vous recevrez ici les paiements, infos et alertes.",
          'lu': false,
          'is_read': false,
          'date_creation': DateTime.now().toUtc().toIso8601String(),
        });
      }
    } catch (_) {/* ignore si RLS empêche */}
  }

  /// Charge en tenant compte des alias (title/titre, lu/is_read, date_creation/created_at)
  Future<void> _loadNotifications() async {
    if (_userId.isEmpty) return;
    final data = await _client
        .from('notifications')
        .select('id, type, title, titre, contenu, lu, is_read, date_creation, created_at, utilisateur_id, user_id')
        .or('utilisateur_id.eq.$_userId,user_id.eq.$_userId') // au cas où seule l’une est remplie
        .neq('type', 'message')
        .order('date_creation', ascending: false) // si NULL, on retriera après
        .order('created_at', ascending: false);

    final list = List<Map<String, dynamic>>.from(data);
    // tri final sur date coalescée
    list.sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));

    if (!mounted) return;
    setState(() {
      _notifications = list;
      _loading = false;
    });
  }

  void _subscribeRealtime() {
    if (_userId.isEmpty) return;

    // On écoute par utilisateur_id; si ta prod remplit parfois user_id, fais deux streams ou crée une vue.
    _realtimeSub = _client
        .from('notifications:utilisateur_id=eq.${_userId}&type=neq.message')
        .stream(primaryKey: ['id']).listen((rows) {
      final list = List<Map<String, dynamic>>.from(rows);
      list.sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));
      if (!mounted) return;
      setState(() => _notifications = list);
    });
  }

  // Mise à jour optimiste + écris à la fois lu et is_read
  Future<void> _marquerCommeLue(String id, int index) async {
    if (index >= 0 && index < _notifications.length) {
      final n = _notifications[index];
      _notifications[index] = {...n, 'lu': true, 'is_read': true};
      setState(() {});
    }
    try {
      await _client
          .from('notifications')
          .update({'lu': true, 'is_read': true})
          .eq('id', id)
          .select()
          .maybeSingle();
    } catch (_) {/* ignore */}
  }

  Future<void> _openNotification(Map<String, dynamic> n, int index) async {
    final id = n['id'].toString();
    await _marquerCommeLue(id, index);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: controller,
            children: [
              Row(
                children: [
                  _iconForType(n['type']?.toString()),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _titleOf(n),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _formatDate(_dateOf(n).toIso8601String()),
                style: const TextStyle(color: Colors.black54),
              ),
              const Divider(height: 24),
              Text(
                (n['contenu'] ?? '').toString(),
                style: const TextStyle(fontSize: 16, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Icon _iconForType(String? type) {
    switch ((type ?? '').toLowerCase()) {
      case 'payment':
      case 'paiement':
        return Icon(Icons.payment, color: Colors.green[700], size: 22);
      case 'alerte':
      case 'warning':
        return Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 22);
      case 'success':
        return Icon(Icons.check_circle, color: Colors.green[700], size: 22);
      case 'info':
      case 'system':
        return Icon(Icons.info, color: Colors.blue[700], size: 22);
      case 'admin':
        return Icon(Icons.verified_user, color: Colors.deepPurple[700], size: 22);
      case 'reservation':
      case 'rdv':
        return Icon(Icons.event, color: Colors.teal[700], size: 22);
      case 'order':
        return Icon(Icons.receipt_long, color: Colors.indigo[700], size: 22);
      case 'hotel':
        return Icon(Icons.hotel, color: Colors.brown[700], size: 22);
      case 'restaurant':
        return Icon(Icons.restaurant, color: Colors.orange[700], size: 22);
      case 'event':
        return Icon(Icons.confirmation_number, color: Colors.pink[700], size: 22);
      case 'welcome':
        return Icon(Icons.waving_hand, color: Colors.blueGrey[700], size: 22);
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
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }

  Future<void> _refresh() async => _loadNotifications();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0.6,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('Aucune notification.'))
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(18),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final lu = _isRead(n);

                      return ListTile(
                        onTap: () => _openNotification(n, index),
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
                          _formatDate(_dateOf(n).toIso8601String()),
                          style: const TextStyle(fontSize: 12, color: Colors.black45),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
