import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/events_service.dart';

class MyTicketsPage extends StatefulWidget {
  const MyTicketsPage({super.key});

  @override
  State<MyTicketsPage> createState() => _MyTicketsPageState();
}

class _MyTicketsPageState extends State<MyTicketsPage> {
  final _svc = EventsService();
  bool _loading = true;
  List<Map<String, dynamic>> _tickets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await _svc.fetchMyTickets();
    setState(() {
      _tickets = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes billets')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _tickets.length,
              itemBuilder: (ctx, i) {
                final t = _tickets[i];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(t['events']['titre'] ?? ''),
                    subtitle: Text(t['ticket_types']['nom'] ?? ''),
                    trailing: QrImageView(
                      data: t['qr_code'],
                      size: 50,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
