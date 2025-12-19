import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import '../models/utilisateur_model.dart';
import '../providers/user_provider.dart';

import 'page_creation_anp_localisation.dart';
import 'page_mon_anp.dart';
import 'page_anp_entreprise_sites.dart';
import 'page_scan_anp_qr.dart';

// fond hexagones + anneaux scan
import 'hexagon_background_painter.dart';

// PALETTE / COULEURS
const Color _primaryBlue = Color(0xFF0066FF);
const Color _titleColor = Color(0xFF111827);
const Color _subtitleColor = Color(0xFF6B7280);

class _RecentRoute {
  final String code;
  final String label;
  const _RecentRoute({required this.code, required this.label});
}

class AnpHomePage extends StatefulWidget {
  const AnpHomePage({super.key});
  @override
  State<AnpHomePage> createState() => _AnpHomePageState();
}

class _AnpHomePageState extends State<AnpHomePage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _loadingAnp = true;
  String? _anpCode;

  String? _homeAnpCode;
  String? _workAnpCode;

  final TextEditingController _searchController = TextEditingController();

  LatLng? _searchedPoint;
  String? _lastSearchedCode;
  String? _lastSearchedLabel;
  String? _lastSearchedNiceName;
  String? _lastCityLabel;
  bool _lastIsEntreprise = false;
  bool _lastIsAddress = false;

  final List<_RecentRoute> _recentRoutes = [];

  // ---------- HISTORIQUE (PERSISTANT) ----------

  Future<void> _saveRecentRoutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _recentRoutes
          .map((r) => jsonEncode({"code": r.code, "label": r.label}))
          .toList();
      await prefs.setStringList('recent_routes', list);
    } catch (_) {
      // on évite de crasher si jamais SharedPreferences plante
    }
  }

  Future<void> _loadRecentRoutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('recent_routes') ?? [];

      final routes = <_RecentRoute>[];
      for (final e in list) {
        try {
          final data = jsonDecode(e);
          final code = data["code"]?.toString();
          final label = data["label"]?.toString();
          if (code != null && label != null) {
            routes.add(_RecentRoute(code: code, label: label));
          }
        } catch (_) {
          // on ignore les entrées invalides
        }
      }

      if (!mounted) return;
      setState(() {
        _recentRoutes
          ..clear()
          ..addAll(routes);
      });
    } catch (_) {
      // rien de grave si la lecture échoue
    }
  }

  bool get _hasAnp => _anpCode != null && _anpCode!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchController.text = '';
    _chargerAnp();
    _chargerMaisonTravail();
    _loadRecentRoutes(); // 🔵 charge l'historique au démarrage
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --------- CHARGEMENT / METADATA USER ---------

  Future<void> _chargerAnp() async {
    setState(() => _loadingAnp = true);
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
          .select('code')
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
    await _supabase.auth.updateUser(UserAttributes(data: current));
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
            decoration: const InputDecoration(labelText: "Code ANP (GN-...)"),
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
          maison ? {'anp_home_code': null} : {'anp_work_code': null});
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
        maison ? {'anp_home_code': value} : {'anp_work_code': value});
    setState(() {
      if (maison) {
        _homeAnpCode = value;
      } else {
        _workAnpCode = value;
      }
    });

    await _rechercherAnpOuAdresse(value);
  }

  // --------- NAVIGATION EXTERNE ---------

  Future<void> _demarrerNavigation() async {
    if (_searchedPoint == null) return;
    final dest = _searchedPoint!;
    final destLabel =
        _lastSearchedNiceName ?? _lastSearchedLabel ?? 'cette adresse';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF020617),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "Aller à l’adresse de",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  destLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.navigation, color: Colors.lightBlue),
                title:
                    const Text("Waze", style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final uriApp = Uri.parse(
                      'waze://?ll=${dest.latitude},${dest.longitude}&navigate=yes');
                  final uriWeb = Uri.parse(
                      'https://waze.com/ul?ll=${dest.latitude},${dest.longitude}&navigate=yes');
                  if (await canLaunchUrl(uriApp)) {
                    await launchUrl(uriApp);
                  } else {
                    await launchUrl(uriWeb,
                        mode: LaunchMode.externalApplication);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.map, color: Colors.greenAccent),
                title: const Text("Google Maps",
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(
                      'https://www.google.com/maps/dir/?api=1&destination=${dest.latitude},${dest.longitude}');
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // --------- RECHERCHE ---------

  Future<void> _ouvrirFenetreRecherche() async {
    FocusScope.of(context).unfocus();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return _AnpSearchSheet(
          initialText: '',
          homeAnpCode: _homeAnpCode,
          workAnpCode: _workAnpCode,
          userAnpCode: _anpCode,
          recentRoutes: _recentRoutes,
          onSelectInput: (value) => _rechercherAnpOuAdresse(value),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _searchAddressWithNominatim(String q) async {
    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {
          'q': q,
          'format': 'json',
          'addressdetails': '1',
          'limit': '1',
          'countrycodes': 'gn,fr',
        },
      );

      final resp = await http.get(
        uri,
        headers: {'User-Agent': 'SoneyaANP/1.0 (contact@example.com)'},
      );

      if (resp.statusCode != 200) return null;

      final list = jsonDecode(resp.body) as List<dynamic>;
      if (list.isEmpty) return null;

      final obj = list.first as Map<String, dynamic>;
      final double lat = double.parse(obj['lat']);
      final double lon = double.parse(obj['lon']);

      final address = (obj['address'] as Map<String, dynamic>? ?? {});
      final city =
          address['city'] ?? address['town'] ?? address['village'] ?? '';
      final suburb = address['suburb'] ?? address['district'] ?? '';

      String nice = '';
      if (suburb != '' && city != '') {
        nice = "$suburb, $city";
      } else if (city != '') {
        nice = city;
      } else {
        nice = obj['display_name'];
      }

      return {
        'lat': lat,
        'lon': lon,
        'niceName': nice,
        'cityLabel': nice,
        'raw': obj['display_name'],
      };
    } catch (_) {
      return null;
    }
  }

  Future<String?> _reverseGeocodeCity(LatLng p) async {
    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/reverse',
        {
          'lat': p.latitude.toString(),
          'lon': p.longitude.toString(),
          'format': 'json',
          'zoom': '14',
          'addressdetails': '1',
        },
      );

      final resp = await http.get(
        uri,
        headers: {'User-Agent': 'SoneyaANP/1.0 (contact@example.com)'},
      );

      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body);
      final addr = data['address'] ?? {};
      final city =
          addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['suburb'];
      return city;
    } catch (_) {
      return null;
    }
  }

  Future<void> _rechercherAnpOuAdresse(String input) async {
    final value = input.trim();
    if (value.isEmpty) return;
    final code = value.toUpperCase();

    try {
      Map<String, dynamic>? found;
      bool isEntreprise = false;
      bool isAdresse = false;
      String label = "ANP $code";
      String nice = '';

      // 1) ANP perso
      found = await _supabase
          .from('anp_adresses')
          .select('code,latitude,longitude,user_id')
          .eq('code', code)
          .maybeSingle();

      if (found == null) {
        final list = await _supabase
            .from('anp_adresses')
            .select('code,latitude,longitude,user_id')
            .ilike('code', code)
            .limit(1);
        if (list is List && list.isNotEmpty) {
          found = list.first;
        }
      }

      if (found != null) {
        final userId = found['user_id'];
        if (userId != null && userId.toString().isNotEmpty) {
          final u = await _supabase
              .from('utilisateurs')
              .select('prenom,nom')
              .eq('id', userId)
              .maybeSingle();

          if (u != null) {
            final prenom = u['prenom']?.trim() ?? '';
            final nom = u['nom']?.trim() ?? '';
            nice = "$prenom $nom".trim();
            if (nice.isNotEmpty) label = "$nice ($code)";
          }
        }
      }

      // 2) ANP entreprise
      if (found == null) {
        final site = await _supabase
            .from('anp_entreprise_sites')
            .select('code,latitude,longitude,nom_site')
            .eq('code', code)
            .maybeSingle();

        if (site != null) {
          found = site;
          isEntreprise = true;
          final nomSite = site['nom_site'] ?? '';
          if (nomSite != '') {
            nice = nomSite;
            label = "$nice ($code)";
          }
        }
      }

      LatLng? pt;
      String? cityFromReverse;

      if (found != null) {
        pt = LatLng(
          (found['latitude'] as num).toDouble(),
          (found['longitude'] as num).toDouble(),
        );
        cityFromReverse = await _reverseGeocodeCity(pt);
      }

      // 3) Adresse "libre" (Nominatim)
      if (found == null) {
        final res = await _searchAddressWithNominatim(value);
        if (res != null) {
          isAdresse = true;
          pt = LatLng(res['lat'], res['lon']);
          nice = res['niceName'];
          label = res['niceName'];
          cityFromReverse = res['cityLabel'];
        }
      }

      if (pt == null) {
        setState(() {
          _searchedPoint = null;
          _lastSearchedCode = null;
          _lastSearchedLabel = null;
          _lastSearchedNiceName = null;
          _lastCityLabel = null;
          _lastIsEntreprise = false;
          _lastIsAddress = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aucun ANP ou adresse pour "$value".')),
        );
        return;
      }

      // 🔵 On met à jour l'état de la dernière destination trouvée
      setState(() {
        _searchedPoint = pt!;
        _lastSearchedCode = found != null ? found['code']?.toString() : null;
        _lastSearchedLabel = label;
        _lastSearchedNiceName = nice.isNotEmpty ? nice : label;
        _lastCityLabel = cityFromReverse;
        _lastIsEntreprise = isEntreprise;
        _lastIsAddress = isAdresse;
      });

      // 🔵 Construction de l'entrée historique (même pour adresse libre)
      final historyCode = _lastSearchedCode ?? value;
      final historyLabel = _lastSearchedNiceName ?? _lastSearchedLabel ?? label;

      // 🔵 Mise à jour de la liste + sauvegarde
      setState(() {
        _recentRoutes.removeWhere((r) => r.code == historyCode);
        _recentRoutes.insert(
          0,
          _RecentRoute(code: historyCode, label: historyLabel),
        );
        if (_recentRoutes.length > 5) {
          _recentRoutes.removeRange(5, _recentRoutes.length);
        }
      });
      await _saveRecentRoutes();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAdresse ? "Adresse trouvée : $label" : "ANP trouvé : $label",
          ),
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de la recherche.")),
      );
    }
  }

  // --------- STYLE HUD / BOUTONS ---------

  BoxDecoration _hudButtonDecoration() {
    return BoxDecoration(
      color: Colors.black.withOpacity(0.35),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withOpacity(0.18)),
    );
  }

  Widget _buildTopBar() {
    final mq = MediaQuery.of(context);
    final isTablet = mq.size.shortestSide >= 600;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 16,
        vertical: isTablet ? 12 : 10,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: isTablet ? 48 : 40,
              height: isTablet ? 48 : 40,
              decoration: _hudButtonDecoration(),
              child: Icon(
                Icons.menu,
                color: Colors.white,
                size: isTablet ? 24 : 22,
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final mq = MediaQuery.of(context);
    final isTablet = mq.size.shortestSide >= 600;

    return GestureDetector(
      onTap: _ouvrirFenetreRecherche,
      child: Container(
        height: isTablet ? 60 : 52,
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 22 : 18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: Colors.white70,
              size: isTablet ? 22 : 20,
            ),
            SizedBox(width: isTablet ? 12 : 10),
            Text(
              "recherche anp",
              style: TextStyle(
                color: Colors.white.withOpacity(0.70),
                fontSize: isTablet ? 16 : 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------- CARTE SCAN ANP (style image + anneaux) ---------

  Widget _buildScanCard() {
    final mq = MediaQuery.of(context);
    final isTablet = mq.size.shortestSide >= 600;

    return GestureDetector(
      onTap: () async {
        final codeScanne = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PageScanAnpQr()),
        );
        if (codeScanne != null) await _rechercherAnpOuAdresse(codeScanne);
      },
      child: Container(
        height: isTablet ? 200 : 164,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF00A9FF),
              Color(0xFF0066FF),
              Color(0xFF6D28D9),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0066FF).withOpacity(0.45),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 30 : 24),
        child: Row(
          children: [
            SizedBox(
              width: isTablet ? 120 : 100,
              height: isTablet ? 120 : 100,
              child: CustomPaint(
                painter: ScanRingPainter(),
                child: Center(
                  child: Container(
                    width: isTablet ? 80 : 68,
                    height: isTablet ? 80 : 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.60),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        "SCAN",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 15 : 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: isTablet ? 26 : 22),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ANP",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 44 : 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  SizedBox(height: isTablet ? 8 : 6),
                  Text(
                    "Adresse Numérique presonnelle",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isTablet ? 15 : 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------- CARTE GUINÉE HOLOGRAPHIQUE (✅ ADAPTÉE TABLETTE / TOUS ÉCRANS) ---------

  Widget _buildGuineaCard(bool hasResult) {
    final mq = MediaQuery.of(context);
    final isTablet = mq.size.shortestSide >= 600;

    // ✅ hauteur responsive basée sur la largeur : évite le "crop" et reste cohérent tablette/web
    final w = mq.size.width;
    final rawH = isTablet ? (w * 0.42) : (w * 0.62);
    final cardH =
        rawH.clamp(isTablet ? 340.0 : 260.0, isTablet ? 560.0 : 430.0);

    final bottomTextPad = isTablet ? 44.0 : 35.0;
    final sidePad = isTablet ? 28.0 : 24.0;

    return Container(
      height: cardH,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.blueAccent.withOpacity(0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.25),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // ✅ fond léger (cover) pour éviter zones vides si l'image contient des marges
            Positioned.fill(
              child: Opacity(
                opacity: 0.16,
                child: Image.asset(
                  'assets/anp/guinee_holo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // ✅ image principale en "contain" => on voit toute la carte sur tablette/desktop
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  left: isTablet ? 18 : 14,
                  right: isTablet ? 18 : 14,
                  top: isTablet ? 14 : 12,
                  bottom:
                      hasResult ? (isTablet ? 98 : 90) : (isTablet ? 84 : 76),
                ),
                child: Image.asset(
                  'assets/anp/guinee_holo.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                ),
              ),
            ),

            // ✅ gradient bas uniquement (améliore lisibilité texte sans masquer la carte)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: isTablet ? 150 : 135,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.70),
                        Colors.black.withOpacity(0.10),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
            ),

            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: bottomTextPad,
                  left: sidePad,
                  right: sidePad,
                ),
                child: Text(
                  "On peut vous rejoindre partout en Guinée\navec votre ANP",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTablet ? 17 : 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            if (hasResult)
              Positioned(
                bottom: isTablet ? 26 : 20,
                right: isTablet ? 26 : 20,
                child: ElevatedButton.icon(
                  onPressed: _demarrerNavigation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 26 : 20,
                      vertical: isTablet ? 14 : 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 6,
                  ),
                  icon: Icon(Icons.navigation, size: isTablet ? 22 : 20),
                  label: const Text(
                    "Démarrer",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultArea(bool hasResult) {
    if (hasResult) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Destination trouvée :",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            _lastSearchedNiceName ?? _lastSearchedLabel ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_lastCityLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              _lastCityLabel!,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
          if (_lastSearchedCode != null) ...[
            const SizedBox(height: 2),
            Text(
              _lastSearchedCode!,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _searchedPoint = null;
                _lastSearchedCode = null;
                _lastSearchedLabel = null;
                _lastSearchedNiceName = null;
                _lastCityLabel = null;
                _lastIsEntreprise = false;
                _lastIsAddress = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.10),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Colors.white.withOpacity(0.25),
                ),
              ),
            ),
            child: const Text(
              "Annuler l’adresse trouvée",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    if (_loadingAnp) {
      return Row(
        children: const [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(_primaryBlue),
            ),
          ),
          SizedBox(width: 10),
          Text(
            "Chargement...",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      );
    }

    if (!_hasAnp) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Créez votre ANP pour être joignable.",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PageCreationAnpLocalisation(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
            ),
            child: const Text(
              "Créer mon ANP",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMyAnpLine() {
    if (!_hasAnp) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        "Votre ANP : $_anpCode",
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
        ),
      ),
    );
  }

  // ✅ CORRECTION : layout scrollable (anti overflow au resize web)
  Widget _buildMainContent(BuildContext context) {
    final hasResult = _searchedPoint != null;

    final mq = MediaQuery.of(context);
    final isTablet = mq.size.shortestSide >= 600;

    final double hPad = isTablet ? 24 : 16;
    final double topGap = isTablet ? 8 : 4;
    final double afterSearchGap = isTablet ? 34 : 28;
    final double afterScanGap = isTablet ? 30 : 26;
    final double afterLineGap = isTablet ? 18 : 16;
    final double scrollVPad = isTablet ? 12 : 8;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: scrollVPad),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: topGap),
                  _buildTopBar(),
                  SizedBox(height: topGap),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: _buildSearchBar(),
                  ),
                  SizedBox(height: afterSearchGap),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: _buildScanCard(),
                  ),
                  SizedBox(height: afterScanGap),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: _buildGuineaCard(hasResult),
                  ),
                  _buildMyAnpLine(),
                  SizedBox(height: afterLineGap),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: _buildSearchResultArea(hasResult),
                  ),
                  SizedBox(height: isTablet ? 18 : 14),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --------- DRAWER ---------

  Drawer _buildDrawer(BuildContext context) {
    final prov = context.watch<UserProvider>();
    final UtilisateurModel? user = prov.utilisateur;

    final name =
        user == null ? 'Mon compte' : '${user.prenom} ${user.nom}'.trim();
    final email = user?.email ?? '';
    final photo = user?.photoUrl;

    return Drawer(
      child: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: (photo != null && photo.isNotEmpty)
                          ? NetworkImage(photo)
                          : const AssetImage('assets/default_avatar.png')
                              as ImageProvider,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: _titleColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                            ),
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
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
              ListTile(
                leading: const Icon(Icons.location_pin, color: _titleColor),
                title: const Text(
                  "Mon ANP",
                  style: TextStyle(color: _titleColor),
                ),
                subtitle: _hasAnp
                    ? Text(
                        _anpCode!,
                        style: const TextStyle(
                          color: _subtitleColor,
                          fontSize: 12,
                        ),
                      )
                    : const Text(
                        "Aucune ANP pour l’instant",
                        style: TextStyle(
                          color: _subtitleColor,
                          fontSize: 12,
                        ),
                      ),
                onTap: () {
                  Navigator.pop(context);
                  if (_hasAnp) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PageMonAnp()),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PageCreationAnpLocalisation(),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_location_alt, color: _titleColor),
                title: Text(
                  _hasAnp ? "J’ai déménagé" : "Créer mon ANP",
                  style: const TextStyle(color: _titleColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PageCreationAnpLocalisation(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.apartment, color: _titleColor),
                title: const Text(
                  "ANP Entreprise",
                  style: TextStyle(color: _titleColor),
                ),
                subtitle: const Text(
                  "Gérer vos sites",
                  style: TextStyle(
                    color: _subtitleColor,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
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
                  "Retour à Soneya",
                  style: TextStyle(color: _titleColor),
                ),
                onTap: () {
                  Navigator.pop(context); // ferme le Drawer
                  Navigator.pop(context); // retourne à la Home Soneya
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // --------- BUILD ROOT ---------

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);

    return Theme(
      data: baseTheme.copyWith(
        textTheme: baseTheme.textTheme.apply(fontFamily: 'Poppins'),
      ),
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _buildDrawer(context),
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF030712),
                    Color(0xFF0F172A),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0.22,
                child: CustomPaint(
                  painter: HexagonBackgroundPainter(),
                ),
              ),
            ),
            SafeArea(
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                ),
                child: _buildMainContent(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------- SEARCH SHEET -------------------------

class _AnpSearchSheet extends StatefulWidget {
  final String initialText;
  final String? homeAnpCode;
  final String? workAnpCode;
  final String? userAnpCode; // ← ANP de l'utilisateur si pas de "Maison"
  final List<_RecentRoute> recentRoutes;
  final ValueChanged<String> onSelectInput;

  const _AnpSearchSheet({
    required this.initialText,
    required this.homeAnpCode,
    required this.workAnpCode,
    required this.userAnpCode,
    required this.recentRoutes,
    required this.onSelectInput,
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
    _controller = TextEditingController(text: widget.initialText);
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

  void _valider(String v) {
    final txt = v.trim();
    if (txt.isEmpty) return;
    widget.onSelectInput(txt);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF030712),
              Color(0xFF020617),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.search,
                  onSubmitted: _valider,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    hintText: "Rechercher un ANP ou une adresse...",
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF0B1728),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () {
                        if (_controller.text.isEmpty) {
                          Navigator.pop(context);
                        } else {
                          _controller.clear();
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _SearchListItem(
                      icon: Icons.home_outlined,
                      title: "Maison",
                      subtitle: widget.homeAnpCode ?? widget.userAnpCode ?? "",
                      onTap: () {
                        final codeMaison =
                            widget.homeAnpCode ?? widget.userAnpCode ?? "";

                        if (codeMaison.isNotEmpty) {
                          widget.onSelectInput(codeMaison);
                        }
                        Navigator.pop(context);
                      },
                    ),
                    if (widget.workAnpCode != null &&
                        widget.workAnpCode!.isNotEmpty)
                      _SearchListItem(
                        icon: Icons.work_outline,
                        title: "Travail",
                        subtitle: widget.workAnpCode!,
                        onTap: () {
                          widget.onSelectInput(widget.workAnpCode!);
                          Navigator.pop(context);
                        },
                      ),
                    if (widget.recentRoutes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        "Historique des recherches",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      for (final r in widget.recentRoutes)
                        _SearchListItem(
                          icon: Icons.history,
                          title: r.label,
                          subtitle: r.code,
                          onTap: () {
                            widget.onSelectInput(r.code);
                            Navigator.pop(context);
                          },
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
      leading: Icon(
        icon,
        color: Colors.white70,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
        ),
      ),
      onTap: onTap,
    );
  }
}
