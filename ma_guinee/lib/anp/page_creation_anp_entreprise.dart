// lib/anp/page_creation_anp_entreprise.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'service_anp_entreprise.dart';

class PageCreationAnpEntreprise extends StatefulWidget {
  /// Si null => on crée l'entreprise + le site principal
  /// Si non null => on ajoute une adresse pour cette entreprise
  final String? entrepriseId;
  final String? nomEntreprise;

  const PageCreationAnpEntreprise({
    super.key,
    this.entrepriseId,
    this.nomEntreprise,
  });

  @override
  State<PageCreationAnpEntreprise> createState() =>
      _PageCreationAnpEntrepriseState();
}

class _PageCreationAnpEntrepriseState extends State<PageCreationAnpEntreprise> {
  final _formKey = GlobalKey<FormState>();
  final _service = ServiceAnpEntreprise();

  bool get _modeAjoutAdresse => widget.entrepriseId != null;

  // Palette ANP
  static const Color _bleuPrincipal = Color(0xFF0066FF);
  static const Color _bleuClair = Color(0xFFEAF3FF);
  static const Color _couleurTexte = Color(0xFF0D1724);

  // ---------- Champs entreprise ----------
  final TextEditingController _nomCtrl = TextEditingController();
  final TextEditingController _secteurCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _telCtrl = TextEditingController();
  final TextEditingController _siteWebCtrl = TextEditingController();

  // ---------- Champs site ----------
  final TextEditingController _nomSiteCtrl =
      TextEditingController(text: "Siège principal");
  final TextEditingController _typeSiteCtrl =
      TextEditingController(text: "agence");

  Position? _position; // position enregistrée
  LatLng? _selectedPoint; // point choisi sur la carte (marker)

  bool _loading = false;
  String? _erreur;

  // centre par défaut sur Conakry
  LatLng _mapCenter = LatLng(9.6412, -13.5784);
  double _mapZoom = 6;

  // 👉 CONTROLEUR DE CARTE POUR POUVOIR LA BOUGER / ZOOMER
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();

