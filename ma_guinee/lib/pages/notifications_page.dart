import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _subscribeToRealtimeNotifications();
  }

  Future<void> _loadNotifications() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final data = await Supabase.instance.client
        .from('notifications')
        .select()
        .eq('utilisateur_id', user.id)
        .order('date_creation', ascending: false);

    setState(() {
      _notifications = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  void _subscribeToRealtimeNotifications() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    Supabase.instance.client
        .from('notifications:utilisateur_id=eq.${user.id}')
        .stream(primaryKey: ['id'])
        .listen((data) {
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(data);
      });
    });
  }

  Future<void> _marquerCommeLue(String notificationId) async {
    await Supabase.instance.client
        .from('notifications')
        .update({'lu': true})
        .eq('id', notificationId);
  }

  Icon _getIcon(String type) {
    switch (type) {
      case 'payment':
        return Icon(Icons.payment, color: Colors.green[700]);
      case 'info':
        return Icon(Icons.info, color: Colors.orange[700]);
      case 'message':
        return Icon(Icons.message, color: Colors.blue[700]);
      case 'alerte':
        return Icon(Icons.warning, color: Colors.red[700]);
      default:
        return Icon(Icons.notifications, color: Colors.grey[700]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0.6,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text("Aucune notification."))
              : ListView.builder(
                  padding: const EdgeInsets.all(18),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notif = _notifications[index];
                    final estLue = notif['lu'] == true;

                    return ListTile(
                      onTap: () {
                        if (!estLue) _marquerCommeLue(notif['id']);
                      },
                      leading: Stack(
                        children: [
                          _getIcon(notif['type']),
                          if (!estLue)
                            Positioned(
                              right: 0,
                              top: 0,
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
                      ),
                      title: Text(notif['title'] ?? '',
                          style: TextStyle(
                            fontWeight: estLue ? FontWeight.normal : FontWeight.bold,
                          )),
                      subtitle: Text(notif['contenu'] ?? ''),
                    );
                  },
                ),
    );
  }
}
