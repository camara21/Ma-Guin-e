import 'package:flutter/material.dart';
import '../services/events_service.dart';
import 'event_detail_page.dart';

class EventsListPage extends StatefulWidget {
  const EventsListPage({super.key});

  @override
  State<EventsListPage> createState() => _EventsListPageState();
}

class _EventsListPageState extends State<EventsListPage> {
  final _svc = EventsService();
  bool _loading = true;
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _svc.fetchEvents();
    setState(() {
      _events = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Événements')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _events.length,
                itemBuilder: (ctx, i) {
                  final ev = _events[i];
                  return ListTile(
                    leading: const Icon(Icons.event),
                    title: Text(ev['titre'] ?? ''),
                    subtitle: Text(ev['lieu'] ?? ''),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventDetailPage(event: ev),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