    if (_modeAjoutAdresse && widget.nomEntreprise != null) {
      // Mode ajout d'adresse : on affiche juste le nom en lecture seule
      _nomCtrl.text = widget.nomEntreprise!;
    }
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _secteurCtrl.dispose();
    _emailCtrl.dispose();
    _telCtrl.dispose();
    _siteWebCtrl.dispose();
    _nomSiteCtrl.dispose();
    _typeSiteCtrl.dispose();
    super.dispose();
  }

  // ============================
  //   GESTION LOCALISATION
  // ============================
  Future<void> _choisirLocalisation() async {
    setState(() {
      _erreur = null;
      _loading = true;
    });

    try {
      // ❗ Localisation seulement sur mobile
      if (kIsWeb) {
        throw Exception(
          "La localisation GPS est disponible uniquement sur l’application mobile Soneya.\n"
          "Veuillez créer ou modifier cette adresse depuis votre téléphone.",
        );
      }

      // Vérifier si le GPS est activé
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception("Activez la localisation sur votre téléphone.");
      }

      // Vérifier les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        throw Exception(
          "Permission de localisation refusée.\n"
          "Merci de l’autoriser dans les paramètres.",
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final point = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _position = pos;
        _selectedPoint = point;
        _mapCenter = point;
        _mapZoom = 16;
      });

      // 👉 on centre / zoome la carte sur la position GPS
      _mapController.move(point, 16);
    } catch (e) {
      setState(() {
        _erreur = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// Quand on tape sur la carte, on déplace le marqueur sur la position exacte
  void _onMapTap(TapPosition tapPos, LatLng latLng) {
    setState(() {
      _selectedPoint = latLng;
      _mapCenter = latLng;
      _mapZoom = 16;

      // On met aussi à jour la Position qui sera envoyée au backend
      _position = Position(
        latitude: latLng.latitude,
        longitude: latLng.longitude,
        timestamp: DateTime.now(),
        accuracy: _position?.accuracy ?? 0,
        altitude: _position?.altitude ?? 0,
        heading: _position?.heading ?? 0,
        speed: _position?.speed ?? 0,
        speedAccuracy: _position?.speedAccuracy ?? 0,
        altitudeAccuracy: _position?.altitudeAccuracy ?? 0,
        headingAccuracy: _position?.headingAccuracy ?? 0,
      );
    });

    // 👉 on centre / zoome la carte sur le point cliqué
    _mapController.move(latLng, 16);
  }

  // ============================
  //   SOUMISSION FORMULAIRE
  // ============================
  Future<void> _soumettre() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_position == null || _selectedPoint == null) {
      setState(() {
        _erreur =
            "Veuillez choisir la localisation exacte sur la carte (point rouge).";
      });
      return;
    }

    setState(() {
      _loading = true;
      _erreur = null;
    });

    try {
      Map<String, dynamic>? entreprise;
      Map<String, dynamic> site;

      if (_modeAjoutAdresse) {
        // ========================
        //  MODE : AJOUT D'ADRESSE
        // ========================
        final entrepriseId = widget.entrepriseId!;
        site = await _service.creerSiteSecondaire(
          entrepriseId: entrepriseId,
          position: _position!,
          nomSite: _nomSiteCtrl.text.trim().isEmpty
              ? "Agence"
              : _nomSiteCtrl.text.trim(),
          typeSite: _typeSiteCtrl.text.trim().isEmpty
              ? "agence"
              : _typeSiteCtrl.text.trim(),
        );
      } else {
        // ========================
        //  MODE : CREATION COMPLETE
        // ========================

        // 1) Créer l'entreprise
        entreprise = await _service.creerOuMettreAJourEntreprise(
          nom: _nomCtrl.text.trim(),
          secteur: _secteurCtrl.text.trim().isEmpty
              ? null
              : _secteurCtrl.text.trim(),
          contactEmail:
              _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          contactTelephone:
              _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
          siteWeb: _siteWebCtrl.text.trim().isEmpty
              ? null
              : _siteWebCtrl.text.trim(),
        );

        final entrepriseId = entreprise['id'] as String;

        // 2) Créer / mettre à jour le site principal
        site = await _service.creerOuMettreAJourSitePrincipal(
          entrepriseId: entrepriseId,
          position: _position!,
          nomSite: _nomSiteCtrl.text.trim().isEmpty
              ? "Siège principal"
              : _nomSiteCtrl.text.trim(),
          typeSite: _typeSiteCtrl.text.trim().isEmpty
              ? "agence"
              : _typeSiteCtrl.text.trim(),
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_modeAjoutAdresse
              ? "Adresse ajoutée avec succès ✅"
              : "Entreprise ANP créée avec succès ✅"),
        ),
      );

      Navigator.of(context).pop({
        'mode_ajout_adresse': _modeAjoutAdresse,
        'entreprise': entreprise,
        'site': site,
      });
    } catch (e) {
      setState(() {
        _erreur = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================
  //   UI
  // ============================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final titre = _modeAjoutAdresse
        ? "Ajouter une adresse à l’entreprise"
        : "Créer mon ANP Entreprise";

    final boutonTexte = _modeAjoutAdresse
        ? "Ajouter cette adresse"
        : "Créer mon ANP Entreprise";

    final latAfficher = _selectedPoint?.latitude ?? _position?.latitude;
    final lngAfficher = _selectedPoint?.longitude ?? _position?.longitude;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _couleurTexte,
        title: Text(
          titre,
          style: const TextStyle(
            color: _couleurTexte,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------------- ENTREPRISE ----------------
                if (!_modeAjoutAdresse) ...[
                  const Text(
                    "Informations de l’entreprise",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _couleurTexte,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nomCtrl,
                    decoration: const InputDecoration(
                      labelText: "Nom de l’entreprise *",
                      hintText: "Ex : Guinée Express",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return "Le nom de l’entreprise est obligatoire.";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _secteurCtrl,
                    decoration: const InputDecoration(
                      labelText: "Secteur d’activité",
                      hintText: "Ex : livraison, taxi, banque…",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: "Email de contact",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _telCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "Téléphone de contact",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _siteWebCtrl,
                    decoration: const InputDecoration(
                      labelText: "Site web",
                      hintText: "https://…",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  const Text(
                    "Entreprise",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _couleurTexte,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                      color: _bleuClair,
                    ),
                    child: Text(
                      widget.nomEntreprise ?? "Entreprise",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _couleurTexte,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ---------------- SITE ----------------
                Text(
                  _modeAjoutAdresse
                      ? "Nouvelle adresse de l’entreprise"
                      : "Site principal (siège / agence principale)",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _couleurTexte,
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _nomSiteCtrl,
                  decoration: InputDecoration(
                    labelText: _modeAjoutAdresse
                        ? "Nom de l’adresse"
                        : "Nom du site principal",
                    hintText: _modeAjoutAdresse
                        ? "Ex : Agence Kipé"
                        : "Ex : Siège Matoto",
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _typeSiteCtrl,
                  decoration: const InputDecoration(
                    labelText: "Type de site",
                    hintText: "Ex : agence, entrepôt, point relais…",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // ------ Localisation ------
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Localisation sur la carte",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _couleurTexte,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (latAfficher != null && lngAfficher != null)
                            Text(
                              "Lat : ${latAfficher.toStringAsFixed(5)}, "
                              "Lng : ${lngAfficher.toStringAsFixed(5)}",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _couleurTexte,
                              ),
                            )
                          else
                            Text(
                              "Touchez la carte ou utilisez le bouton pour vous localiser.",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _choisirLocalisation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _bleuPrincipal,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.my_location, size: 18),
                      label: const Text(
                        "Me localiser",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                const Text(
                  "Après la localisation, déplacez le point rouge sur la position exacte de votre site.",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),

                // ======= VRAIE CARTE =======
                SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _selectedPoint ?? _mapCenter,
                        initialZoom: _selectedPoint != null ? 16 : _mapZoom,
                        onTap: _onMapTap,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.soneya.ma_guinee',
                        ),
                        if (_selectedPoint != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _selectedPoint!,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_on,
                                  size: 36,
                                  color: _bleuPrincipal,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                if (_erreur != null) ...[
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  const SizedBox(height: 12),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _soumettre,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _bleuPrincipal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            boutonTexte,
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
      ),
    );
  }
}
