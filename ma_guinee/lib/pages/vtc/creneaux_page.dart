import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreneauxChauffeurPage extends StatefulWidget {
  final String userId;
  const CreneauxChauffeurPage({super.key, required this.userId});

  @override
  State<CreneauxChauffeurPage> createState() => _CreneauxChauffeurPageState();
}

class _CreneauxChauffeurPageState extends State<CreneauxChauffeurPage> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _sb
          .from('creneaux_chauffeur')
          .select('id, start_time, end_time, active')
          .eq('user_id', widget.userId)
          .order('start_time', ascending: true);
      setState(() => _rows = (r as List).map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    DateTime? start = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 60)));
    if (start == null) return;
    final t1 = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
    if (t1 == null) return;
    final t2 = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 12, minute: 0));
    if (t2 == null) return;

    final st = DateTime(start.year, start.month, start.day, t1.hour, t1.minute);
    final et = DateTime(start.year, start.month, start.day, t2.hour, t2.minute);
    if (et.isBefore(st)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Horaire invalide')));
      return;
    }
    try {
      await _sb.from('creneaux_chauffeur').insert({
        'user_id': widget.userId,
        'start_time': st.toIso8601String(),
        'end_time': et.toIso8601String(),
        'active': true,
      });
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec: $e')));
    }
  }

  Future<void> _toggle(String id, bool active) async {
    try {
      await _sb.from('creneaux_chauffeur').update({'active': !active}).eq('id', id);
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec: $e')));
    }
  }

  Future<void> _delete(String id) async {
    try {
      await _sb.from('creneaux_chauffeur').delete().eq('id', id);
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec suppression: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créneaux de disponibilité'), actions: [
        IconButton(onPressed: _add, icon: const Icon(Icons.add)),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(child: Text('Aucun créneau'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = _rows[i];
                    final start = r['start_time']?.toString().replaceFirst('T', ' ').substring(0, 16) ?? '';
                    final end = r['end_time']?.toString().replaceFirst('T', ' ').substring(0, 16) ?? '';
                    final active = (r['active'] as bool?) ?? true;
                    return ListTile(
                      title: Text('$start  →  $end'),
                      subtitle: Text(active ? 'Actif' : 'Inactif'),
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          IconButton(onPressed: () => _toggle(r['id'] as String, active), icon: Icon(active ? Icons.pause : Icons.play_arrow)),
                          IconButton(onPressed: () => _delete(r['id'] as String), icon: const Icon(Icons.delete)),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
