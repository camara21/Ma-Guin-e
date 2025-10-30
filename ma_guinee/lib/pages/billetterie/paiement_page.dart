// lib/pages/billetterie/paiement_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart'; // v2: pour PostgrestException
import '../../services/billetterie_service.dart';

// Palette directe (pas de ServiceColors)
const _kEventPrimary = Color(0xFF7B2CBF);
const _kOnPrimary = Colors.white;

class PaiementPage extends StatefulWidget {
  /// On arrive ici SANS créer de réservation avant.
  /// On crée la réservation au moment du paiement puis on enregistre le paiement.
  final String billetId;
  final int quantite;
  final int prixUnitaireGNF;

  /// Pour le récap
  final String? eventTitle;
  final String? ticketTitle;

  const PaiementPage({
    super.key,
    required this.billetId,
    required this.quantite,
    required this.prixUnitaireGNF,
    this.eventTitle,
    this.ticketTitle,
  });

  @override
  State<PaiementPage> createState() => _PaiementPageState();
}

enum _PayKind { mobile, card }

class _PaiementPageState extends State<PaiementPage> {
  final _sb = Supabase.instance.client;
  final _svc = BilletterieService();

  bool _processing = false;
  _PayKind _kind = _PayKind.mobile;

  // Form mobile money
  final _phoneCtrl = TextEditingController();

  // Form carte
  final _cardHolderCtrl = TextEditingController();
  final _cardNumberCtrl = TextEditingController();
  final _cardExpiryCtrl = TextEditingController();
  final _cardCvcCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl
      ..text = ''
      ..dispose();
    _cardHolderCtrl.dispose();
    _cardNumberCtrl.dispose();
    _cardExpiryCtrl.dispose();
    _cardCvcCtrl.dispose();
    super.dispose();
  }

  int get _subtotal => widget.prixUnitaireGNF * widget.quantite;
  int get _fees => 0; // pas de frais pour l’instant
  int get _total => _subtotal + _fees;

  Future<void> _payer() async {
    if (_processing) return;

    // Validation minimale
    if (_kind == _PayKind.mobile && _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entre un numéro Mobile Money.')),
      );
      return;
    }

    setState(() => _processing = true);

    try {
      // 1) (Simulation) Appel passerelle (OM/PayTech/Stripe…)
      await Future.delayed(const Duration(milliseconds: 600));

      // 2) Créer la RÉSERVATION maintenant
      final reservationId = await _svc.reserverBillet(
        billetId: widget.billetId,
        quantite: widget.quantite,
      );

      // 3) Créer le PAIEMENT via la RPC "create_paiement_dynamic"
      // ENUMs DB : {cash, om, mtn, wave, carte}
      final String moyenText = (_kind == _PayKind.mobile) ? 'om' : 'carte';

      final data = await _sb.rpc(
        'create_paiement_dynamic',
        params: {
          'p_ride_id': reservationId, // reservations_billets.id
          'p_moyen_text': moyenText,  // 'om' ou 'carte'
          'p_amount_gnf': _total,
          // ne PAS envoyer p_provider_ref -> hash généré côté DB
        },
      ) as List;

      if (data.isEmpty) {
        throw Exception('Paiement non créé (réponse vide).');
      }

      if (!mounted) return;
      Navigator.pop(context, true); // succès → renvoie true à l’appelant

    } on PostgrestException catch (e) {
      if (!mounted) return;
      final msg = _friendlyError(e.message ?? e.toString());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      final msg = _friendlyError(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  String _friendlyError(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('22p02')) {
      return 'Moyen de paiement invalide. Choisis une option valide (om / carte).';
    }
    if (r.contains('42501') || r.contains('row level security')) {
      return 'Accès refusé (RLS). Connecte-toi et réessaie.';
    }
    if (r.contains('23503')) {
      return 'Réservation introuvable. Réessaie de réserver le billet.';
    }
    if (r.contains('digest') || r.contains('pgcrypto')) {
      return 'Erreur de signature interne. Réessaie dans un instant.';
    }
    return 'Erreur: $raw';
  }

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat.decimalPattern('fr_FR');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kEventPrimary,
        foregroundColor: _kOnPrimary,
        title: const Text('Paiement'),
      ),
      backgroundColor: const Color(0xFFF7F7F7),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ======================
            // Récap commande
            // ======================
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.eventTitle ?? 'Commande',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.ticketTitle ?? 'Billet sélectionné',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('x${widget.quantite}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Prix unitaire'),
                        Text('${nf.format(widget.prixUnitaireGNF)} GNF',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sous-total'),
                        Text('${nf.format(_subtotal)} GNF',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Frais'),
                        Text('${nf.format(_fees)} GNF',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: TextStyle(fontWeight: FontWeight.w900)),
                        Text('${nf.format(_total)} GNF',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ======================
            // Choix méthode (puces teintées)
            // ======================
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    selected: _kind == _PayKind.mobile,
                    label: const Text('Mobile Pay'),
                    selectedColor: _kEventPrimary.withOpacity(.20),
                    labelStyle: TextStyle(
                      color: _kind == _PayKind.mobile ? _kEventPrimary : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(color: _kEventPrimary.withOpacity(.35)),
                    onSelected: (_) => setState(() => _kind = _PayKind.mobile),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    selected: _kind == _PayKind.card,
                    label: const Text('Carte bancaire'),
                    selectedColor: _kEventPrimary.withOpacity(.20),
                    labelStyle: TextStyle(
                      color: _kind == _PayKind.card ? _kEventPrimary : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(color: _kEventPrimary.withOpacity(.35)),
                    onSelected: (_) => setState(() => _kind = _PayKind.card),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ======================
            // Formulaire selon méthode
            // ======================
            if (_kind == _PayKind.mobile)
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Numéro Mobile Money',
                      hintText: 'Ex: +224 6X XX XX XX',
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: _kEventPrimary),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: _kEventPrimary.withOpacity(.35)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              )
            else
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _cardHolderCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Titulaire de la carte',
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: _kEventPrimary),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: _kEventPrimary.withOpacity(.35)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _cardNumberCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Numéro de carte',
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: _kEventPrimary),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: _kEventPrimary.withOpacity(.35)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cardExpiryCtrl,
                              keyboardType: TextInputType.datetime,
                              decoration: InputDecoration(
                                labelText: 'MM/AA',
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: _kEventPrimary),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: _kEventPrimary.withOpacity(.35)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _cardCvcCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'CVC',
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: _kEventPrimary),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: _kEventPrimary.withOpacity(.35)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // ======================
            // Bouton Payer (couleur événement)
            // ======================
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _processing ? null : _payer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kEventPrimary,
                  foregroundColor: _kOnPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _processing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Payer ${nf.format(_total)} GNF'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
