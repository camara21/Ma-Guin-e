import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../tourisme_detail_page.dart';

class ReservationsTourismePage extends StatefulWidget {
  const ReservationsTourismePage({super.key});

  @override
  State<ReservationsTourismePage> createState() => _ReservationsTourismePageState();
}

class _ReservationsTourismePageState extends State<ReservationsTourismePage> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) {
      setState(() {
        _items = [];
        _loading = false;
      });
      return;
    }
    try {
      final rows = await _sb
          .from('v_reservations_tourisme_admin')
          .select()
          .eq('user_id', uid)
          .neq('status', 'annule')
          .order('created_at', ascending: false);

      setState(() {
        _items = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _annuler(String id) async {
    final ok = await _confirm();
    if (!ok) return;
    try {
      await _sb.from('reservations_tourisme').update({'status': 'annule'}).eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réservation annulée.')));
        _load();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<bool> _confirm() async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Annuler la réservation ?'),
            content: const Text('Cette action met le statut à "annule".'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Oui')),
            ],
          ),
        ) ??
        false;
  }

  void _openLieu(Map<String, dynamic> r) {
    final lieu = {
      'id': r['lieu_id'],
      'nom': r['lieu_nom'],
      'ville': r['lieu_ville'],
    };
    Navigator.push(context, MaterialPageRoute(builder: (_) => TourismeDetailPage(lieu: lieu)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes réservations — Tourisme')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final r = _items[i];
                  final titre = (r['lieu_nom'] ?? 'Lieu').toString();
                  final ville = (r['lieu_ville'] ?? '').toString();
                  final dt = "${r['visit_date'] ?? ''} • ${r['arrival_time'] ?? ''}";
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.place),
                      title: Text(titre),
                      subtitle: Text("${ville.isNotEmpty ? '$ville • ' : ''}$dt"),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'open') _openLieu(r);
                          if (v == 'cancel') _annuler(r['id'].toString());
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'open', child: Text('Voir le lieu')),
                          PopupMenuItem(value: 'cancel', child: Text('Annuler')),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
