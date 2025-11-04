// lib/pages/billetterie/paiement_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart';
import '../../services/billetterie_service.dart';

// Palette directe (pas de ServiceColors)
const _kEventPrimary = Color(0xFF7B2CBF);
const _kOnPrimary = Colors.white;

// 🔒 Interrupteur global pour bloquer les paiements
const bool kPaymentsTemporarilyDisabled = true;

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

  /// Référence externe lisible générée côté app (pas besoin de package)
  String _makeProviderRef() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rnd = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'SNY-$ts-$rnd';
  }

  Future<void> _payer() async {
    if (_processing) return;

    // Garde-fou supplémentaire (même si le bouton est désactivé)
    if (kPaymentsTemporarilyDisabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "L’achat des billets sera disponible dans les plus brefs délais. Merci de votre patience.",
          ),
        ),
      );
      return;
    }

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

      // 3) Créer le PAIEMENT via la RPC "create_paiement_dynamic" (4 params)
      final String moyenText = (_kind == _PayKind.mobile) ? 'om' : 'carte';
      final String providerRef = _makeProviderRef();

      final res = await _sb.rpc(
        'create_paiement_dynamic',
        params: {
          'p_ride_id': reservationId, // reservations_billets.id
          'p_moyen_text': moyenText,  // 'om' / 'carte' / 'mtn' / 'wave' / 'cash'
          'p_amount_gnf': _total,
          'p_provider_ref': providerRef, // généré côté app
        },
      );

      final ok = (res != null) && !((res is List) && res.isEmpty);
      if (!ok) {
        throw Exception('Paiement non créé (réponse vide).');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paiement réussi ✅')),
      );
      Navigator.pop(context, true);
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
    return 'Erreur: $raw';
  }

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat.decimalPattern('fr_FR');
    final bool disabled = kPaymentsTemporarilyDisabled;

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

                    // Ligne "Frais"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Frais'),
                        Text('${nf.format(_fees)} GNF',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // 🟠 Message d’info placé à l’endroit des "frais"
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFD699)),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "L’achat des billets sera disponible dans les plus brefs délais. "
                              "Merci de votre patience.",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
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
            // Formulaire selon méthode (désactivé si payments off)
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
                    enabled: !disabled,
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
                        enabled: !disabled,
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
                        enabled: !disabled,
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
                              enabled: !disabled,
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
                              enabled: !disabled,
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
            // Bouton Payer (désactivé + grisé)
            // ======================
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (disabled || _processing) ? null : _payer,
                style: ButtonStyle(
                  padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 14)),
                  shape: MaterialStateProperty.all(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.disabled)) {
                      return Colors.grey.shade400; // gris quand désactivé
                    }
                    return _kEventPrimary;
                  }),
                  foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.disabled)) {
                      return Colors.white70;
                    }
                    return _kOnPrimary;
                  }),
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
