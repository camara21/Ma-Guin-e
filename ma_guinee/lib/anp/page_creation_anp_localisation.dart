// lib/anp/page_creation_anp_localisation.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/utilisateur_model.dart';
import '../providers/user_provider.dart';

import 'service_localisation_anp.dart';
import 'page_creation_anp_confirmation.dart'; // Étape 2

class PageCreationAnpLocalisation extends StatefulWidget {
  const PageCreationAnpLocalisation({super.key});

  @override
  State<PageCreationAnpLocalisation> createState() =>
      _PageCreationAnpLocalisationState();
}

class _PageCreationAnpLocalisationState
    extends State<PageCreationAnpLocalisation> {
  // Service de localisation ANP
  final ServiceLocalisationAnp _serviceLocalisation = ServiceLocalisationAnp();

  Position? _position; // position fusionnée qui sera envoyée à la suite (ANP)
  LatLng? _pointSelectionne; // point choisi à la main sur la carte

  bool _chargement = false;
  String? _erreur;
  bool _estHorsGuinee = false;

  // Précision GPS
  double? _precisionMetres;
  bool _precisionSuffisante = false;
  String? _messagePrecision;

  // Profil utilisateur
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  bool _infosChargeesDepuisProfil = false;
  bool _infosConfirmees = false;
  String? _erreurInfos;

  // Mode d’affichage : true = satellite, false = carte classique
  bool _modeSatellite = true;

  // Palette ANP (même que la page Mon ANP)
  static const Color _bleuPrincipal = Color(0xFF0066FF);
  static const Color _bleuClair = Color(0xFFEAF3FF);
  static const Color _couleurTexte = Color(0xFF0D1724);
  static const Color _fondPrincipal = Color(0xFFF2F4F8);
  static const Color _accentSoft = Color(0xFFEDF2FF);
  static const Color _carteFond = Colors.white;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_infosChargeesDepuisProfil) {
      final prov = context.read<UserProvider>();
      final UtilisateurModel? user = prov.utilisateur;

      if (user != null) {
        _prenomController.text = user.prenom ?? '';
        _nomController.text = user.nom ?? '';
        _emailController.text = user.email ?? '';
        _telephoneController.text = user.telephone ?? '';
      }
      _infosChargeesDepuisProfil = true;
    }
  }

  @override
  void dispose() {
    _prenomController.dispose();
    _nomController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  // ─────────────────────────────
  //  FUSION DE MESURES (pseudo "trilatération")
  // ─────────────────────────────

  /// On effectue plusieurs mesures GPS très précises,
  /// puis on fusionne pour stabiliser la position finale.
  Future<Position> _acquerirPositionFusionnee() async {
    const int nombreMesures = 3;
    final List<Position> mesures = [];

    for (int i = 0; i < nombreMesures; i++) {
      final p = await _serviceLocalisation.recupererPositionActuelle();
      mesures.add(p);

      // petite pause entre deux mesures pour laisser le GPS se recalibrer
      if (i < nombreMesures - 1) {
        await Future.delayed(const Duration(milliseconds: 350));
      }
    }

    if (mesures.length == 1) return mesures.first;

    final double avgLat =
        mesures.map((m) => m.latitude).reduce((a, b) => a + b) / mesures.length;
    final double avgLng =
        mesures.map((m) => m.longitude).reduce((a, b) => a + b) /
            mesures.length;
    final double avgAlt =
        mesures.map((m) => m.altitude).reduce((a, b) => a + b) / mesures.length;
    final double bestAcc =
        mesures.map((m) => m.accuracy).reduce(math.min); // meilleure précision

    final base = mesures.first;

    return Position(
      latitude: avgLat,
      longitude: avgLng,
      timestamp: DateTime.now(),
      accuracy: bestAcc,
      altitude: avgAlt,
      altitudeAccuracy: base.altitudeAccuracy,
      heading: base.heading,
      headingAccuracy: base.headingAccuracy,
      speed: base.speed,
      speedAccuracy: base.speedAccuracy,
      floor: base.floor,
      isMocked: base.isMocked,
    );
  }

  // Interprétation de la précision GPS
  void _evaluerPrecision(Position pos) {
    final acc = pos.accuracy; // en mètres
    _precisionMetres = acc;

    if (acc <= 10) {
      _messagePrecision =
          "Précision fine (≈ ${acc.toStringAsFixed(0)} m). Parfait pour votre ANP.";
      _precisionSuffisante = true;
    } else if (acc <= 25) {
      _messagePrecision =
          "Précision correcte (≈ ${acc.toStringAsFixed(0)} m). Ajustez le point si besoin.";
      _precisionSuffisante = true;
    } else {
      _messagePrecision =
          "Précision faible (≈ ${acc.toStringAsFixed(0)} m). Réessayez si possible près d’une fenêtre ou à l’extérieur.";
      _precisionSuffisante = false;
    }
  }

  Future<void> _utiliserPositionActuelle() async {
    setState(() {
      _chargement = true;
      _erreur = null;
      _estHorsGuinee = false;
      _precisionMetres = null;
      _messagePrecision = null;
      _precisionSuffisante = false;
    });

    try {
      // 🔵 Multi-mesures fusionnées (pseudo trilatération)
      final posFusionnee = await _acquerirPositionFusionnee();
      final enGuinee = _serviceLocalisation.estEnGuinee(posFusionnee);

      _evaluerPrecision(posFusionnee);

      setState(() {
        _position = posFusionnee;
        _pointSelectionne =
            LatLng(posFusionnee.latitude, posFusionnee.longitude);
        _estHorsGuinee = !enGuinee;
      });
    } on ExceptionLocalisationAnp catch (e) {
      setState(() {
        _erreur = e.message;
      });
    } catch (_) {
      setState(() {
        _erreur = "Impossible de récupérer votre position.\n\n"
            "Vérifiez la localisation, les autorisations GPS et votre connexion Internet.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _chargement = false;
        });
      }
    }
  }

  Future<void> _validerEtContinuer() async {
    if (_position == null || !_infosConfirmees || !_precisionSuffisante) {
      return;
    }

    // Étape 2 : Confirmation + création / mise à jour ANP
    final codeAnp = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => PageCreationAnpConfirmation(
          position: _position!,
          autoriserHorsGuineePourTests: _estHorsGuinee,
        ),
      ),
    );

    if (!mounted) return;

    if (codeAnp != null) {
      Navigator.of(context).pop<String>(codeAnp);
    }
  }

  void _confirmerInfos() {
    setState(() {
      _infosConfirmees = true;
      _erreurInfos = null;
    });
  }

  void _infosIncorrectes() {
    setState(() {
      _infosConfirmees = false;
      _erreurInfos =
          "Mettez à jour votre nom, e-mail ou téléphone dans votre profil Soneya, puis revenez ici.";
    });

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Mettre à jour vos informations"),
          content: const Text(
            "Ces données proviennent de votre profil Soneya.\n\n"
            "Modifiez-les depuis votre profil, puis revenez sur la page ANP.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  bool get _peutContinuer =>
      _position != null &&
      !_chargement &&
      _infosConfirmees &&
      _precisionSuffisante;

  /// Mise à jour du point sélectionné (utilisé par la carte normale et la plein écran)
  void _mettreAJourPoint(LatLng latLng) {
    if (_position == null) return;

    setState(() {
      _pointSelectionne = latLng;

      _position = Position(
        latitude: latLng.latitude,
        longitude: latLng.longitude,
        timestamp: DateTime.now(),
        accuracy: _position!.accuracy,
        altitude: _position!.altitude,
        altitudeAccuracy: _position!.altitudeAccuracy,
        heading: _position!.heading,
        headingAccuracy: _position!.headingAccuracy,
        speed: _position!.speed,
        speedAccuracy: _position!.speedAccuracy,
        floor: _position!.floor,
        isMocked: _position!.isMocked,
      );

      // Dès qu’on ajuste à la main, on considère la précision comme OK
      _precisionSuffisante = true;
    });
  }

  /// Quand l’utilisateur tape sur la carte pour choisir la position exacte
  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    _mettreAJourPoint(latLng);
  }

  /// Ouvre une carte satellite / classique en plein écran pour ajuster précisément le point
  Future<void> _ouvrirCartePleine() async {
    if (_position == null && _pointSelectionne == null) return;

    final lat = _pointSelectionne?.latitude ?? _position!.latitude;
    final lng = _pointSelectionne?.longitude ?? _position!.longitude;

    final LatLng pointInitial = LatLng(lat, lng);

    final _ResultCartePleine? resultat =
        await Navigator.of(context).push<_ResultCartePleine>(
      MaterialPageRoute(
        builder: (_) => _PageAnpCartePleine(
          pointInitial: pointInitial,
          modeSatelliteInitial: _modeSatellite,
        ),
        fullscreenDialog: true,
      ),
    );

    if (resultat != null) {
      _mettreAJourPoint(resultat.point);
      setState(() {
        _modeSatellite = resultat.modeSatellite;
      });
    }
  }

  Widget _buildToggleCarteSatellite() {
    final bool sat = _modeSatellite;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bouton CARTE
          GestureDetector(
            onTap: () {
              setState(() => _modeSatellite = false);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sat ? Colors.transparent : Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                "Carte",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sat ? _couleurTexte : _bleuPrincipal,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Bouton SATELLITE
          GestureDetector(
            onTap: () {
              setState(() => _modeSatellite = true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sat ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                "Satellite",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sat ? _bleuPrincipal : _couleurTexte,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────
  //  UI
  // ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lat = _pointSelectionne?.latitude ?? _position?.latitude;
    final lng = _pointSelectionne?.longitude ?? _position?.longitude;
    final size = MediaQuery.of(context).size;
    final double carteHeight = size.height * 0.30;
    final double carteMin = 200;
    final double carteMax = 280;
    final double carteFinalHeight =
        math.max(carteMin, math.min(carteMax, carteHeight));

    return Scaffold(
      backgroundColor: _fondPrincipal,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _couleurTexte,
        centerTitle: true,
        title: Column(
          children: const [
            Text(
              "Mon ANP – Localisation",
              style: TextStyle(
                color: _couleurTexte,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 3),
            Text(
              "Étape 1 / 2 • Position exacte",
              style: TextStyle(
                color: Colors.black45,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Contenu scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ────────────── Carte profil compacte ──────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _carteFond,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _accentSoft,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.person_pin_circle,
                                  color: _bleuPrincipal,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  "Profil ANP",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _couleurTexte,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _bleuClair,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  "Depuis votre profil",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _bleuPrincipal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _prenomController,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: "Prénom",
                                    isDense: true,
                                    filled: true,
                                    fillColor: Color(0xFFF5F7FA),
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.transparent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _nomController,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: "Nom",
                                    isDense: true,
                                    filled: true,
                                    fillColor: Color(0xFFF5F7FA),
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.transparent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _emailController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: "E-mail",
                              isDense: true,
                              filled: true,
                              fillColor: Color(0xFFF5F7FA),
                              border: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.transparent),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _telephoneController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: "Téléphone",
                              isDense: true,
                              filled: true,
                              fillColor: Color(0xFFF5F7FA),
                              border: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.transparent),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    "Ces informations sont-elles correctes ?",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _couleurTexte,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _confirmerInfos,
                                  child: Text(
                                    "Oui",
                                    style: TextStyle(
                                      color: _infosConfirmees
                                          ? _bleuPrincipal
                                          : _couleurTexte,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _infosIncorrectes,
                                  child: const Text(
                                    "Non",
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_erreurInfos != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _erreurInfos!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ────────────── Bloc localisation & bouton GPS ──────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _carteFond,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _bleuClair,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.my_location,
                                  color: _bleuPrincipal,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  "Localiser votre ANP",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: _couleurTexte,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _accentSoft,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  "Étape 1/2",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _bleuPrincipal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "On récupère votre position, puis vous ajustez le point sur la carte.",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: _chargement
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.gps_fixed),
                              onPressed: _chargement
                                  ? null
                                  : _utiliserPositionActuelle,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _bleuPrincipal,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              label: Text(
                                _chargement
                                    ? "Analyse de la position…"
                                    : "Détecter ma position exacte",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          if (_erreur != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 10,
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
                          if (_precisionMetres != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  _precisionSuffisante
                                      ? Icons.verified
                                      : Icons.warning_amber_rounded,
                                  size: 18,
                                  color: _precisionSuffisante
                                      ? Colors.green[700]
                                      : Colors.orange[700],
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _messagePrecision ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _precisionSuffisante
                                          ? Colors.green[700]
                                          : Colors.orange[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (_position != null && lat != null && lng != null) ...[
                      if (_estHorsGuinee)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            "Vous semblez en dehors de la Guinée. En tests, l’ANP peut être enregistrée, "
                            "mais en production il faudra être sur le territoire guinéen.",
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Ajuster le point ANP",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _couleurTexte,
                            ),
                          ),
                          _buildToggleCarteSatellite(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Touchez la carte pour placer le point sur votre porte ou portail.",
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Carte avec marker + sélection manuelle
                      Container(
                        height: carteFinalHeight,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(lat, lng),
                              initialZoom: 18,
                              minZoom: 3,
                              maxZoom: 19,
                              onTap: _onMapTap,
                            ),
                            children: [
                              if (_modeSatellite)
                                TileLayer(
                                  urlTemplate:
                                      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                                  userAgentPackageName: 'ma.guinee.anp',
                                  maxNativeZoom: 18,
                                )
                              else
                                TileLayer(
                                  urlTemplate:
                                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  subdomains: const ['a', 'b', 'c'],
                                  userAgentPackageName: 'ma.guinee.anp',
                                  maxNativeZoom: 19,
                                ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(lat, lng),
                                    width: 52,
                                    height: 52,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.25),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.location_on,
                                        color: Colors.red,
                                        size: 36,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Bouton pour passer en plein écran
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          onPressed: _ouvrirCartePleine,
                          icon: const Icon(Icons.fullscreen),
                          label: const Text("Ajuster sur grande carte"),
                        ),
                      ),

                      const SizedBox(height: 4),
                      Text(
                        "Lat : ${lat.toStringAsFixed(5)}   •   Lng : ${lng.toStringAsFixed(5)}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _couleurTexte,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "La position combine le GPS + vos ajustements sur la carte.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bouton CONTINUER collé en bas
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _peutContinuer ? _validerEtContinuer : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _peutContinuer
                        ? _bleuPrincipal
                        : _bleuPrincipal.withOpacity(0.4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    "Continuer",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────
//  Objet de retour pour la carte plein écran
// ─────────────────────────────

class _ResultCartePleine {
  final LatLng point;
  final bool modeSatellite;
  _ResultCartePleine(this.point, this.modeSatellite);
}

/// Page interne pour l’ajustement en plein écran
class _PageAnpCartePleine extends StatefulWidget {
  final LatLng pointInitial;
  final bool modeSatelliteInitial;

  const _PageAnpCartePleine({
    super.key,
    required this.pointInitial,
    required this.modeSatelliteInitial,
  });

  @override
  State<_PageAnpCartePleine> createState() => _PageAnpCartePleineState();
}

class _PageAnpCartePleineState extends State<_PageAnpCartePleine> {
  // Palette locale (mêmes couleurs que la page principale)
  static const Color _bleuPrincipal = Color(0xFF0066FF);
  static const Color _fondPrincipal = Color(0xFFF2F4F8);
  static const Color _couleurTexte = Color(0xFF0D1724);

  late LatLng _point;
  final MapController _mapController = MapController();
  late bool _modeSatellite;

  @override
  void initState() {
    super.initState();
    _point = widget.pointInitial;
    _modeSatellite = widget.modeSatelliteInitial;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(_point, 18);
    });
  }

  void _onTap(TapPosition tapPosition, LatLng latLng) {
    setState(() {
      _point = latLng;
      // On ne déplace pas la caméra, on ne fait que déplacer le marqueur
    });
  }

  void _valider() {
    Navigator.of(context).pop<_ResultCartePleine>(
      _ResultCartePleine(_point, _modeSatellite),
    );
  }

  Widget _buildToggleCarteSatellite() {
    final bool sat = _modeSatellite;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              setState(() => _modeSatellite = false);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sat ? Colors.transparent : Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                "Carte",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sat ? Colors.black87 : _bleuPrincipal,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              setState(() => _modeSatellite = true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sat ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                "Satellite",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sat ? _bleuPrincipal : Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondPrincipal,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _couleurTexte,
        title: const Text(
          "Ajuster ma position ANP",
          style: TextStyle(
            color: _couleurTexte,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: _buildToggleCarteSatellite(),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              "Touchez la carte pour placer le point sur votre porte ou votre portail.",
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _point,
                initialZoom: 18,
                minZoom: 3,
                maxZoom: 19,
                onTap: _onTap,
              ),
              children: [
                if (_modeSatellite)
                  TileLayer(
                    urlTemplate:
                        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                    userAgentPackageName: 'ma.guinee.anp',
                    maxNativeZoom: 18,
                  )
                else
                  TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'ma.guinee.anp',
                    maxNativeZoom: 19,
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _point,
                      width: 52,
                      height: 52,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 38,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _valider,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _bleuPrincipal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: const Text(
                    "Valider cette position",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
