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

  Position? _position; // position qui sera envoyée à la suite (ANP)
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

  static const Color _bleuPrincipal = Color(0xFF0066FF);
  static const Color _bleuClair = Color(0xFFEAF3FF);
  static const Color _couleurTexte = Color(0xFF0D1724);

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

  // Interprétation de la précision GPS
  void _evaluerPrecision(Position pos) {
    final acc = pos.accuracy; // en mètres
    _precisionMetres = acc;

    if (acc <= 20) {
      _messagePrecision =
          "Localisation très précise (≈ ${acc.toStringAsFixed(0)} m).";
      _precisionSuffisante = true;
    } else if (acc <= 50) {
      _messagePrecision =
          "Localisation correcte (≈ ${acc.toStringAsFixed(0)} m). "
          "Vous pouvez affiner en déplaçant le point rouge sur la carte.";
      _precisionSuffisante = true;
    } else {
      _messagePrecision =
          "Localisation approximative (≈ ${acc.toStringAsFixed(0)} m). "
          "Si possible, placez-vous à l’extérieur ou près d’une fenêtre, "
          "puis relancez la localisation.";
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
      final pos = await _serviceLocalisation.recupererPositionActuelle();
      final enGuinee = _serviceLocalisation.estEnGuinee(pos);

      _evaluerPrecision(pos);

      setState(() {
        _position = pos;
        _pointSelectionne = LatLng(pos.latitude, pos.longitude);
        _estHorsGuinee = !enGuinee;
      });
    } on ExceptionLocalisationAnp catch (e) {
      setState(() {
        _erreur = e.message;
      });
    } catch (_) {
      setState(() {
        _erreur = "Impossible de récupérer votre position.\n\n"
            "Vérifiez que la localisation est activée, que Soneya a l’autorisation "
            "d’utiliser le GPS et que vous disposez d’une connexion Internet.";
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
          "Merci de mettre à jour votre nom, e-mail ou numéro de téléphone "
          "dans votre profil Soneya avant d’enregistrer votre ANP.";
    });

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Mettre à jour vos informations"),
          content: const Text(
            "Ces informations proviennent de votre profil Soneya.\n\n"
            "Pour les modifier, retournez sur votre profil, mettez-les à jour "
            "puis revenez sur la page ANP.",
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
    // ❗ On ne bouge PAS la carte ici, seulement le marqueur
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

  @override
  Widget build(BuildContext context) {
    final lat = _pointSelectionne?.latitude ?? _position?.latitude;
    final lng = _pointSelectionne?.longitude ?? _position?.longitude;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _couleurTexte,
        title: const Text(
          "Mon ANP – Localisation",
          style: TextStyle(
            color: _couleurTexte,
            fontWeight: FontWeight.w600,
          ),
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
                    // ────────────── Infos utilisateur ──────────────
                    const Text(
                      "Vos informations",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _couleurTexte,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Nous utilisons les informations de votre profil Soneya. "
                      "Confirmez qu’elles sont correctes avant d’enregistrer votre ANP.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _prenomController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: "Prénom",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _nomController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: "Nom",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: "E-mail",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _telephoneController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: "Numéro de téléphone",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
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
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _infosIncorrectes,
                            child: const Text(
                              "Non",
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600,
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

                    const SizedBox(height: 24),

                    // ────────────── Localisation ──────────────
                    const Text(
                      "Étape 1 sur 2 : Localisation précise",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _couleurTexte,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Votre Adresse Numérique Personnelle (ANP) est basée sur votre "
                      "position exacte. Utilisez d’abord la localisation de votre téléphone, "
                      "puis ajustez le point rouge sur la carte (classique ou satellite) si nécessaire.",
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bouton "Utiliser ma position actuelle"
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.my_location),
                        onPressed:
                            _chargement ? null : _utiliserPositionActuelle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _bleuClair,
                          foregroundColor: _couleurTexte,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        label: _chargement
                            ? const Text("Localisation en cours…")
                            : const Text("Utiliser ma position actuelle"),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_erreur != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
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
                      const SizedBox(height: 8),
                      const Text(
                        "Si le problème persiste, redémarrez la localisation ou votre téléphone.",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "Vous ne vous trouvez pas en Guinée.\n"
                            "Ce service n’est pas disponible à l’international pour le moment.\n"
                            "Pour les tests, l’enregistrement reste possible, mais en production "
                            "vous devrez vous trouver sur le territoire guinéen.",
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Aperçu de votre position",
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
                        "Touchez la carte pour placer le point rouge exactement à l’endroit de votre ANP (porte, portail, entrée du bâtiment…).",
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Carte avec marker + sélection manuelle
                      Container(
                        height: 220,
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
                              initialZoom: 17,
                              minZoom: 3,
                              maxZoom: 18, // évite l’écran gris
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
                                    width: 40,
                                    height: 40,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.red, // point rouge
                                      size: 40,
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

                      const SizedBox(height: 8),
                      Text(
                        "Lat : ${lat.toStringAsFixed(5)}   "
                        "Lng : ${lng.toStringAsFixed(5)}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _couleurTexte,
                          fontSize: 13,
                        ),
                      ),
                      if (_precisionMetres != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _messagePrecision ?? '',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _precisionSuffisante
                                ? Colors.green[700]
                                : Colors.orange[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (!_precisionSuffisante &&
                          _precisionMetres != null) ...[
                        const SizedBox(height: 4),
                        const Text(
                          "La localisation est trop approximative pour enregistrer votre ANP. "
                          "Merci de relancer la localisation ou d’ajuster le point sur la carte.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      const Text(
                        "(La position provient du GPS puis de votre ajustement sur la carte.)",
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
                    backgroundColor: _bleuPrincipal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    "Continuer",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
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

// petit objet pour renvoyer point + mode carte/satellite
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
  static const Color _bleuPrincipal = Color(0xFF0066FF);

  late LatLng _point;
  final MapController _mapController = MapController();
  late bool _modeSatellite;

  @override
  void initState() {
    super.initState();
    _point = widget.pointInitial;
    _modeSatellite = widget.modeSatelliteInitial;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(_point, 17);
    });
  }

  void _onTap(TapPosition tapPosition, LatLng latLng) {
    setState(() {
      _point = latLng;
      // ❗ ICI ON NE BOUGE PLUS LA CARTE :
      // on ne fait plus _mapController.move(latLng, 17);
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
      appBar: AppBar(
        title: const Text("Ajuster ma position ANP"),
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
              "Touchez la carte pour placer le point rouge exactement "
              "sur votre porte, portail ou entrée de bâtiment.",
              style: TextStyle(fontSize: 14),
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _point,
                initialZoom: 17,
                minZoom: 3,
                maxZoom: 18, // on reste dans une zone nette
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
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 42,
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
                  child: const Text(
                    "Valider cette position",
                    style: TextStyle(fontWeight: FontWeight.w600),
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
