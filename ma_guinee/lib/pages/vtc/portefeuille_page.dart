import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PortefeuilleChauffeurPage extends StatefulWidget {
  final String userId;
  const PortefeuilleChauffeurPage({super.key, required this.userId});

  @override
  State<PortefeuilleChauffeurPage> createState() => _PortefeuilleChauffeurPageState();
}

class _PortefeuilleChauffeurPageState extends State<PortefeuilleChauffeurPage> {
  final _sb = Supabase.instance.client;
  num _solde = 0;
  List<Map<String, dynamic>> _journal = [];
  bool _loading = true;
  final _montantCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await _sb
          .from('portefeuilles_chauffeur')
          .select('solde')
          .eq('user_id', widget.userId)
          .maybeSingle();
      _solde = (p?['solde'] as num?) ?? 0;

      final j = await _sb
          .from('journal_portefeuille')
          .select('id, type, montant, libelle, created_at')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);
      _journal = (j as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _demanderRetrait() async {
    final montant = num.tryParse(_montantCtrl.text.trim());
    if (montant == null || montant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Montant invalide')));
      return;
    }
    if (montant > _solde) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Montant > solde')));
      return;
    }
    try {
      await _sb.from('demandes_retrait').insert({
        'user_id': widget.userId,
        'montant': montant,
        'status': 'pending',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande envoyée')));
      _montantCtrl.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Portefeuille chauffeur')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                title: const Text('Solde disponible'),
                subtitle: Text('$_solde GNF', style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _montantCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Montant de retrait (GNF)'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _demanderRetrait, child: const Text('Retirer')),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: _journal.isEmpty
                  ? const Center(child: Text('Aucun mouvement'))
                  : ListView.separated(
                      itemCount: _journal.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final j = _journal[i];
                        return ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(.2))),
                          title: Text('${j['type']}  •  ${j['montant']} GNF'),
                          subtitle: Text(j['libelle'] ?? ''),
                          trailing: Text(j['created_at']?.toString().substring(0, 19) ?? ''),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
