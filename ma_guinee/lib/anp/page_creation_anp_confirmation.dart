// lib/anp/page_creation_anp_confirmation.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'service_anp.dart';

/// Palette ANP (partagée entre les pages)
const Color kAnpBleuPrincipal = Color(0xFF0066FF);
const Color kAnpBleuClair = Color(0xFFEAF3FF);
const Color kAnpCouleurTexte = Color(0xFF0D1724);
const Color kAnpFondPrincipal = Color(0xFFF2F4F8);
const Color kAnpAccentSoft = Color(0xFFEDF2FF);

class PageCreationAnpConfirmation extends StatefulWidget {
  final Position position;

  /// Permet d'autoriser (ou non) la création d'ANP hors Guinée.
  /// - En PROD : laisse false (par défaut).
  /// - En mode TEST : tu peux passer true depuis la page de localisation.
  final bool autoriserHorsGuineePourTests;

  const PageCreationAnpConfirmation({
    super.key,
    required this.position,
    this.autoriserHorsGuineePourTests = false,
  });

  @override
  State<PageCreationAnpConfirmation> createState() =>
      _PageCreationAnpConfirmationState();
}

class _PageCreationAnpConfirmationState
    extends State<PageCreationAnpConfirmation> {
  final ServiceAnp _serviceAnp = ServiceAnp();

  bool _accepteConditions = false;
  bool _chargement = false;
  String? _erreur;

  Future<void> _finaliserCreation() async {
    if (!_accepteConditions) return;

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      // Appel direct au service ANP (création / mise à jour en base)
      final code = await _serviceAnp.creerOuMettreAJourAnp(
        position: widget.position,
        autoriserHorsGuineePourTests: widget.autoriserHorsGuineePourTests,
      );

      if (!mounted) return;

      // On renvoie le code ANP à l’écran précédent (localisation)
      Navigator.of(context).pop<String>(code);
    } on ExceptionAnp catch (e) {
      setState(() {
        _erreur = e.message;
      });
    } catch (_) {
      setState(() {
        _erreur =
            "Une erreur technique est survenue lors de l’enregistrement de votre ANP.\n\n"
            "Vérifiez votre connexion Internet et réessayez. "
            "Si le problème persiste, réessayez plus tard.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _chargement = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.position;

    return Scaffold(
      backgroundColor: kAnpFondPrincipal,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: kAnpCouleurTexte,
        centerTitle: true,
        title: Column(
          children: const [
            Text(
              "Mon ANP – Confirmation",
              style: TextStyle(
                color: kAnpCouleurTexte,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 3),
            Text(
              "Étape 2 / 2 • Validation",
              style: TextStyle(
                color: Colors.black45,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              // Contenu scrollable
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Carte en-tête moderne
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: kAnpBleuClair,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.verified_user,
                                color: kAnpBleuPrincipal,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Étape 2 sur 2 : Confirmation & règles",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: kAnpCouleurTexte,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    "Avant d’enregistrer ou de mettre à jour votre Adresse Numérique Personnelle (ANP), "
                                    "merci de lire et d’accepter les règles suivantes.",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                      height: 1.32,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Bloc règles
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: kAnpAccentSoft,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LigneRegleAnp(
                              texte:
                                  "Une seule ANP par personne. Elle est liée à votre compte.",
                            ),
                            SizedBox(height: 10),
                            _LigneRegleAnp(
                              texte:
                                  "Personne ne peut trouver votre ANP sans que vous lui donniez votre code.",
                            ),
                            SizedBox(height: 10),
                            _LigneRegleAnp(
                              texte:
                                  "Pour venir chez vous, les gens devront entrer votre code ANP dans l’application.",
                            ),
                            SizedBox(height: 10),
                            _LigneRegleAnp(
                              texte:
                                  "Votre position pourra être mise à jour, mais votre code ANP restera le même.",
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        "Position utilisée pour votre ANP",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: kAnpCouleurTexte,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: kAnpBleuClair.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: kAnpBleuPrincipal,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Latitude : ${pos.latitude.toStringAsFixed(5)}\n"
                                "Longitude : ${pos.longitude.toStringAsFixed(5)}",
                                style: const TextStyle(
                                  color: kAnpCouleurTexte,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Checkbox conditions
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _accepteConditions,
                            activeColor: kAnpBleuPrincipal,
                            onChanged: (v) {
                              setState(() {
                                _accepteConditions = v ?? false;
                              });
                            },
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              "J’accepte et je souhaite enregistrer (ou mettre à jour) mon Adresse Numérique Personnelle (ANP) "
                              "avec ces règles.",
                              style: TextStyle(
                                fontSize: 14,
                                color: kAnpCouleurTexte,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (_erreur != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _erreur!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bouton bas de page
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (!_accepteConditions || _chargement)
                      ? null
                      : _finaliserCreation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAnpBleuPrincipal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    _chargement
                        ? "Enregistrement de votre ANP…"
                        : "Enregistrer mon ANP",
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LigneRegleAnp extends StatelessWidget {
  final String texte;
  const _LigneRegleAnp({required this.texte});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 3),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: kAnpBleuPrincipal,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texte,
            style: const TextStyle(
              color: kAnpCouleurTexte,
              fontSize: 14,
              height: 1.32,
            ),
          ),
        ),
      ],
    );
  }
}
