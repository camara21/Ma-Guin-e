import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/utilisateur_model.dart';
import '../providers/user_provider.dart';

import 'page_creation_anp_localisation.dart';
import 'page_mon_anp.dart';
import 'page_anp_entreprise_sites.dart';
import 'page_scan_anp_qr.dart';

// ───────────────────────────────────────────
// PALETTE PARTAGÉE
// ───────────────────────────────────────────
const Color _primaryBlue = Color(0xFF0066FF);
const Color _titleColor = Color(0xFF111827);
const Color _subtitleColor = Color(0xFF6B7280);
const Color _sheetBg = Colors.white;
const Color _iconColor = Colors.black87;

// Position fixe du header (descendu comme Waze)
const double _headerTopOffset = 32.0;

// Modèle interne pour les trajets récents
class _RecentRoute {
  final String code;
  final String label;
  final LatLng destination;

  _RecentRoute({
    required this.code,
    required this.label,
    required this.destination,
  });
}

class AnpHomePage extends StatefulWidget {
  const AnpHomePage({super.key});

  @override
  State<AnpHomePage> createState() => _AnpHomePageState();
}

class _AnpHomePageState extends State<AnpHomePage> {
  final MapController _mapController = MapController();
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Centre par défaut : Conakry
  LatLng _center = const LatLng(9.6412, -13.5784);
  double _zoom = 12;

  bool _loadingAnp = true;
  String? _anpCode;

  // ANP Maison / Travail
  String? _homeAnpCode;
  String? _workAnpCode;

  // Localisation
  Position? _position;
  bool _locationDenied = false;

  // Recherche (barre en bas)
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Résultat de recherche ANP (marqueur sur la carte)
  LatLng? _searchedAnpPoint;
  String? _lastSearchedCode;
  String? _lastSearchedLabel;

  // Itinéraire simple
  LatLng? _routeStart;
  LatLng? _routeEnd;

  // Historique mémoire
  final List<_RecentRoute> _recentRoutes = [];

