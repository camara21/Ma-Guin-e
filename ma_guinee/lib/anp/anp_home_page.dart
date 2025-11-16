import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

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

// Modèle pour une étape de navigation
class _NavStep {
  final String instruction;
  final double distanceMeters;
  final double durationSec;
  final LatLng location;
  final String type;
  final String modifier;
  final String name;

  const _NavStep({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSec,
    required this.location,
    required this.type,
    required this.modifier,
    required this.name,
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
  final Distance _distanceCalc = const Distance();

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

  // Stream de localisation pendant la navigation
  StreamSubscription<Position>? _positionSub;

  // Recherche (barre en bas)
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Résultat de recherche ANP (marqueur sur la carte)
  LatLng? _searchedAnpPoint;
  String? _lastSearchedCode;
  String? _lastSearchedLabel;
  String? _lastSearchedNiceName;
  bool _lastIsEntreprise = false;

  // Itinéraire détaillé
  LatLng? _routeStart;
  LatLng? _routeEnd;
  List<LatLng> _routePoints = [];
  bool _routeLoading = false;

  // Segments de la polyline
  List<double> _routeSegmentDistances = [];
  double? _routePolylineDistanceMeters;

  // Temps & distance totales (OSRM)
  double? _routeDurationSec;
  double? _routeDistanceMeters;

  // Liste d'étapes
  List<_NavStep> _navSteps = [];
  int _currentStepIndex = 0;

  // Bearing (même si on ne l'affiche plus, on le garde pour plus tard)
  double? _routeBearingDeg;

  // Historique mémoire
  final List<_RecentRoute> _recentRoutes = [];

  // Navigation interne (Soneya)
  bool _internalNavActive = false;

  bool get _hasAnp => _anpCode != null && _anpCode!.isNotEmpty;
  bool get _hasRoute => _routeStart != null && _routeEnd != null;

  _NavStep? get _currentStep =>
      (_navSteps.isNotEmpty && _currentStepIndex < _navSteps.length)
          ? _navSteps[_currentStepIndex]
          : null;

  // ─────────── Helpers temps / distance / trafic ───────────

  double? get _remainingDistanceMeters {
    if (_routePoints.length < 2) {
      return _routeDistanceMeters ?? _routePolylineDistanceMeters;
    }
    if (_position == null) {
      return _routeDistanceMeters ?? _routePolylineDistanceMeters;
    }
    if (_routePolylineDistanceMeters == null ||
        _routePolylineDistanceMeters! <= 0) {
      return _routeDistanceMeters;
    }

    final cur = LatLng(_position!.latitude, _position!.longitude);

    int nearestIdx = 0;
    double bestD = double.infinity;
    for (int i = 0; i < _routePoints.length; i++) {
      final d = _distanceCalc(cur, _routePoints[i]);
      if (d < bestD) {
        bestD = d;
        nearestIdx = i;
      }
    }

    double remaining = bestD;
    for (int k = nearestIdx; k < _routeSegmentDistances.length; k++) {
      remaining += _routeSegmentDistances[k];
    }

    return remaining;
  }

  double? get _remainingDurationSecBase {
    if (_routeDurationSec == null) return null;
    if (_routePolylineDistanceMeters == null ||
        _routePolylineDistanceMeters! <= 0) {
      return _routeDurationSec;
    }

    final remDist = _remainingDistanceMeters;
    if (remDist == null) return _routeDurationSec;

    final ratio = (remDist / _routePolylineDistanceMeters!)
        .clamp(0.0, 1.0);

    return _routeDurationSec! * ratio;
  }

  // marge trafic (~ +15% + 3 min)
  double? get _remainingDurationSecTraffic {
    final base = _remainingDurationSecBase;
    if (base == null) return null;
    return base * 1.15 + 180;
  }

  String? get _formattedRemainingTime {
    final s = _remainingDurationSecTraffic;
    if (s == null) return null;
    final d = Duration(seconds: s.round());
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) {
      return '$h h ${m.toString().padLeft(2, '0')} min';
    }
    return '$m min';
  }

  String? get _formattedRemainingDistance {
    final meters = _remainingDistanceMeters ?? _routeDistanceMeters;
    if (meters == null) return null;
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  String _formatStepDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  String? get _etaClockString {
    final s = _remainingDurationSecTraffic;
    if (s == null) return null;
    final eta = DateTime.now().add(Duration(seconds: s.round()));
    final hh = eta.hour.toString().padLeft(2, '0');
    final mm = eta.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  double _computeBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180.0;
    final lon1 = from.longitude * math.pi / 180.0;
    final lat2 = to.latitude * math.pi / 180.0;
    final lon2 = to.longitude * math.pi / 180.0;

    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x);
    final brngDeg = (brng * 180.0 / math.pi + 360.0) % 360.0;
    return brngDeg;
  }

  String _formatInstruction(String type, String modifier, String name) {
    final hasRoad = name.trim().isNotEmpty;
    final road = hasRoad ? ' sur $name' : '';

    switch (type) {
      case 'depart':
        return hasRoad ? 'Commencez sur $name' : 'Commencez le trajet';
      case 'arrive':
        return 'Vous êtes arrivé${hasRoad ? ' à destination' : ''}';
      case 'roundabout':
        return 'Au rond-point, continuez$road';
      case 'merge':
        return 'Rejoignez la voie$road';
      case 'on ramp':
        return 'Prenez la bretelle$road';
      case 'off ramp':
        return 'Prenez la sortie$road';
      case 'fork':
        return 'Tenez la direction indiquée$road';
      case 'continue':
        return 'Continuez tout droit$road';
      case 'turn':
      default:
        switch (modifier) {
          case 'left':
            return 'Tournez à gauche$road';
          case 'right':
            return 'Tournez à droite$road';
          case 'slight right':
            return 'Tournez légèrement à droite$road';
          case 'slight left':
            return 'Tournez légèrement à gauche$road';
          case 'sharp right':
            return 'Tournez franchement à droite$road';
          case 'sharp left':
            return 'Tournez franchement à gauche$road';
          case 'uturn':
            return 'Faites demi-tour$road';
          case 'straight':
            return 'Continuez tout droit$road';
          default:
            return 'Continuez$road';
        }
    }
  }

  // 👉 icône pour la flèche de direction (haut)
  IconData _stepIcon(_NavStep s) {
    final m = s.modifier.toLowerCase();
    if (m.contains('uturn')) {
      return Icons.rotate_left; // demi-tour
    } else if (m.contains('left')) {
      return Icons.turn_left; // flèche gauche longue
    } else if (m.contains('right')) {
      return Icons.turn_right; // flèche droite longue
    } else {
      return Icons.straight; // tout droit
    }
  }

  void _updateCurrentStep() {
    if (!_internalNavActive) return;
    if (_position == null) return;
    if (_navSteps.isEmpty) return;

    final current = LatLng(_position!.latitude, _position!.longitude);

    int bestIndex = _currentStepIndex;
    double bestDist = double.infinity;

    for (var i = _currentStepIndex; i < _navSteps.length; i++) {
      final d = _distanceCalc(current, _navSteps[i].location);
      if (d < bestDist) {
        bestDist = d;
        bestIndex = i;
      }
    }

    if (bestDist < 25 && bestIndex < _navSteps.length - 1) {
      bestIndex++;
    }

    if (bestIndex != _currentStepIndex) {
      setState(() {
        _currentStepIndex = bestIndex;
        _routeBearingDeg =
            _computeBearing(current, _navSteps[bestIndex].location);
      });
    }
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

      // comme l'ancien code : on récupère seulement le champ code
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

  // ───────────────── Calcul itinéraire sur vraie route (OSRM) ─────────────────
  Future<void> _calculerItineraireRoute(LatLng start, LatLng end) async {
    setState(() {
      _routeLoading = true;
      _routePoints = [];
      _routeDurationSec = null;
      _routeDistanceMeters = null;
      _routeSegmentDistances = [];
      _routePolylineDistanceMeters = null;
      _routeBearingDeg = null;
      _navSteps = [];
      _currentStepIndex = 0;
    });

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson&steps=true',
      );

      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route0 = routes[0] as Map<String, dynamic>;
          final geometry = route0['geometry'] as Map<String, dynamic>;
          final coords = geometry['coordinates'] as List<dynamic>;

          final points = coords.map<LatLng>((c) {
            final list = (c as List);
            final double lon = (list[0] as num).toDouble();
            final double lat = (list[1] as num).toDouble();
            return LatLng(lat, lon);
          }).toList();

          final List<double> seg = [];
          double sum = 0;
          for (int i = 0; i < points.length - 1; i++) {
            final d = _distanceCalc(points[i], points[i + 1]);
            seg.add(d);
            sum += d;
          }

          final double? durationSec =
              (route0['duration'] as num?)?.toDouble();
          final double? distanceMeters =
              (route0['distance'] as num?)?.toDouble();

          final List<_NavStep> stepsList = [];
          final legs = (route0['legs'] as List?) ?? [];
          if (legs.isNotEmpty) {
            final leg0 = legs[0] as Map<String, dynamic>;
            final legSteps = leg0['steps'] as List<dynamic>?;
            if (legSteps != null) {
              for (final s in legSteps) {
                final step = s as Map<String, dynamic>;
                final maneuver =
                    (step['maneuver'] as Map<String, dynamic>?) ?? {};
                final loc = maneuver['location'] as List<dynamic>?;
                LatLng? stepPoint;
                if (loc != null && loc.length >= 2) {
                  final double lon = (loc[0] as num).toDouble();
                  final double lat = (loc[1] as num).toDouble();
                  stepPoint = LatLng(lat, lon);
                }
                final type = (maneuver['type'] as String?) ?? '';
                final modifier = (maneuver['modifier'] as String?) ?? '';
                final name = (step['name'] as String?) ?? '';
                final distance =
                    (step['distance'] as num?)?.toDouble() ?? 0.0;
                final duration =
                    (step['duration'] as num?)?.toDouble() ?? 0.0;
                final instr = _formatInstruction(type, modifier, name);

                if (stepPoint != null) {
                  stepsList.add(
                    _NavStep(
                      instruction: instr,
                      distanceMeters: distance,
                      durationSec: duration,
                      location: stepPoint,
                      type: type,
                      modifier: modifier,
                      name: name,
                    ),
                  );
                }
              }
            }
          }

          double? bearingDeg;
          if (stepsList.isNotEmpty) {
            bearingDeg = _computeBearing(start, stepsList.first.location);
          } else if (points.length >= 2) {
            bearingDeg = _computeBearing(points.first, points[1]);
          } else {
            bearingDeg = _computeBearing(start, end);
          }

          if (mounted) {
            setState(() {
              _routePoints = points;
              _routeSegmentDistances = seg;
              _routePolylineDistanceMeters = sum > 0 ? sum : null;
              _routeDurationSec = durationSec;
              _routeDistanceMeters = distanceMeters;
              _navSteps = stepsList;
              _currentStepIndex = 0;
              _routeBearingDeg = bearingDeg;
            });
          }
        }
      }

