import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReglesTarifairesPage extends StatefulWidget {
  const ReglesTarifairesPage({super.key});

  @override
  State<ReglesTarifairesPage> createState() => _ReglesTarifairesPageState();
}

class _ReglesTarifairesPageState extends State<ReglesTarifairesPage> {
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
          .from('regles_tarifaires')
          .select('id, city, vehicle, base, per_km, per_min, surge')
          .order('city', ascending: true)
          .order('vehicle', ascending: true);
      setState(() => _rows = (r as List).map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _openEdit({Map<String, dynamic>? row}) async {
    final cityCtrl = TextEditingController(text: row?['city'] ?? 'Conakry');
    String vehicle = row?['vehicle'] ?? 'car';
    final baseCtrl = TextEditingController(text: (row?['base'] ?? 10000).toString());
    final perKmCtrl = TextEditingController(text: (row?['per_km'] ?? 2000).toString());
    final perMinCtrl = TextEditingController(text: (row?['per_min'] ?? 200).toString());
    final surgeCtrl = TextEditingController(text: (row?['surge'] ?? 1).toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(row == null ? 'Nouvelle règle' : 'Modifier règle'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'Ville')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: vehicle,
                decoration: const InputDecoration(labelText: 'Véhicule'),
                items: const [
                  DropdownMenuItem(value: 'car', child: Text('Voiture')),
                  DropdownMenuItem(value: 'moto', child: Text('Moto')),
                ],
                onChanged: (v) => vehicle = v ?? 'car',
              ),
              const SizedBox(height: 8),
              TextField(controller: baseCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Base')),
              TextField(controller: perKmCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Par km')),
              TextField(controller: perMinCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Par min')),
              TextField(controller: surgeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Surge (x)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final payload = {
        'city': cityCtrl.text.trim(),
        'vehicle': vehicle,
        'base': num.tryParse(baseCtrl.text.trim()) ?? 0,
        'per_km': num.tryParse(perKmCtrl.text.trim()) ?? 0,
        'per_min': num.tryParse(perMinCtrl.text.trim()) ?? 0,
        'surge': num.tryParse(surgeCtrl.text.trim()) ?? 1,
      };
      if (row == null) {
        await _sb.from('regles_tarifaires').insert(payload);
      } else {
        await _sb.from('regles_tarifaires').update(payload).eq('id', row['id']);
      }
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec: $e')));
    }
  }

  Future<void> _delete(String id) async {
    try {
      await _sb.from('regles_tarifaires').delete().eq('id', id);
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec suppression: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Règles tarifaires'),
        actions: [IconButton(onPressed: () => _openEdit(), icon: const Icon(Icons.add))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final r = _rows[i];
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(.2))),
                  title: Text('${r['city']} • ${r['vehicle']}'),
                  subtitle: Text('Base ${r['base']} | km ${r['per_km']} | min ${r['per_min']} | x${r['surge']}'),
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      IconButton(onPressed: () => _openEdit(row: r), icon: const Icon(Icons.edit)),
                      IconButton(onPressed: () => _delete(r['id'] as String), icon: const Icon(Icons.delete)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