  bool get _hasAnp => _anpCode != null && _anpCode!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchController.text = ''; // toujours vide par défaut
    _chargerAnp();
    _getLocation();
    _chargerMaisonTravail();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ───────────────── Localisation ─────────────────
  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationDenied = true);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _locationDenied = true);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        _position = pos;
        _center = LatLng(pos.latitude, pos.longitude);
        _zoom = 15;
      });

      _mapController.move(_center, _zoom);
    } catch (_) {
      if (mounted) {
        setState(() => _locationDenied = true);
      }
    }
  }

  // ───────────────── Chargement ANP perso ─────────────────
  Future<void> _chargerAnp() async {
    setState(() {
      _loadingAnp = true;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _anpCode = null;
          _loadingAnp = false;
        });
        return;
      }

      final Map<String, dynamic>? existant = await _supabase
          .from('anp_adresses')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _anpCode = existant != null ? (existant['code']?.toString()) : null;
        _loadingAnp = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _anpCode = null;
        _loadingAnp = false;
      });
    }
  }

  // ───────────────── Maison / Travail ─────────────────
  Future<void> _chargerMaisonTravail() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final meta = user.userMetadata ?? {};
    setState(() {
      _homeAnpCode = (meta['anp_home_code'] as String?)?.trim();
      _workAnpCode = (meta['anp_work_code'] as String?)?.trim();
    });
  }

  Future<void> _majUserMetadata(Map<String, dynamic> patch) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final current = Map<String, dynamic>.from(user.userMetadata ?? {});
    current.addAll(patch);

    await _supabase.auth.updateUser(
      UserAttributes(data: current),
    );
  }

  Future<void> _definirMaisonAvecMonAnp() async {
    if (!_hasAnp || _anpCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vous n’avez pas encore d’ANP.")),
      );
      return;
    }

    await _majUserMetadata({'anp_home_code': _anpCode});
    setState(() => _homeAnpCode = _anpCode);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Maison définie sur $_anpCode.")),
    );
  }

  Future<void> _editerMaisonTravail({required bool maison}) async {
    final initial = maison ? _homeAnpCode : _workAnpCode;
    final controller = TextEditingController(text: initial ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(maison ? "ANP Maison" : "ANP Travail"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: "Code ANP (GN-...)",
            ),
          ),
          actions: [
            if (initial != null)
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  "Supprimer",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Enregistrer"),
            ),
          ],
        );
      },
    );

    if (confirmed == null) return;

    if (confirmed == false) {
      await _majUserMetadata(
        maison ? {'anp_home_code': null} : {'anp_work_code': null},
      );
      setState(() {
        if (maison) {
          _homeAnpCode = null;
        } else {
          _workAnpCode = null;
        }
      });
      return;
    }

    final value = controller.text.trim().toUpperCase();
    if (value.isEmpty) return;

    await _majUserMetadata(
      maison ? {'anp_home_code': value} : {'anp_work_code': value},
    );
    setState(() {
      if (maison) {
        _homeAnpCode = value;
      } else {
        _workAnpCode = value;
      }
    });

    // on lance la recherche pour placer la carte dessus
    await _rechercherAnp(value);
  }

  Future<void> _allerVersMaisonOuTravail(String code) async {
    await _rechercherAnp(code);
  }

  Future<void> _lancerCreationAnp() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const PageCreationAnpLocalisation(),
      ),
    );

    if (code != null) {
      await _chargerAnp();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Votre ANP a été créée / mise à jour avec succès."),
        ),
      );
    }
  }

  Future<void> _ouvrirMonAnp() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PageMonAnp(),
      ),
    );
    await _chargerAnp();
  }

  // ───────────────── Recherche ANP ─────────────────
  Future<void> _rechercherAnp(String value) async {
    final code = value.trim().toUpperCase();
    if (code.isEmpty) return;

    try {
      Map<String, dynamic>? found;

      // 1) ANP PERSONNEL
      found = await _supabase
          .from('anp_adresses')
          .select('code, latitude, longitude')
          .eq('code', code)
          .maybeSingle();

      // 1b) tentative ilike
      if (found == null) {
        final list = await _supabase
            .from('anp_adresses')
            .select('code, latitude, longitude')
            .ilike('code', code)
            .limit(1);
        if (list is List && list.isNotEmpty) {
          found = list.first as Map<String, dynamic>;
        }
      }

      String label = "ANP $code";

      // 2) ANP ENTREPRISE
      if (found == null) {
        final site = await _supabase
            .from('anp_entreprise_sites')
            .select('code, latitude, longitude, nom_site')
            .eq('code', code)
            .maybeSingle();
        if (site != null) {
          found = site;
          final nomSite = (site['nom_site'] as String?) ?? '';
          if (nomSite.isNotEmpty) {
            label = "$nomSite ($code)";
          }
        }
      }

      if (found == null) {
        if (!mounted) return;
        setState(() {
          _searchedAnpPoint = null;
          _routeStart = null;
          _routeEnd = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aucun ANP trouvé pour "$code".'),
          ),
        );
        return;
      }

      final lat = (found['latitude'] as num).toDouble();
      final lng = (found['longitude'] as num).toDouble();
      final point = LatLng(lat, lng);

      setState(() {
        _center = point;
        _zoom = 17;
        _searchedAnpPoint = point;
        _lastSearchedCode = found!['code']?.toString() ?? code;
        _lastSearchedLabel = label;

        if (_position != null) {
          _routeStart = LatLng(_position!.latitude, _position!.longitude);
          _routeEnd = point;
        } else {
          _routeStart = null;
          _routeEnd = null;
        }
      });

      _mapController.move(point, 17);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ANP trouvé : ${_lastSearchedCode!}'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erreur lors de la recherche de l'ANP."),
        ),
      );
    }
  }

  // clic sur la barre de recherche => fenêtre type Waze/Uber
  Future<void> _ouvrirFenetreRecherche() async {
    FocusScope.of(context).unfocus();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _AnpSearchSheet(
          initialText: '',
          homeAnpCode: _homeAnpCode,
          workAnpCode: _workAnpCode,
          recentRoutes: _recentRoutes,
          onSelectCode: (code) {
            _rechercherAnp(code);
          },
        );
      },
    );
  }

  // ───────────────── Navigation externe ─────────────────
  Future<void> _ouvrirDansWaze(LatLng dest) async {
    final uriApp =
        Uri.parse('waze://?ll=${dest.latitude},${dest.longitude}&navigate=yes');
    final uriWeb = Uri.parse(
        'https://waze.com/ul?ll=${dest.latitude},${dest.longitude}&navigate=yes');

    if (await canLaunchUrl(uriApp)) {
      await launchUrl(uriApp);
    } else {
      await launchUrl(
        uriWeb,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  Future<void> _ouvrirDansGoogleMaps(LatLng dest) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${dest.latitude},${dest.longitude}'
      '&travelmode=driving',
    );

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _demarrerNavigation() async {
    if (_searchedAnpPoint == null) return;

    final dest = _searchedAnpPoint!;

    // on stocke dans l'historique
    if (_lastSearchedCode != null && _lastSearchedLabel != null) {
      final route = _RecentRoute(
        code: _lastSearchedCode!,
        label: _lastSearchedLabel!,
        destination: dest,
      );
      setState(() {
        _recentRoutes.removeWhere((r) => r.code == route.code);
        _recentRoutes.insert(0, route);
        if (_recentRoutes.length > 5) {
          _recentRoutes.removeLast();
        }
      });
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Ouvrir l’itinéraire avec",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Choisissez votre application de navigation",
                style: TextStyle(
                  fontSize: 13,
                  color: _subtitleColor,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.navigation, color: Colors.blue),
                title: const Text("Waze"),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _ouvrirDansWaze(dest);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.map_outlined, color: Colors.greenAccent),
                title: const Text("Google Maps"),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _ouvrirDansGoogleMaps(dest);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ───────────────── Menu latéral ─────────────────
  Widget _buildDrawer(BuildContext context) {
    final prov = context.watch<UserProvider>();
    final UtilisateurModel? user = prov.utilisateur;

    final String displayName =
        user == null ? 'Mon compte' : '${user.prenom} ${user.nom}'.trim();
    final String email = user?.email ?? '';
    final String? photoUrl = user?.photoUrl;

    return Drawer(
      child: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header profil
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                          ? NetworkImage(photoUrl)
                          : const AssetImage('assets/default_avatar.png')
                              as ImageProvider,
                      child: (photoUrl == null || photoUrl.isEmpty)
                          ? const Icon(Icons.person,
                              size: 30, color: Colors.black54)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _titleColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _subtitleColor,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFE5E7EB), height: 1),

              // Mon ANP perso
              ListTile(
                leading: const Icon(Icons.home_outlined, color: _titleColor),
                title: const Text(
                  "Mon ANP",
                  style: TextStyle(color: _titleColor),
                ),
                subtitle: _hasAnp && _anpCode != null
                    ? Text(
                        _anpCode!,
                        style: const TextStyle(
                          color: _subtitleColor,
                          fontSize: 12,
                        ),
                      )
                    : const Text(
                        "Aucune ANP créée pour l’instant",
                        style: TextStyle(
                          color: _subtitleColor,
                          fontSize: 12,
                        ),
                      ),
                onTap: () {
                  Navigator.pop(context);
                  if (_hasAnp) {
                    _ouvrirMonAnp();
                  } else {
                    _lancerCreationAnp();
                  }
                },
              ),

              // Créer / modifier ANP perso
              ListTile(
                leading: const Icon(Icons.add_location_alt_outlined,
                    color: _titleColor),
                title: Text(
                  _hasAnp ? "Modifier mon ANP" : "Créer mon ANP",
                  style: const TextStyle(color: _titleColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _lancerCreationAnp();
                },
              ),

              // ANP Entreprise
              ListTile(
                leading:
                    const Icon(Icons.business_outlined, color: _titleColor),
                title: const Text(
                  "ANP Entreprise",
                  style: TextStyle(color: _titleColor),
                ),
                subtitle: const Text(
                  "Gérer vos adresses professionnelles",
                  style: TextStyle(
                    color: _subtitleColor,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PageAnpEntrepriseSites(),
                    ),
                  );
                },
              ),

              const Spacer(),
              ListTile(
                leading: const Icon(Icons.arrow_back, color: _titleColor),
                title: const Text(
                  "Retour à l’accueil Soneya",
                  style: TextStyle(color: _titleColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────── UI principale ─────────────────
  @override
  Widget build(BuildContext context) {
    final hasAnp = _hasAnp;
    final hasRoute = _routeStart != null && _routeEnd != null;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _buildDrawer(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: null,
      body: Stack(
        children: [
          // 1) Carte
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: Container(
                color: Colors.white,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: _zoom,
                    minZoom: 3,
                    maxZoom: 19,
                    onPositionChanged: (pos, _) {
                      _center = pos.center ?? _center;
                      _zoom = pos.zoom ?? _zoom;
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'ma.guinee.anp',
                    ),
                    if (hasRoute)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [_routeStart!, _routeEnd!],
                            strokeWidth: 4,
                            color: _primaryBlue.withOpacity(0.8),
                          ),
                        ],
                      ),
                    if (_searchedAnpPoint != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _searchedAnpPoint!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_on,
                              size: 36,
                              color: _primaryBlue,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 2) HEADER (descendu comme Waze)
          Positioned(
            top: _headerTopOffset,
            left: 0,
            right: 0,
            child: SafeArea(
              top: true,
              bottom: false,
              minimum: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    // menu
                    InkWell(
                      onTap: () => _scaffoldKey.currentState?.openDrawer(),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.menu,
                          color: _iconColor,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // bouton "Créer mon ANP" centré
                    if (!hasAnp)
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            height: 40,
                            child: ElevatedButton.icon(
                              onPressed: _lancerCreationAnp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryBlue,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                elevation: 4,
                              ),
                              icon: const Icon(
                                Icons.location_on_outlined,
                                size: 18,
                              ),
                              label: const Text(
                                "Créer mon ANP",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      const Spacer(),

                    const SizedBox(width: 8),

                    // scanner QR à droite
                    InkWell(
                      onTap: () async {
                        final codeScanne =
                            await Navigator.of(context).push<String>(
                          MaterialPageRoute(
                            builder: (_) => const PageScanAnpQr(),
                          ),
                        );

                        if (codeScanne != null &&
                            codeScanne.trim().isNotEmpty) {
                          await _rechercherAnp(codeScanne);
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner,
                          color: _iconColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3) Bouton "Démarrer"
          if (_searchedAnpPoint != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).size.height * 0.30 + 12,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: _demarrerNavigation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    elevation: 5,
                  ),
                  icon: const Icon(
                    Icons.navigation,
                    size: 20,
                  ),
                  label: const Text(
                    "Démarrer",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

          // 4) Bottom sheet principale
          DraggableScrollableSheet(
            initialChildSize: 0.30,
            minChildSize: 0.12,
            maxChildSize: 0.5,
            builder: (ctx, scrollController) {
              return GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: Container(
                  decoration: BoxDecoration(
                    color: _sheetBg,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 18,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),

                      // Barre de recherche (toujours vide, juste un bouton)
                      InkWell(
                        onTap: _ouvrirFenetreRecherche,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: IgnorePointer(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: "Rechercher un ANP (GN-...)",
                                hintStyle: TextStyle(
                                  color: _subtitleColor,
                                  fontSize: 15,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: _subtitleColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Maison / Travail
                      Row(
                        children: [
                          Expanded(
                            child: _HomeWorkTile(
                              icon: Icons.home_outlined,
                              label: 'Maison',
                              code: _homeAnpCode,
                              accentColor: _primaryBlue,
                              onTap: () {
                                if (_homeAnpCode != null &&
                                    _homeAnpCode!.isNotEmpty) {
                                  _allerVersMaisonOuTravail(_homeAnpCode!);
                                } else if (_hasAnp) {
                                  _definirMaisonAvecMonAnp();
                                } else {
                                  _lancerCreationAnp();
                                }
                              },
                              onEdit: () => _editerMaisonTravail(maison: true),
                              helperText: _homeAnpCode != null
                                  ? 'Aller à la maison'
                                  : (_hasAnp
                                      ? 'Définir la maison avec mon ANP'
                                      : 'Créer une ANP pour la maison'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _HomeWorkTile(
                              icon: Icons.work_outline,
                              label: 'Travail',
                              code: _workAnpCode,
                              accentColor: Colors.orange,
                              onTap: () {
                                if (_workAnpCode != null &&
                                    _workAnpCode!.isNotEmpty) {
                                  _allerVersMaisonOuTravail(_workAnpCode!);
                                } else {
                                  _editerMaisonTravail(maison: false);
                                }
                              },
                              onEdit: () => _editerMaisonTravail(maison: false),
                              helperText: _workAnpCode != null
                                  ? 'Aller au travail'
                                  : 'Ajouter une ANP travail',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Derniers trajets
                      if (_recentRoutes.isNotEmpty) ...[
                        const Text(
                          "Derniers trajets",
                          style: TextStyle(
                            color: _titleColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final r in _recentRoutes)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE5F0FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.place_outlined,
                                size: 18,
                                color: _primaryBlue,
                              ),
                            ),
                            title: Text(
                              r.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              r.code,
                              style: const TextStyle(
                                color: _subtitleColor,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () => _allerVersMaisonOuTravail(r.code),
                          ),
                      ],

                      const SizedBox(height: 8),

                      if (_loadingAnp)
                        Row(
                          children: const [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  _primaryBlue,
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              "Chargement de vos informations ANP...",
                              style: TextStyle(
                                color: _subtitleColor,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        )
                      else if (hasAnp && _anpCode != null)
                        Text(
                          "Votre ANP : $_anpCode",
                          style: const TextStyle(
                            color: _subtitleColor,
                            fontSize: 13,
                          ),
                        )
                      else if (_locationDenied)
                        const Text(
                          "Activez la localisation pour centrer la carte sur votre position.",
                          style: TextStyle(
                            color: _subtitleColor,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ───────────────── Tuile Maison / Travail ─────────────────
class _HomeWorkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? code;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final String helperText;

  const _HomeWorkTile({
    required this.icon,
    required this.label,
    required this.code,
    required this.accentColor,
    required this.onTap,
    required this.onEdit,
    required this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    final hasCode = code != null && code!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5F0FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(icon, size: 18, color: accentColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onEdit,
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: _subtitleColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (hasCode)
              Text(
                code!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _subtitleColor,
                  fontSize: 12,
                ),
              )
            else
              Text(
                helperText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _subtitleColor,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fenêtre de recherche façon Waze / Uber
class _AnpSearchSheet extends StatefulWidget {
  final String initialText;
  final String? homeAnpCode;
  final String? workAnpCode;
  final List<_RecentRoute> recentRoutes;
  final ValueChanged<String> onSelectCode;

  const _AnpSearchSheet({
    required this.initialText,
    required this.homeAnpCode,
    required this.workAnpCode,
    required this.recentRoutes,
    required this.onSelectCode,
  });

  @override
  State<_AnpSearchSheet> createState() => _AnpSearchSheetState();
}

class _AnpSearchSheetState extends State<_AnpSearchSheet> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Champ toujours vide par défaut
    _controller = TextEditingController(text: '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _valider(String value) {
    widget.onSelectCode(value);
    // on lance la recherche MAIS on ne ferme pas la feuille
    FocusScope.of(context).unfocus();
  }

  void _tapCode(String code) {
    widget.onSelectCode(code);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (_) {
          FocusScope.of(context).unfocus();
        },
        child: Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),

                // Barre de recherche
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _valider,
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: "Rechercher un ANP (GN-...)",
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Petites icônes catégories
                const _CategoryRow(),
                const SizedBox(height: 16),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (widget.homeAnpCode != null &&
                          widget.homeAnpCode!.isNotEmpty)
                        _SearchListItem(
                          icon: Icons.home_outlined,
                          title: "Maison",
                          subtitle: widget.homeAnpCode!,
                          onTap: () => _tapCode(widget.homeAnpCode!),
                        ),
                      if (widget.workAnpCode != null &&
                          widget.workAnpCode!.isNotEmpty)
                        _SearchListItem(
                          icon: Icons.work_outline,
                          title: "Travail",
                          subtitle: widget.workAnpCode!,
                          onTap: () => _tapCode(widget.workAnpCode!),
                        ),
                      if (widget.recentRoutes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          "Derniers trajets",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        for (final r in widget.recentRoutes)
                          _SearchListItem(
                            icon: Icons.place_outlined,
                            title: r.label,
                            subtitle: r.code,
                            onTap: () => _tapCode(r.code),
                          ),
                      ],
                    ],
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

// Icônes Restaurant / Clinique / Hôtel / Divertissement
class _CategoryRow extends StatelessWidget {
  const _CategoryRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          _CategoryIcon(icon: Icons.restaurant, label: "Restaurants"),
          _CategoryIcon(icon: Icons.local_hospital, label: "Cliniques"),
          _CategoryIcon(icon: Icons.hotel, label: "Hôtels"),
          _CategoryIcon(icon: Icons.local_activity, label: "Divertissement"),
        ],
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CategoryIcon({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 22, color: _iconColor),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: _subtitleColor,
          ),
        ),
      ],
    );
  }
}

class _SearchListItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SearchListItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Color(0xFF6B7280),
        ),
      ),
      onTap: onTap,
    );
  }
}
