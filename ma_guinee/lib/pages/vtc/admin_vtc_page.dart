import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminVtcPage extends StatefulWidget {
  const AdminVtcPage({super.key});

  @override
  State<AdminVtcPage> createState() => _AdminVtcPageState();
}

class _AdminVtcPageState extends State<AdminVtcPage> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _pendingDrivers = [];
  List<Map<String, dynamic>> _revenusJour = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await _sb
          .from('chauffeurs')
          .select('id, user_id, city, vehicle_pref, is_verified')
          .eq('is_verified', false);
      _pendingDrivers = (d as List).map((e) => Map<String, dynamic>.from(e)).toList();

      // Vue agrégée si dispo
      try {
        final rev = await _sb.from('v_revenus_plateforme_jour').select('jour, total_gnf').order('jour', ascending: false).limit(14);
        _revenusJour = (rev as List).map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {
        _revenusJour = [];
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _valider(String id) async {
    try {
      await _sb.from('chauffeurs').update({'is_verified': true}).eq('id', id);
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec validation: $e')));
    }
  }

  Future<void> _refuser(String id) async {
    try {
      await _sb.from('chauffeurs').delete().eq('id', id);
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec suppression: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin VTC'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text('Chauffeurs en attente', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_pendingDrivers.isEmpty)
                  const Text('Aucun en attente')
                else
                  ..._pendingDrivers.map((c) => Card(
                        child: ListTile(
                          title: Text('${c['user_id']} • ${c['city']}'),
                          subtitle: Text('Préférence: ${c['vehicle_pref']}'),
                          trailing: Wrap(
                            spacing: 6,
                            children: [
                              IconButton(onPressed: () => _valider(c['id'] as String), icon: const Icon(Icons.check, color: Colors.green)),
                              IconButton(onPressed: () => _refuser(c['id'] as String), icon: const Icon(Icons.close, color: Colors.red)),
                            ],
                          ),
                        ),
                      )),
                const Divider(height: 24),
                Text('Revenus plateforme (14 derniers jours)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_revenusJour.isEmpty)
                  const Text('Vue indisponible')
                else
                  ..._revenusJour.map((r) => ListTile(
                        title: Text('${r['jour']}'),
                        trailing: Text('${r['total_gnf']} GNF'),
                      )),
              ],
            ),
    );
  }
}
