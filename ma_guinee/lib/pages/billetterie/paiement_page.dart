import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaiementPage extends StatefulWidget {
  final String reservationId; // uuid de reservations_billets
  final int montantGNF;

  const PaiementPage({
    super.key,
    required this.reservationId,
    required this.montantGNF,
  });

  @override
  State<PaiementPage> createState() => _PaiementPageState();
}

class _PaiementPageState extends State<PaiementPage> {
  final _sb = Supabase.instance.client;
  bool _processing = false;
  String _methode = 'Orange Money'; // exemple

  Future<void> _payer() async {
    setState(() => _processing = true);
    try {
      // TODO: intégrer la passerelle réelle (OM, PayTech, Stripe, …)
      // Simulation de succès :
      await Future.delayed(const Duration(seconds: 1));

      await _sb.from('paiements_billets').insert({
        'reservation_id': widget.reservationId,
        'montant_gnf': widget.montantGNF,
        'fournisseur': _methode,
        'reference_externe': 'SIM-${DateTime.now().millisecondsSinceEpoch}',
        'statut': 'reussi',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paiement confirmé ✅')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        title: const Text('Paiement'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              title: const Text('Montant'),
              trailing: Text(
                '${widget.montantGNF} GNF',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _methode,
              items: const [
                DropdownMenuItem(value: 'Orange Money', child: Text('Orange Money')),
                DropdownMenuItem(value: 'PayTech', child: Text('PayTech')),
                DropdownMenuItem(value: 'Stripe', child: Text('Stripe')),
              ],
              onChanged: (v) => setState(() => _methode = v!),
              decoration: const InputDecoration(labelText: 'Méthode'),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _processing ? null : _payer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _processing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Payer maintenant'),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: const Color(0xFFF7F7F7),
    );
  }
}