      if (mounted && _routePoints.isEmpty) {
        final d = _distanceCalc(start, end);
        setState(() {
          _routePoints = [start, end];
          _routeSegmentDistances = [d];
          _routePolylineDistanceMeters = d;
          _routeDurationSec ??= d / 13.9; // ~50 km/h
          _routeDistanceMeters ??= d;
          _routeBearingDeg = _computeBearing(start, end);
          _navSteps = [];
          _currentStepIndex = 0;
        });
      }
    } catch (_) {
      if (mounted) {
        final d = _distanceCalc(start, end);
        setState(() {
          _routePoints = [start, end];
          _routeSegmentDistances = [d];
          _routePolylineDistanceMeters = d;
          _routeDurationSec ??= d / 13.9;
          _routeDistanceMeters ??= d;
          _routeBearingDeg = _computeBearing(start, end);
          _navSteps = [];
          _currentStepIndex = 0;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _routeLoading = false);
      }
    }
  }

  // ───────────────── Réinitialiser la destination ─────────────────
  void _clearDestination() {
    _positionSub?.cancel();
    _positionSub = null;

    setState(() {
      _searchedAnpPoint = null;
      _lastSearchedCode = null;
      _lastSearchedLabel = null;
      _lastSearchedNiceName = null;
      _lastIsEntreprise = false;
      _routeStart = null;
      _routeEnd = null;
      _routePoints = [];
      _routeSegmentDistances = [];
      _routePolylineDistanceMeters = null;
      _routeDurationSec = null;
      _routeDistanceMeters = null;
      _routeBearingDeg = null;
      _navSteps = [];
      _currentStepIndex = 0;
      _internalNavActive = false;
    });
  }

  // ───────────────── Feuille avec la liste des étapes ─────────────────
  void _showStepsSheet() {
    if (_navSteps.isEmpty) return;

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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.list_alt_outlined, color: _primaryBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lastSearchedNiceName ??
                            _lastSearchedLabel ??
                            'Itinéraire',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _titleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: _navSteps.length,
                  itemBuilder: (ctx, index) {
                    final s = _navSteps[index];
                    final isCurrent = index == _currentStepIndex;
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor:
                            isCurrent ? _primaryBlue : Colors.grey.shade300,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isCurrent ? Colors.white : _titleColor,
                            fontWeight:
                                isCurrent ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                      title: Text(
                        s.instruction,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isCurrent ? FontWeight.w700 : FontWeight.w500,
                          color: _titleColor,
                        ),
                      ),
                      subtitle: Text(
                        _formatStepDistance(s.distanceMeters),
                        style: const TextStyle(
                          fontSize: 12,
                          color: _subtitleColor,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _mapController.move(s.location, 18);
                        setState(() {
                          _currentStepIndex = index;
                          _routeBearingDeg =
                              _computeBearing(_routeStart ?? s.location,
                                  s.location);
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ───────────────── Recherche ANP ─────────────────
  Future<void> _rechercherAnp(String value) async {
    final code = value.trim().toUpperCase();
    if (code.isEmpty) return;

    try {
      Map<String, dynamic>? found;
      bool isEntreprise = false;
      String label = "ANP $code";
      String niceName = '';

      // 1) ANP perso
      found = await _supabase
          .from('anp_adresses')
          .select('code, latitude, longitude, user_id')
          .eq('code', code)
          .maybeSingle();

      if (found == null) {
        final list = await _supabase
            .from('anp_adresses')
            .select('code, latitude, longitude, user_id')
            .ilike('code', code)
            .limit(1);
        if (list is List && list.isNotEmpty) {
          found = list.first as Map<String, dynamic>;
        }
      }

      if (found != null) {
        final userId = found['user_id'] as String?;
        if (userId != null && userId.isNotEmpty) {
          final userRow = await _supabase
              .from('utilisateurs')
              .select('prenom, nom')
              .eq('id', userId)
              .maybeSingle();

          if (userRow != null) {
            final prenom = (userRow['prenom'] as String?)?.trim() ?? '';
            final nom = (userRow['nom'] as String?)?.trim() ?? '';
            if (prenom.isNotEmpty && nom.isNotEmpty) {
              niceName = '$prenom $nom';
            } else if (prenom.isNotEmpty || nom.isNotEmpty) {
              niceName = (prenom + ' ' + nom).trim();
            }
          }
        }

        if (niceName.isNotEmpty) {
          label = '$niceName ($code)';
        }
      }

      // 2) ANP entreprise
      if (found == null) {
        final site = await _supabase
            .from('anp_entreprise_sites')
            .select('code, latitude, longitude, nom_site')
            .eq('code', code)
            .maybeSingle();

        if (site != null) {
          found = site;
          isEntreprise = true;

          final nomSite = (site['nom_site'] as String?) ?? '';
          if (nomSite.isNotEmpty) {
            niceName = nomSite.trim();
            label = '$niceName ($code)';
          }
        }
      }

      if (found == null) {
        if (!mounted) return;
        setState(() {
          _searchedAnpPoint = null;
          _routeStart = null;
          _routeEnd = null;
          _routePoints = [];
          _routeSegmentDistances = [];
          _routePolylineDistanceMeters = null;
          _lastSearchedCode = null;
          _lastSearchedLabel = null;
          _lastSearchedNiceName = null;
          _lastIsEntreprise = false;
          _routeDurationSec = null;
          _routeDistanceMeters = null;
          _routeBearingDeg = null;
          _navSteps = [];
          _currentStepIndex = 0;
          _internalNavActive = false;
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

      _lastIsEntreprise = isEntreprise;

      setState(() {
        _center = point;
        _zoom = 17;
        _searchedAnpPoint = point;
        _lastSearchedCode = found!['code']?.toString() ?? code;
        _lastSearchedLabel = label;
        _lastSearchedNiceName =
            niceName.isNotEmpty ? niceName : label;
        _internalNavActive = false;

        if (_position != null) {
          _routeStart = LatLng(_position!.latitude, _position!.longitude);
          _routeEnd = point;
        } else {
          _routeStart = null;
          _routeEnd = null;
        }

        _routePoints = [];
        _routeSegmentDistances = [];
        _routePolylineDistanceMeters = null;
        _routeDurationSec = null;
        _routeDistanceMeters = null;
        _routeBearingDeg = null;
        _navSteps = [];
        _currentStepIndex = 0;
      });

      _mapController.move(point, 17);

      if (_routeStart != null && _routeEnd != null) {
        await _calculerItineraireRoute(_routeStart!, _routeEnd!);
      }

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

  // ───────────────── Navigation interne Soneya ─────────────────
  void _lancerNavigationInterne() {
    // si pas de localisation : on affiche un message et on ne démarre pas
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Merci d’activer votre géolocalisation pour démarrer la navigation dans Soneya.",
          ),
        ),
      );
      return;
    }

    if (!_hasRoute || _routePoints.isNotEmpty == false) return;

    if (_routeStart != null) {
      _mapController.move(_routeStart!, 18);
    }

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() {
        _position = pos;
      });
      _updateCurrentStep();
    });

    setState(() {
      _internalNavActive = true;
    });
  }

  void _arreterNavigationInterne() {
    _positionSub?.cancel();
    _positionSub = null;

    setState(() {
      _internalNavActive = false;
    });
  }

  Future<void> _demarrerNavigation() async {
    if (_searchedAnpPoint == null) return;

    final dest = _searchedAnpPoint!;
    final destLabel =
        _lastSearchedNiceName ?? _lastSearchedLabel ?? 'cette adresse ANP';

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
                "Aller à l’adresse de",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: _subtitleColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                destLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: _titleColor,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Choisissez comment démarrer le trajet",
                style: TextStyle(
                  fontSize: 13,
                  color: _subtitleColor,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading:
                    const Icon(Icons.navigation_outlined, color: _primaryBlue),
                title: const Text("Naviguer dans Soneya"),
                subtitle: const Text(
                  "Suivre l’itinéraire directement sur cette carte",
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _lancerNavigationInterne();
                },
              ),
              const Divider(height: 1),
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

  // ───────────────── init / dispose ─────────────────
  @override
  void initState() {
    super.initState();
    _searchController.text = '';
    _chargerAnp();
    _getLocation();
    _chargerMaisonTravail();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _positionSub?.cancel();
    super.dispose();
  }

  // ───────────────── UI principale ─────────────────
  @override
  Widget build(BuildContext context) {
    final hasAnp = _hasAnp;
    final currentStep = _currentStep;

    double? distanceToNextStep;
    if (currentStep != null && _position != null) {
      final cur = LatLng(_position!.latitude, _position!.longitude);
      distanceToNextStep = _distanceCalc(cur, currentStep.location);
    }

    final eta = _etaClockString;
    final remainTime = _formattedRemainingTime;
    final remainDistance = _formattedRemainingDistance;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _buildDrawer(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: null,
      body: Stack(
        children: [
          // Carte
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
                    if (_position != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              _position!.latitude,
                              _position!.longitude,
                            ),
                            width: 52,
                            height: 52,
                            child: _UserPositionMarker(
                              isHome: _lastSearchedCode != null &&
                                  _homeAnpCode != null &&
                                  _lastSearchedCode == _homeAnpCode,
                            ),
                          ),
                        ],
                      ),
                    if (_hasRoute && _routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 8,
                            color: _primaryBlue.withOpacity(0.9),
                          ),
                        ],
                      ),
                    if (_searchedAnpPoint != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _searchedAnpPoint!,
                            width: 46,
                            height: 46,
                            child:
                                _DestinationMarker(isEntreprise: _lastIsEntreprise),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Header normal descendu (quand pas en nav interne)
          if (!_internalNavActive)
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
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

          // Bandeau de navigation Waze en haut (flèche longue + texte)
          if (_internalNavActive && currentStep != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: true,
                bottom: false,
                minimum: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _stepIcon(currentStep),
                        size: 34,
                        color: _primaryBlue,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                if (distanceToNextStep != null)
                                  _formatStepDistance(distanceToNextStep),
                                if (currentStep.name.isNotEmpty)
                                  currentStep.name,
                              ].join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _titleColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentStep.instruction,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (_navSteps.isNotEmpty)
                        IconButton(
                          onPressed: _showStepsSheet,
                          icon: const Icon(
                            Icons.list_alt_outlined,
                            size: 20,
                            color: _titleColor,
                          ),
                        ),
                      TextButton.icon(
                        onPressed: _arreterNavigationInterne,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          foregroundColor: Colors.red[700],
                        ),
                        icon: const Icon(Icons.stop, size: 16),
                        label: const Text(
                          "Arrêter",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Carte d’adresse + bouton Démarrer (et croix pour effacer la destination)
          if (_searchedAnpPoint != null && !_internalNavActive)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).size.height * 0.30 + 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_lastSearchedNiceName != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Prêt à partir ?",
                                style: TextStyle(
                                  color: _subtitleColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Aller à l’adresse de",
                                style: TextStyle(
                                  color: _subtitleColor,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _lastSearchedNiceName!,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: _titleColor,
                                ),
                              ),
                              if (_lastSearchedCode != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _lastSearchedCode!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _subtitleColor,
                                  ),
                                ),
                              ],
                              if (_routeLoading) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: const [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          _primaryBlue,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      "Calcul de l’itinéraire sur la route…",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _subtitleColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if (remainTime != null ||
                                  remainDistance != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.directions_car_filled,
                                      size: 16,
                                      color: _primaryBlue,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      [
                                        if (remainTime != null) remainTime,
                                        if (remainDistance != null)
                                          remainDistance,
                                      ].join(' • '),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _subtitleColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: _subtitleColor,
                              ),
                              onPressed: _clearDestination,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  Center(
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
                        elevation: 6,
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
                ],
              ),
            ),

          // Barre du bas collée comme Waze : heure d’arrivée + temps + distance (sans flèche)
          if (_internalNavActive && (eta != null || remainTime != null))
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (eta != null)
                        Text(
                          eta,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: _titleColor,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (remainTime != null) remainTime,
                          if (remainDistance != null) remainDistance,
                        ].join(' • '),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom sheet principale (hors navigation)
          if (!_internalNavActive)
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
                        Row(
                          children: [
                            Expanded(
                              child: _HomeWorkTile(
                                icon: Icons.home_outlined,
                                label: 'Maison',
                                code: _homeAnpCode,
                                accentColor: _primaryBlue,
                                showCode: false,
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
                                onEdit: () =>
                                    _editerMaisonTravail(maison: true),
                                helperText: _homeAnpCode != null
                                    ? 'Maison enregistrée'
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
                                showCode: true,
                                onTap: () {
                                  if (_workAnpCode != null &&
                                      _workAnpCode!.isNotEmpty) {
                                    _allerVersMaisonOuTravail(_workAnpCode!);
                                  } else {
                                    _editerMaisonTravail(maison: false);
                                  }
                                },
                                onEdit: () =>
                                    _editerMaisonTravail(maison: false),
                                helperText: _workAnpCode != null
                                    ? 'Aller au travail'
                                    : 'Ajouter une ANP travail',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
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

// ───────────────── Marqueurs persos ─────────────────

class _UserPositionMarker extends StatelessWidget {
  final bool isHome;

  const _UserPositionMarker({required this.isHome});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.navigation,
            size: 26,
            color: _primaryBlue,
          ),
        ),
        if (isHome)
          Positioned(
            bottom: -4,
            right: -4,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _primaryBlue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.home,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

class _DestinationMarker extends StatelessWidget {
  final bool isEntreprise;

  const _DestinationMarker({required this.isEntreprise});

  @override
  Widget build(BuildContext context) {
    final iconData = isEntreprise ? Icons.business : Icons.home;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(color: _primaryBlue, width: 3),
          ),
          child: Icon(
            iconData,
            color: _primaryBlue,
            size: 22,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: _primaryBlue,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}

// ───────────────── Tuile Maison / Travail ─────────────────
class _HomeWorkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? code;
  final Color accentColor;
  final bool showCode;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final String helperText;

  const _HomeWorkTile({
    required this.icon,
    required this.label,
    required this.code,
    required this.accentColor,
    required this.showCode,
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
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: _subtitleColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (hasCode && showCode)
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
    final code = value.trim().toUpperCase();
    if (code.isEmpty) return;
    widget.onSelectCode(code);
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

// Icônes catégories
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
