import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaiementsPage extends StatefulWidget {
  final String userId;
  const PaiementsPage({super.key, required this.userId});

  @override
  State<PaiementsPage> createState() => _PaiementsPageState();
}

class _PaiementsPageState extends State<PaiementsPage> {
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
          .from('paiements')
          .select('id, course_id, payer_id, payee_id, amount, method, status, created_at')
          .or('payer_id.eq.${widget.userId},payee_id.eq.${widget.userId}')
          .order('created_at', ascending: false);
      setState(() => _rows = (r as List).map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _marquerPaye(String id) async {
    try {
      await _sb.from('paiements').update({'status': 'paid'}).eq('id', id);
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paiements')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(child: Text('Aucun paiement'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final p = _rows[i];
                    final isPayee = p['payee_id'] == widget.userId;
                    return ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(.2))),
                      title: Text('${p['amount']} GNF  •  ${p['method']}'),
                      subtitle: Text('Course: ${p['course_id']}\nStatut: ${p['status']}'),
                      trailing: isPayee && p['status'] != 'paid'
                          ? ElevatedButton(
                              onPressed: () => _marquerPaye(p['id'] as String),
                              child: const Text('Marquer payé'),
                            )
                          : null,
                    );
                  },
                ),
    );
  }
}
