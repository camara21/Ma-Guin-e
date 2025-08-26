// lib/pages/vtc/home_client_vtc_page.dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/utilisateur_model.dart';

// --------- Palette Guinée ----------
const Color kGuineaRed = Color(0xFFE73B2E);
const Color kGuineaYellow = Color(0xFFFFD400);
const Color kGuineaGreen = Color(0xFF1BAA5C);

// --------- Enums ----------
enum TargetField { depart, arrivee }
enum _BottomTab { profil, historique, paiement }

class HomeClientVtcPage extends StatefulWidget {
  final UtilisateurModel currentUser;
  const HomeClientVtcPage({super.key, required this.currentUser});

  @override
  State<HomeClientVtcPage> createState() => _HomeClientVtcPageState();
}

class _HomeClientVtcPageState extends State<HomeClientVtcPage>
    with SingleTickerProviderStateMixin {
  final _sb = Supabase.instance.client;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // --- Map ---
  final MapController _map = MapController();
  ll.LatLng _center = const ll.LatLng(9.6412, -13.5784); // Conakry
  double _zoom = 13;

  // --- Points & labels ---
  ll.LatLng? _depart;
  String? _departLabel;
  ll.LatLng? _arrivee;
  String? _arriveeLabel;

  // Champ actif
  TargetField _target = TargetField.depart;

  // Saisie
  final _departCtrl = TextEditingController();
  final _arriveeCtrl = TextEditingController();

  // Anim
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  // Ville (pour Nominatim)
  String _city = 'Conakry';

  // Véhicule: 'moto' | 'car'
  String _vehicle = 'moto';

  // Itinéraire & estimation
  List<ll.LatLng> _routePoints = [];
  bool _routing = false;
  double? _distanceKm;
  int? _durationMin;
  int? _priceGNF;

  bool _creating = false;

  // --- Profil / Paiements / Historique (dock) ---
  late UtilisateurModel _user;
  List<Map<String, dynamic>> _lastPayments = [];
  bool _loadingPayments = false;
  List<Map<String, dynamic>> _recent = [];
  bool _loadingRecent = false;

  @override
  void initState() {
    super.initState();
    _user = widget.currentUser;

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _refreshUserFromSupabase();
    _loadLastPayments();
    _loadRecent();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _departCtrl.dispose();
    _arriveeCtrl.dispose();
    super.dispose();
  }

  // =================== TOAST ===================
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ============ PROFIL / HISTO / PAIEMENTS ============
  Future<void> _refreshUserFromSupabase() async {
    try {
      Map<String, dynamic>? m;
      try {
        final r = await _sb
            .from('profiles')
            .select('id, nom, prenom, email, telephone, photo_url, pays, genre')
            .eq('id', widget.currentUser.id)
            .maybeSingle();
        if (r != null) m = Map<String, dynamic>.from(r);
      } catch (_) {}

      if (m == null) {
        final r = await _sb
            .from('utilisateurs')
            .select('id, nom, prenom, email, telephone, photo_url, pays, genre')
            .eq('id', widget.currentUser.id)
            .maybeSingle();
        if (r != null) m = Map<String, dynamic>.from(r);
      }
      if (!mounted || m == null) return;

      final mm = m; // non-null local

      setState(() {
        _user = UtilisateurModel(
          id: (mm['id']?.toString() ?? widget.currentUser.id),
          nom: (mm['nom']?.toString() ?? ''),
          prenom: (mm['prenom']?.toString() ?? ''),
          email: (mm['email']?.toString() ?? ''),
          telephone: (mm['telephone']?.toString() ?? ''),
          photoUrl: mm['photo_url']?.toString(),
          pays: (mm['pays']?.toString() ?? widget.currentUser.pays ?? 'GN'),
          genre: (mm['genre']?.toString() ?? 'autre'),
        );
      });
    } catch (_) {}
  }

  Future<void> _loadLastPayments() async {
    setState(() => _loadingPayments = true);
    try {
      final rows = await _sb
          .from('paiements')
          .select('id, amount_gnf, moyen, statut, created_at, ride_id, courses!inner(client_id)')
          .eq('courses.client_id', widget.currentUser.id)
          .order('created_at', ascending: false)
          .limit(5);
      _lastPayments = (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      _lastPayments = [];
    } finally {
      if (mounted) setState(() => _loadingPayments = false);
    }
  }

  Future<void> _loadRecent() async {
    setState(() => _loadingRecent = true);
    try {
      final rows = await _sb
          .from('courses')
          .select('id,statut,prix_gnf,depart_adresse,arrivee_adresse,demande_a')
          .eq('client_id', widget.currentUser.id)
          .order('demande_a', ascending: false)
          .limit(10);
      _recent = (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingRecent = false);
    }
  }

  // ================= LIEUX / SUGGESTIONS =================
  Future<List<_Lieu>> _searchLieux(String q) async {
    q = q.trim();
    if (q.isEmpty) return [];
    try {
      final rows = await _sb
          .from('lieux')
          .select('id, name, type, city, commune, lat, lng')
          .ilike('name', '%$q%')
          .limit(15);
      final list = (rows as List).map((e) => _Lieu.fromMap(Map<String, dynamic>.from(e))).toList();
      if (list.isEmpty) {
        final ext = await _searchNominatim(q);
        return ext;
      }
      return list;
    } catch (_) {
      return _searchNominatim(q);
    }
  }

  Future<List<_Lieu>> _searchNominatim(String q) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=json&limit=8&addressdetails=1'
        '&countrycodes=gn'
        '&city=${Uri.encodeComponent(_city)}'
        '&q=${Uri.encodeComponent(q)}',
      );
      final r = await http.get(uri, headers: {'User-Agent': 'ma_guinee/1.0 (support@ma-guinee.app)'});
      if (r.statusCode != 200) return [];
      final List data = jsonDecode(r.body);
      return data.map<_Lieu>((e) {
        final full = (e['display_name'] as String?) ?? '';
        final parts = full.split(',').map((s) => s.trim()).toList();
        final short = parts.isNotEmpty ? parts.take(2).join(', ') : full;
        return _Lieu(
          id: (e['osm_id']?.toString() ?? e['place_id']?.toString() ?? ''),
          name: short,
          type: (e['type']?.toString() ?? 'lieu'),
          lat: double.tryParse(e['lat']?.toString() ?? '') ?? 0,
          lng: double.tryParse(e['lon']?.toString() ?? '') ?? 0,
          city: null,
          commune: null,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ================= GEOCODAGE INVERSÉ =================
  Future<String?> _reverseGeocode(ll.LatLng p) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=${p.latitude}&lon=${p.longitude}&zoom=16&addressdetails=1',
      );
      final r = await http.get(uri, headers: {'User-Agent': 'ma_guinee/1.0'});
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body);
      final disp = j['display_name'] as String?;
      if (disp == null) return null;
      final parts = disp.split(',').map((e) => e.trim()).toList();
      return parts.take(2).join(', ');
    } catch (_) {
      return null;
    }
  }

  // ================= POSITION / ACTIONS =================
  void _swap() {
    setState(() {
      final tPoint = _depart;
      final tLabel = _departLabel;
      _depart = _arrivee;
      _departLabel = _arriveeLabel;
      _arrivee = tPoint;
      _arriveeLabel = tLabel;

      final tText = _departCtrl.text;
      _departCtrl.text = _arriveeCtrl.text;
      _arriveeCtrl.text = tText;
    });
    if (_depart != null && _arrivee != null) _computeRoute();
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _toast('Service de localisation désactivé.');
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied) {
      _toast('Permission de localisation refusée.');
      return false;
    }
    if (perm == LocationPermission.deniedForever) {
      _toast('Permission refusée définitivement (réglages système).');
      return false;
    }
    return true;
  }

  Future<void> _myLocation() async {
    try {
      final ok = await _ensureLocationPermission();
      if (!ok) return;
      final p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final me = ll.LatLng(p.latitude, p.longitude);
      _map.move(me, 16);
      setState(() {
        _center = me;
        if (_target == TargetField.depart) {
          _depart = me; _departLabel = 'Ma position'; _departCtrl.text = 'Ma position';
        } else {
          _arrivee = me; _arriveeLabel = 'Ma position'; _arriveeCtrl.text = 'Ma position';
        }
      });
      if (_depart != null && _arrivee != null) _computeRoute();
    } catch (e) {
      _toast('Position indisponible: $e');
    }
  }

  Future<void> _applyFreeText({required bool depart}) async {
    final txt = (depart ? _departCtrl.text : _arriveeCtrl.text).trim();
    if (txt.isEmpty) return;
    final results = await _searchLieux(txt);
    if (results.isEmpty) {
      _toast("Aucun lieu trouvé pour « $txt ».");
      return;
    }
    final l = results.first;
    setState(() {
      final p = ll.LatLng(l.lat, l.lng);
      if (depart) {
        _depart = p; _departLabel = l.fullLabel; _departCtrl.text = l.fullLabel;
      } else {
        _arrivee = p; _arriveeLabel = l.fullLabel; _arriveeCtrl.text = l.fullLabel;
      }
    });
    _map.move(depart ? _depart! : _arrivee!, 15);
    if (_depart != null && _arrivee != null) _computeRoute();
  }

  void _commitCenterAsTarget() async {
    final p = _center;
    setState(() {
      if (_target == TargetField.depart) {
        _depart = p;
      } else {
        _arrivee = p;
      }
    });
    final label = await _reverseGeocode(p);
    if (!mounted) return;
    setState(() {
      if (_target == TargetField.depart) {
        _departLabel = label ?? 'Point de départ'; _departCtrl.text = _departLabel!;
      } else {
        _arriveeLabel = label ?? 'Point d’arrivée'; _arriveeCtrl.text = _arriveeLabel!;
      }
    });
    if (_depart != null && _arrivee != null) _computeRoute();
  }

  // ================= ITINÉRAIRE / PRIX =================
  Future<void> _computeRoute() async {
    final a = _depart, b = _arrivee;
    if (a == null || b == null) return;

    setState(() {
      _routing = true;
      _routePoints = [];
      _distanceKm = null;
      _durationMin = null;
      _priceGNF = null;
    });

    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving'
        '/${a.longitude},${a.latitude};${b.longitude},${b.latitude}'
        '?overview=full&geometries=geojson',
      );
      final resp = await http.get(uri, headers: {'User-Agent': 'ma_guinee/1.0'});
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final r = routes.first as Map<String, dynamic>;
          final distMeters = (r['distance'] as num?)?.toDouble() ?? 0;
          final durSeconds = (r['duration'] as num?)?.toDouble() ?? 0;
          final km = distMeters / 1000.0;
          final min = durSeconds / 60.0;

          final coords = (r['geometry']?['coordinates'] as List?) ?? [];
          final pts = <ll.LatLng>[];
          for (final c in coords) {
            if (c is List && c.length >= 2) {
              pts.add(ll.LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
            }
          }
          setState(() => _routePoints = pts);

          _applyEstimation(km, min);
          _fitMapToBounds(a, b);
          return;
        }
      }
      _fallbackDirectEstimation(a, b);
    } catch (_) {
      _fallbackDirectEstimation(a, b);
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  void _fallbackDirectEstimation(ll.LatLng a, ll.LatLng b) {
    const d = ll.Distance();
    final km = d.as(ll.LengthUnit.Kilometer, a, b);
    final avgSpeedKmh = _vehicle == 'moto' ? 28.0 : 22.0;
    final min = (km / math.max(avgSpeedKmh, 5) * 60).clamp(3, 180).toDouble();
    setState(() => _routePoints = [a, b]);
    _applyEstimation(km, min);
    _fitMapToBounds(a, b);
  }

  void _applyEstimation(double km, double min) {
    setState(() {
      _distanceKm = double.parse(km.toStringAsFixed(2));
      _durationMin = min.ceil();
      _priceGNF = _estimatePrice(km, min);
    });
  }

  int _estimatePrice(double km, double min) {
    if (_vehicle == 'moto') {
      const base = 8000;
      const perKm = 1500;
      const perMin = 60;
      return (base + perKm * km + perMin * min).round();
    } else {
      const base = 12000;
      const perKm = 2200;
      const perMin = 80;
      return (base + perKm * km + perMin * min).round();
    }
  }

  void _fitMapToBounds(ll.LatLng a, ll.LatLng b) {
    final mid = ll.LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2);
    _map.move(mid, 13);
  }

  // ================== CRÉATION COURSE ==================
  Future<void> _createCourse() async {
    final a = _depart, b = _arrivee;
    final km = _distanceKm, min = _durationMin, price = _priceGNF;
    if (a == null || b == null || km == null || min == null || price == null) {
      _toast('Sélectionnez départ et destination puis calculez l’estimation.');
      return;
    }

    final metres = (km * 1000).round();
    final seconds = (min * 60).round();

    final departPoint = {'type': 'Point', 'coordinates': [a.longitude, a.latitude]};
    final arriveePoint = {'type': 'Point', 'coordinates': [b.longitude, b.latitude]};

    setState(() => _creating = true);
    try {
      final inserted = await _sb
          .from('courses')
          .insert({
            'client_id': widget.currentUser.id,
            'vehicule': _vehicle,
            'depart_adresse': _departLabel ?? _departCtrl.text,
            'arrivee_adresse': _arriveeLabel ?? _arriveeCtrl.text,
            'depart_point': departPoint,
            'arrivee_point': arriveePoint,
            'depart_lat': a.latitude,
            'depart_lng': a.longitude,
            'arrivee_lat': b.latitude,
            'arrivee_lng': b.longitude,
            'distance_metres': metres,
            'duree_secondes_est': seconds,
            'prix_gnf': price,
          })
          .select('id')
          .single();

      final courseId = (inserted['id'] ?? '').toString();
      _toast('Demande créée.');
      if (courseId.isNotEmpty && mounted) {
        Navigator.pushNamed(context, '/vtc/offres', arguments: {'demandeId': courseId});
      }
    } catch (e) {
      _toast('Erreur lors de la création: $e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    final padTop = MediaQuery.of(context).padding.top;
    final padBot = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ---- CARTE ----
          Positioned.fill(
            child: Listener(
              onPointerUp: (_) => _commitCenterAsTarget(),
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: _zoom,
                  interactionOptions: const InteractionOptions(flags: ~InteractiveFlag.rotate),
                  onPositionChanged: (pos, _) {
                    if (pos.center != null) {
                      _center = pos.center!;
                      _zoom = pos.zoom ?? _zoom;
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    retinaMode: true,
                    userAgentPackageName: 'com.ma_guinee.app',
                  ),
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [Polyline(points: _routePoints, strokeWidth: 5, color: Colors.green)],
                    ),
                  MarkerLayer(
                    markers: [
                      if (_depart != null)
                        Marker(
                          point: _depart!,
                          width: 40,
                          height: 40,
                          child: Icon(Icons.location_pin, color: kGuineaRed, size: 34),
                        ),
                      if (_arrivee != null)
                        Marker(
                          point: _arrivee!,
                          width: 40,
                          height: 40,
                          child: Icon(Icons.flag, color: kGuineaGreen, size: 30),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ---- Épingle fantôme au centre ----
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, -6 + (_pulse.value * -2)),
                    child: Icon(
                      _target == TargetField.depart ? Icons.place : Icons.flag,
                      size: 34,
                      color: _target == TargetField.depart
                          ? kGuineaRed.withOpacity(.85)
                          : kGuineaGreen.withOpacity(.85),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ---- Barre départ / arrivée + ville ----
          Positioned(
            top: padTop + 10,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _searchPill(
                        label: 'Départ',
                        controller: _departCtrl,
                        selected: _target == TargetField.depart,
                        onTap: () => setState(() => _target = TargetField.depart),
                        onSelected: (l) {
                          setState(() {
                            _depart = ll.LatLng(l.lat, l.lng);
                            _departLabel = l.fullLabel;
                            _departCtrl.text = l.fullLabel;
                          });
                          _map.move(_depart!, 16);
                          if (_arrivee != null) _computeRoute();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Glass(
                      child: PopupMenuButton<String>(
                        tooltip: 'Ville',
                        onSelected: (v) => setState(() => _city = v),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'Conakry', child: Text('Conakry')),
                          PopupMenuItem(value: 'Kindia', child: Text('Kindia')),
                          PopupMenuItem(value: 'Labé', child: Text('Labé')),
                          PopupMenuItem(value: 'Kankan', child: Text('Kankan')),
                          PopupMenuItem(value: 'N’Zérékoré', child: Text('N’Zérékoré')),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_city, size: 18),
                              const SizedBox(width: 6),
                              Text(_city, style: const TextStyle(fontWeight: FontWeight.w600)),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _searchPill(
                  label: 'Arrivée',
                  controller: _arriveeCtrl,
                  selected: _target == TargetField.arrivee,
                  onTap: () => setState(() => _target = TargetField.arrivee),
                  onSelected: (l) {
                    setState(() {
                      _arrivee = ll.LatLng(l.lat, l.lng);
                      _arriveeLabel = l.fullLabel;
                      _arriveeCtrl.text = l.fullLabel;
                    });
                    _map.move(_arrivee!, 16);
                    if (_depart != null) _computeRoute();
                  },
                ),
              ],
            ),
          ),

          // ---- Toggle véhicule + actions floating ----
          Positioned(
            right: 12,
            bottom: 220 + padBot,
            child: Column(
              children: [
                _roundGlass(icon: Icons.my_location, onTap: _myLocation),
                const SizedBox(height: 10),
                _roundGlass(icon: Icons.swap_vert_rounded, onTap: _swap),
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 210 + padBot,
            child: _Glass(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _VehicleToggle(
                      icon: Icons.two_wheeler,
                      label: 'Moto',
                      selected: _vehicle == 'moto',
                      onTap: () {
                        setState(() => _vehicle = 'moto');
                        if (_depart != null && _arrivee != null) _computeRoute();
                      },
                    ),
                    const SizedBox(width: 6),
                    _VehicleToggle(
                      icon: Icons.directions_car_filled_rounded,
                      label: 'Voiture',
                      selected: _vehicle == 'car',
                      onTap: () {
                        setState(() => _vehicle = 'car');
                        if (_depart != null && _arrivee != null) _computeRoute();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ---- Estimation ----
          Positioned(
            left: 12,
            right: 12,
            bottom: 160 + padBot,
            child: _EstimationCard(
              vehicle: _vehicle,
              distanceKm: _distanceKm,
              durationMin: _durationMin,
              priceGNF: _priceGNF,
              routing: _routing,
            ),
          ),

          // ---- Boutons Recalculer / Effacer ----
          Positioned(
            left: 12,
            right: 12,
            bottom: 110 + padBot,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_depart != null && _arrivee != null && !_routing) ? _computeRoute : null,
                    icon: const Icon(Icons.route),
                    label: const Text('Recalculer'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _depart = null; _arrivee = null;
                      _departLabel = null; _arriveeLabel = null;
                      _departCtrl.clear(); _arriveeCtrl.clear();
                      _routePoints = []; _distanceKm = null; _durationMin = null; _priceGNF = null;
                    });
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Effacer'),
                ),
              ],
            ),
          ),

          // ---- CONFIRMER (création) ----
          Positioned(
            left: 12,
            right: 12,
            bottom: 60 + padBot,
            child: SafeArea(
              top: false,
              child: ElevatedButton.icon(
                onPressed: _creating ? null : _createCourse,
                icon: const Icon(Icons.play_arrow),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  backgroundColor: const Color(0xFF15A05D),
                  foregroundColor: Colors.white,
                ),
                label: Text(_creating ? 'Création…' : 'Créer la demande',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ),

          // ---- Dock ----
          Positioned(
            left: 12,
            right: 12,
            bottom: 12 + padBot,
            child: _Glass(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _DockButton(
                      icon: Icons.person,
                      label: 'Moi',
                      onTap: () => _openDock(_BottomTab.profil),
                    ),
                    const _DockDivider(),
                    _DockButton(
                      icon: Icons.history,
                      label: 'Historique',
                      onTap: () => _openDock(_BottomTab.historique),
                    ),
                    const _DockDivider(),
                    _DockButton(
                      icon: Icons.account_balance_wallet,
                      label: 'Paiements',
                      onTap: () => _openDock(_BottomTab.paiement),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Widgets ----------
  Widget _searchPill({
    required String label,
    required TextEditingController controller,
    required bool selected,
    required VoidCallback onTap,
    required void Function(_Lieu) onSelected,
  }) {
    return _Glass(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [kGuineaRed, kGuineaYellow, kGuineaGreen],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Icon(label == 'Départ' ? Icons.place : Icons.flag, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: onTap,
                child: TypeAheadField<_Lieu>(
                  hideOnEmpty: true,
                  hideOnUnfocus: true,
                  debounceDuration: const Duration(milliseconds: 220),
                  controller: controller,
                  suggestionsCallback: _searchLieux,
                  builder: (context, ctrl, focus) {
                    return TextField(
                      controller: ctrl,
                      focusNode: focus,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: label == 'Départ'
                            ? '… (quartier, carrefour, commune, ville)'
                            : 'Destination…',
                        hintStyle: const TextStyle(color: Colors.black54),
                      ),
                      onTap: onTap,
                      onChanged: (_) => onTap(),
                      onEditingComplete: () => _applyFreeText(depart: label == 'Départ'),
                      onSubmitted: (_) => _applyFreeText(depart: label == 'Départ'),
                    );
                  },
                  itemBuilder: (context, _Lieu l) => ListTile(
                    dense: true,
                    title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(l.meta),
                  ),
                  onSelected: onSelected,
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: selected ? Colors.black : Colors.black26,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundGlass({required IconData icon, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withOpacity(.75),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, size: 22),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Dock ----------
  void _openDock(_BottomTab tab) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DockSheet(
        tab: tab,
        user: _user,
        recent: _recent,
        loadingRecent: _loadingRecent,
        loadingPayments: _loadingPayments,
        paymentMethods: _lastPayments,
        onRefreshProfile: _refreshUserFromSupabase,
        onRefreshHistory: _loadRecent,
        onRefreshPayments: _loadLastPayments,
        onEditProfile: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Brancher la page Profil ici.')),
          );
        },
      ),
    );
  }
}

// ---------- Glass ----------
class _Glass extends StatelessWidget {
  final Widget child;
  const _Glass({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 0.8),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ---------- Dock widgets ----------
class _DockButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DockButton({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _DockDivider extends StatelessWidget {
  const _DockDivider();
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 26, color: Colors.black12);
}

// ---------- Toggle véhicule ----------
class _VehicleToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _VehicleToggle({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selColor = selected ? kGuineaGreen : Colors.black87;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selColor),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: selColor, fontWeight: FontWeight.w600)),
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle, size: 16, color: kGuineaGreen),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------- Estimation ----------
class _EstimationCard extends StatelessWidget {
  final String vehicle;
  final double? distanceKm;
  final int? durationMin;
  final int? priceGNF;
  final bool routing;

  const _EstimationCard({
    required this.vehicle,
    required this.distanceKm,
    required this.durationMin,
    required this.priceGNF,
    required this.routing,
  });

  @override
  Widget build(BuildContext context) {
    final icon = vehicle == 'moto' ? Icons.two_wheeler : Icons.directions_car;
    return _Glass(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Icon(icon, size: 26, color: kGuineaGreen),
            const SizedBox(width: 10),
            Expanded(
              child: routing
                  ? const Text('Calcul de l’itinéraire…')
                  : Text(
                      (distanceKm != null && durationMin != null)
                          ? '~ ${distanceKm!.toStringAsFixed(2)} km • ${durationMin!} min'
                          : 'Sélectionnez départ et destination…',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
            Text(priceGNF != null ? '${priceGNF!} GNF' : '—',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

// ---------- Modèle Lieu ----------
class _Lieu {
  final String id;
  final String name;
  final String type; // quartier / carrefour / commune / ville / lieu
  final String? city;
  final String? commune;
  final double lat;
  final double lng;

  _Lieu({
    required this.id,
    required this.name,
    required this.type,
    required this.lat,
    required this.lng,
    this.city,
    this.commune,
  });

  String get meta {
    final parts = <String>[];
    if (type.isNotEmpty) parts.add(type);
    if (commune != null && commune!.isNotEmpty) parts.add(commune!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    return parts.join(' • ');
  }

  String get fullLabel {
    final parts = <String>[name];
    if (commune != null && commune!.isNotEmpty) parts.add(commune!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    return parts.join(', ');
  }

  factory _Lieu.fromMap(Map<String, dynamic> m) => _Lieu(
        id: m['id'].toString(),
        name: m['name']?.toString() ?? '-',
        type: m['type']?.toString() ?? '',
        city: m['city']?.toString(),
        commune: m['commune']?.toString(),
        lat: (m['lat'] is num) ? (m['lat'] as num).toDouble() : double.parse(m['lat'].toString()),
        lng: (m['lng'] is num) ? (m['lng'] as num).toDouble() : double.parse(m['lng'].toString()),
      );
}

// ---------- Bottom sheet (profil / historique / paiements) ----------
class _DockSheet extends StatelessWidget {
  final _BottomTab tab;
  final UtilisateurModel user;
  final List<Map<String, dynamic>> recent;
  final bool loadingRecent;

  final bool loadingPayments;
  final List<Map<String, dynamic>> paymentMethods;

  final Future<void> Function() onRefreshProfile;
  final Future<void> Function() onRefreshHistory;
  final Future<void> Function() onRefreshPayments;
  final VoidCallback onEditProfile;

  const _DockSheet({
    required this.tab,
    required this.user,
    required this.recent,
    required this.loadingRecent,
    required this.loadingPayments,
    required this.paymentMethods,
    required this.onRefreshProfile,
    required this.onRefreshHistory,
    required this.onRefreshPayments,
    required this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    final radius = const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    );
    return Material(
      shape: radius,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          color: Colors.white,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: _content(context),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    switch (tab) {
      case _BottomTab.profil:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text('Mon profil',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  tooltip: 'Rafraîchir',
                  onPressed: onRefreshProfile,
                  icon: const Icon(Icons.refresh),
                )
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.shade100,
                child: const Icon(Icons.person, color: Colors.black87),
              ),
              title: Text(
                ('${user.prenom ?? ''} ${user.nom ?? ''}').trim().isEmpty
                    ? 'Client'
                    : '${user.prenom ?? ''} ${user.nom ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(user.email ?? user.telephone ?? '—'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.phone_iphone),
              title: const Text('Téléphone'),
              subtitle: Text(user.telephone ?? '—'),
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              subtitle: Text(user.email ?? '—'),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Modifier mon profil'),
                onPressed: onEditProfile,
              ),
            ),
          ],
        );

      case _BottomTab.historique:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text('Historique récent',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  onPressed: onRefreshHistory,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualiser',
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (loadingRecent)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (recent.isEmpty)
              const Card(child: ListTile(title: Text('Aucune course récente')))
            else
              ...recent.map((c) {
                final prix = c['prix_gnf'];
                return Card(
                  elevation: 0,
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.local_taxi)),
                    title: Text('${c['depart_adresse'] ?? '-'} → ${c['arrivee_adresse'] ?? '-'}'),
                    subtitle: Text('Statut: ${c['statut']}'),
                    trailing: Text(prix != null ? '$prix GNF' : '—'),
                  ),
                );
              }),
          ],
        );

      case _BottomTab.paiement:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text('Paiements',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  tooltip: 'Rafraîchir',
                  onPressed: onRefreshPayments,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (loadingPayments)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (paymentMethods.isEmpty)
              Card(
                elevation: 0,
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet),
                  title: const Text('Aucun paiement trouvé'),
                  subtitle: Text(
                    (user.telephone != null && user.telephone!.isNotEmpty)
                        ? 'Mobile Money suggéré • ${user.telephone}'
                        : 'Ajoute un moyen de paiement dans ton profil',
                  ),
                  trailing: const Text('—'),
                ),
              )
            else
              ...paymentMethods.map((m) {
                final moyen = (m['moyen'] ?? '').toString();
                final statut = (m['statut'] ?? '').toString();
                final amount = m['amount_gnf'];
                final createdAt = (m['created_at'] ?? '').toString();
                return Card(
                  elevation: 0,
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: Text('${amount ?? '—'} GNF'),
                    subtitle: Text('$moyen • $statut\n$createdAt'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              }),
            const SizedBox(height: 8),
            const Text(
              'Astuce : lie Orange Money / MTN / Free pour payer plus vite.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        );
    }
  }

  Widget _sheetHandle() => Center(
        child: Container(
          width: 44,
          height: 5,
          margin: const EdgeInsets.only(top: 6, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
}
