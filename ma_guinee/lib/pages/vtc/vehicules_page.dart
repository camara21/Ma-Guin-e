import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VehiculesPage extends StatefulWidget {
  final String ownerUserId;
  const VehiculesPage({super.key, required this.ownerUserId});

  @override
  State<VehiculesPage> createState() => _VehiculesPageState();
}

class _VehiculesPageState extends State<VehiculesPage> {
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
          .from('vehicules')
          .select('id, type, marque, modele, plaque, couleur, actif')
          .eq('owner_user_id', widget.ownerUserId)
          .order('created_at', ascending: false);
      setState(() => _rows = (r as List).map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _openEdit({Map<String, dynamic>? row}) async {
    String type = row?['type'] ?? 'car';
    final marque = TextEditingController(text: row?['marque'] ?? '');
    final modele = TextEditingController(text: row?['modele'] ?? '');
    final plaque = TextEditingController(text: row?['plaque'] ?? '');
    final couleur = TextEditingController(text: row?['couleur'] ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(row == null ? 'Nouveau véhicule' : 'Modifier véhicule'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'car', child: Text('Voiture')),
                  DropdownMenuItem(value: 'moto', child: Text('Moto')),
                ],
                onChanged: (v) => type = v ?? 'car',
              ),
              TextField(controller: marque, decoration: const InputDecoration(labelText: 'Marque')),
              TextField(controller: modele, decoration: const InputDecoration(labelText: 'Modèle')),
              TextField(controller: plaque, decoration: const InputDecoration(labelText: 'Plaque')),
              TextField(controller: couleur, decoration: const InputDecoration(labelText: 'Couleur')),
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
        'owner_user_id': widget.ownerUserId,
        'type': type,
        'marque': marque.text.trim(),
        'modele': modele.text.trim(),
        'plaque': plaque.text.trim(),
        'couleur': couleur.text.trim(),
        'actif': true,
      };
      if (row == null) {
        await _sb.from('vehicules').insert(payload);
      } else {
        await _sb.from('vehicules').update(payload).eq('id', row['id']);
      }
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec: $e')));
    }
  }

  Future<void> _toggle(String id, bool actif) async {
    try {
      await _sb.from('vehicules').update({'actif': !actif}).eq('id', id);
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec: $e')));
    }
  }

  Future<void> _delete(String id) async {
    try {
      await _sb.from('vehicules').delete().eq('id', id);
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec suppression: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes véhicules'), actions: [
        IconButton(onPressed: _openEdit, icon: const Icon(Icons.add)),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(child: Text('Aucun véhicule'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final v = _rows[i];
                    final actif = (v['actif'] as bool?) ?? true;
                    return ListTile(
                      title: Text('${v['type']} • ${v['marque']} ${v['modele']}'),
                      subtitle: Text('Plaque: ${v['plaque']} • Couleur: ${v['couleur']}'),
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          IconButton(onPressed: () => _openEdit(row: v), icon: const Icon(Icons.edit)),
                          IconButton(onPressed: () => _toggle(v['id'] as String, actif), icon: Icon(actif ? Icons.toggle_on : Icons.toggle_off)),
                          IconButton(onPressed: () => _delete(v['id'] as String), icon: const Icon(Icons.delete)),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
