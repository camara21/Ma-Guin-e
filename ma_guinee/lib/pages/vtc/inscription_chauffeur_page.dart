import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../routes.dart';

class InscriptionChauffeurPage extends StatefulWidget {
  const InscriptionChauffeurPage({super.key});

  @override
  State<InscriptionChauffeurPage> createState() => _InscriptionChauffeurPageState();
}

class _InscriptionChauffeurPageState extends State<InscriptionChauffeurPage> {
  final _sb = Supabase.instance.client;
  final _villeCtrl = TextEditingController(text: 'Conakry');
  final _permisCtrl = TextEditingController();
  String _typePref = 'car';
  bool _loading = false;

  @override
  void dispose() {
    _villeCtrl.dispose();
    _permisCtrl.dispose();
    super.dispose();
  }

  Future<void> _soumettre() async {
    final u = _sb.auth.currentUser;
    if (u == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }
    if (_permisCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('N° permis requis')));
      return;
    }
    setState(() => _loading = true);
    try {
      await _sb.from('chauffeurs').upsert({
        'id': u.id, // si la PK = user.id
        'user_id': u.id, // si la table a user_id plutôt que id
        'city': _villeCtrl.text.trim(),
        'vehicle_pref': _typePref,
        'permis_num': _permisCtrl.text.trim(),
        'is_online': false,
        'is_verified': false,
      }, onConflict: 'id');

      // Portefeuille si pas existant
      await _sb.rpc('ensure_portefeuille', params: {'p_user_id': u.id}).catchError((_) async {
        // fallback: insert direct si pas de RPC
        final existing = await _sb.from('portefeuilles_chauffeur').select('user_id').eq('user_id', u.id).maybeSingle();
        if (existing == null) {
          await _sb.from('portefeuilles_chauffeur').insert({'user_id': u.id, 'solde': 0});
        }
      });

      // Rôle
      await _sb.from('utilisateurs').update({'role': 'chauffeur'}).eq('id', u.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inscription envoyée.')));
      Navigator.pushReplacementNamed(context, AppRoutes.vtcHome);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Devenir chauffeur')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(controller: _villeCtrl, decoration: const InputDecoration(labelText: 'Ville')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _typePref,
              decoration: const InputDecoration(labelText: 'Type préféré'),
              items: const [
                DropdownMenuItem(value: 'car', child: Text('Voiture')),
                DropdownMenuItem(value: 'moto', child: Text('Moto')),
              ],
              onChanged: (v) => setState(() => _typePref = v ?? 'car'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _permisCtrl, decoration: const InputDecoration(labelText: 'Numéro de permis')),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loading ? null : _soumettre,
              icon: const Icon(Icons.check),
              label: const Text('Soumettre'),
            ),
          ],
        ),
      ),
    );
  }
}
