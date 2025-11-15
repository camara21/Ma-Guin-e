import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'service_anp.dart';

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

  static const Color _bleuPrincipal = Color(0xFF0066FF);
  static const Color _bleuClair = Color(0xFFEAF3FF);
  static const Color _couleurTexte = Color(0xFF0D1724);

  Future<void> _finaliserCreation() async {
    if (!_accepteConditions) return;

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      // 🔗 Appel direct au service ANP (création / mise à jour en base)
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
            "Une erreur est survenue lors de la création de votre ANP. Réessayez.";
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _couleurTexte,
        title: const Text(
          "Créer mon ANP – Confirmation",
          style: TextStyle(
            color: _couleurTexte,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Étape 2 sur 2 : Confirmation & règles",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _couleurTexte,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Avant de finaliser votre Adresse Numérique Personnelle (ANP), "
                "merci de lire et d’accepter les règles suivantes :",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _bleuClair,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LigneRegleAnp(
                      texte:
                          "Une seule ANP par personne. Elle est liée à votre compte.",
                    ),
                    SizedBox(height: 8),
                    _LigneRegleAnp(
                      texte:
                          "Personne ne peut trouver votre ANP sans que vous lui donniez votre code.",
                    ),
                    SizedBox(height: 8),
                    _LigneRegleAnp(
                      texte:
                          "Pour venir chez vous, les gens devront entrer votre code ANP dans l’application.",
                    ),
                    SizedBox(height: 8),
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
                  color: _couleurTexte,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _bleuClair.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  "Latitude : ${pos.latitude.toStringAsFixed(5)}\n"
                  "Longitude : ${pos.longitude.toStringAsFixed(5)}",
                  style: const TextStyle(
                    color: _couleurTexte,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _accepteConditions,
                    activeColor: _bleuPrincipal,
                    onChanged: (v) {
                      setState(() {
                        _accepteConditions = v ?? false;
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      "J’accepte et je souhaite créer mon Adresse Numérique Personnelle (ANP) "
                      "avec ces règles.",
                      style: TextStyle(
                        fontSize: 14,
                        color: _couleurTexte,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (!_accepteConditions || _chargement)
                      ? null
                      : _finaliserCreation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _bleuPrincipal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    _chargement ? "Création de votre ANP..." : "Finaliser",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
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
        const Text(
          "• ",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            texte,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
