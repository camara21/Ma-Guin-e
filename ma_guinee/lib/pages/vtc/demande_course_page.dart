// lib/pages/vtc/demande_course_page.dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:http/http.dart' as http;
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/utilisateur_model.dart';
import '../../routes.dart';

class DemandeCoursePage extends StatefulWidget {
  final UtilisateurModel currentUser;
  const DemandeCoursePage({super.key, required this.currentUser});

  @override
  State<DemandeCoursePage> createState() => _DemandeCoursePageState();
}

enum _MoveTarget { none, depart, arrivee }

class _DemandeCoursePageState extends State<DemandeCoursePage> {
  final _sb = Supabase.instance.client;

  // Carte
  final MapController _map = MapController();
  ll.LatLng _mapCenter = const ll.LatLng(9.6412, -13.5784); // Conakry
  double _zoom = 13;

  // Form
  String _vehicle = 'car'; // 'car' | 'moto'
  String _city = 'Conakry';

  final TextEditingController _departCtrl = TextEditingController();
  final TextEditingController _arriveeCtrl = TextEditingController();

  ll.LatLng? _pDepart;
  ll.LatLng? _pArrivee;

  double? _distanceKm;
  int? _durationMin;
  int? _priceGNF;

  // Itinéraire
  List<ll.LatLng> _routePoints = [];
  bool _routing = false;

  _MoveTarget _moveTarget = _MoveTarget.none;
  bool _creating = false;

  @override
  void dispose() {
    _departCtrl.dispose();
    _arriveeCtrl.dispose();
    super.dispose();
  }

  // ---------- Géocodage ----------
  Future<List<_Place>> _searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?format=json&limit=8&addressdetails=1'
      '&countrycodes=gn'
      '&city=${Uri.encodeComponent(_city)}'
      '&q=${Uri.encodeComponent(query)}',
    );

    final resp = await http.get(
      uri,
      headers: {'User-Agent': 'ma_guinee/1.0 (contact@example.com)'},
    );
    if (resp.statusCode != 200) return [];

    final List data = jsonDecode(resp.body);
    return data.map((e) => _Place.fromJson(e)).toList();
  }

  Future<_Place?> _geocodeOne(String text) async {
    final q = text.trim();
    if (q.isEmpty) return null;
    final list = await _searchPlaces(q);
    if (list.isEmpty) return null;
    final idx = list.indexWhere(
      (p) => p.displayName.toLowerCase().contains(_city.toLowerCase()),
    );
    return idx >= 0 ? list[idx] : list.first;
  }

  Future<void> _applyFreeText({required bool depart}) async {
    final text = depart ? _departCtrl.text : _arriveeCtrl.text;
    final p = await _geocodeOne(text);
    if (p == null) {
      _toast("Impossible de localiser « $text » à $_city.");
      return;
    }
    setState(() {
      final latlng = ll.LatLng(p.lat, p.lon);
      if (depart) {
        _pDepart = latlng;
        _map.move(latlng, 14);
      } else {
        _pArrivee = latlng;
        _map.move(latlng, 14);
      }
    });
    if (_pDepart != null && _pArrivee != null) {
      await _computeRoute();
    }
  }

  // ---------- Géolocalisation ----------
  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _toast("Service de localisation désactivé.");
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      _toast("Permission de localisation refusée.");
      return false;
    }
    if (perm == LocationPermission.deniedForever) {
      _toast("Permission refusée définitivement (réglages système).");
      return false;
    }
    return true;
  }

  Future<void> _centerOnUser({bool setAsDepart = false}) async {
    try {
      final ok = await _ensureLocationPermission();
      if (!ok) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final here = ll.LatLng(pos.latitude, pos.longitude);
      _map.move(here, 15);

      if (setAsDepart) {
        setState(() {
          _pDepart = here;
          _departCtrl.text = 'Ma position';
        });
        if (_pArrivee != null) {
          await _computeRoute();
        }
      }
    } catch (e) {
      _toast("Localisation impossible: $e");
    }
  }

  // ---------- Routage ----------
  Future<void> _computeRoute() async {
    final a = _pDepart;
    final b = _pArrivee;
    if (a == null || b == null) return;

    setState(() {
      _distanceKm = null;
      _durationMin = null;
      _priceGNF = null;
      _routing = true;
      _routePoints = [];
    });

    try {
      final profile = 'driving';
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/$profile'
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
          final km = (distMeters / 1000.0);
          final min = (durSeconds / 60.0);

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
    final min = (km / math.max(avgSpeedKmh, 5) * 60).clamp(3, 120).toDouble();

    setState(() => _routePoints = [a, b]);
    _applyEstimation(km, min);
    _fitMapToBounds(a, b);
  }

  void _applyEstimation(double km, double min) {
    final price = _estimatePrice(km, min);
    setState(() {
      _distanceKm = double.parse(km.toStringAsFixed(2));
      _durationMin = min.ceil();
      _priceGNF = price;
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
    final center = ll.LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2);
    _map.move(center, 13);
  }

  List<Marker> get _markers {
    final items = <Marker>[];
    if (_pDepart != null) {
      items.add(
        Marker(
          point: _pDepart!,
          width: 48,
          height: 48,
          child: const Icon(Icons.location_pin, color: Colors.red, size: 36),
        ),
      );
    }
    if (_pArrivee != null) {
      items.add(
        Marker(
          point: _pArrivee!,
          width: 48,
          height: 48,
          child: const Icon(Icons.flag, color: Colors.green, size: 30),
        ),
      );
    }
    return items;
  }

  // ---------- Création ----------
  Future<void> _createCourse() async {
    if (_pDepart == null && _departCtrl.text.trim().isNotEmpty) {
      await _applyFreeText(depart: true);
    }
    if (_pArrivee == null && _arriveeCtrl.text.trim().isNotEmpty) {
      await _applyFreeText(depart: false);
    }
    if (_pDepart != null && _pArrivee != null && (_distanceKm == null || _durationMin == null)) {
      await _computeRoute();
    }

    final a = _pDepart;
    final b = _pArrivee;
    final km = _distanceKm;
    final min = _durationMin;
    final price = _priceGNF;

    if (a == null || b == null || km == null || min == null || price == null) {
      _toast('Sélectionnez départ et destination');
      return;
    }

    setState(() => _creating = true);
    try {
      await _sb.from('courses').insert({
        'client_id': widget.currentUser.id,
        'status': 'pending',
        'vehicle': _vehicle == 'moto' ? 'moto' : 'car',
        'city': _city,
        'depart_label': _departCtrl.text.trim(),
        'arrivee_label': _arriveeCtrl.text.trim(),
        'depart_lat': a.latitude,
        'depart_lng': a.longitude,
        'arrivee_lat': b.latitude,
        'arrivee_lng': b.longitude,
        'distance_km': km,
        'duration_min': min,
        'price_estimated': price,
      });

      if (!mounted) return;
      Navigator.pop(context);
      _toast('Demande créée.');
    } catch (e) {
      if (!mounted) return;
      _toast('Échec création: $e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demande de course'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // --- Carte “glaciale” ---
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                SizedBox(
                  height: 260,
                  child: FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: _mapCenter,
                      initialZoom: _zoom,
                      onTap: (tapPos, latlng) async {
                        if (_moveTarget == _MoveTarget.depart) {
                          setState(() => _pDepart = latlng);
                          if (_pArrivee != null) await _computeRoute();
                        } else if (_moveTarget == _MoveTarget.arrivee) {
                          setState(() => _pArrivee = latlng);
                          if (_pDepart != null) await _computeRoute();
                        }
                      },
                      interactionOptions: const InteractionOptions(
                        flags: ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'com.example.ma_guinee',
                      ),
                      if (_routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(points: _routePoints, strokeWidth: 5, color: Colors.green),
                          ],
                        ),
                      MarkerLayer(markers: _markers),
                    ],
                  ),
                ),
                // Effet glass
                Positioned.fill(
                  child: IgnorePointer(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.06),
                              blurRadius: 22,
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Toggles véhicule
                Positioned(
                  top: 12,
                  left: 12,
                  child: _Glass(
                    child: Row(
                      children: [
                        _VehiclePill(
                          icon: Icons.two_wheeler,
                          label: 'Moto',
                          selected: _vehicle == 'moto',
                          onTap: () {
                            setState(() => _vehicle = 'moto');
                            if (_pDepart != null && _pArrivee != null) _computeRoute();
                          },
                        ),
                        _VehiclePill(
                          icon: Icons.directions_car_filled_rounded,
                          label: 'Voiture',
                          selected: _vehicle == 'car',
                          onTap: () {
                            setState(() => _vehicle = 'car');
                            if (_pDepart != null && _pArrivee != null) _computeRoute();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Boutons localisation
                Positioned(
                  top: 12,
                  right: 12,
                  child: _Glass(
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Localiser (centrer)',
                          onPressed: () => _centerOnUser(),
                          icon: const Icon(Icons.gps_fixed),
                        ),
                        IconButton(
                          tooltip: 'Départ = ma position',
                          onPressed: () => _centerOnUser(setAsDepart: true),
                          icon: const Icon(Icons.my_location),
                        ),
                      ],
                    ),
                  ),
                ),
                // Mode ajuster
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: _Glass(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Ajuster sur la carte', style: TextStyle(fontWeight: FontWeight.w600)),
                          ToggleButtons(
                            isSelected: [
                              _moveTarget == _MoveTarget.depart,
                              _moveTarget == _MoveTarget.arrivee,
                            ],
                            onPressed: (i) {
                              setState(() {
                                _moveTarget = i == 0
                                    ? (_moveTarget == _MoveTarget.depart ? _MoveTarget.none : _MoveTarget.depart)
                                    : (_moveTarget == _MoveTarget.arrivee ? _MoveTarget.none : _MoveTarget.arrivee);
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            children: const [
                              Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('Départ')),
                              Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('Arrivée')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Ville + raccourci "ma position"
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _city,
                  decoration: const InputDecoration(labelText: 'Ville'),
                  items: const [
                    DropdownMenuItem(value: 'Conakry', child: Text('Conakry')),
                    DropdownMenuItem(value: 'Kindia', child: Text('Kindia')),
                    DropdownMenuItem(value: 'Labé', child: Text('Labé')),
                    DropdownMenuItem(value: 'Kankan', child: Text('Kankan')),
                    DropdownMenuItem(value: 'N’Zérékoré', child: Text('N’Zérékoré')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _city = v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              _Glass(
                child: IconButton(
                  tooltip: 'Départ = ma position',
                  onPressed: () => _centerOnUser(setAsDepart: true),
                  icon: const Icon(Icons.my_location),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Recherche départ — utiliser TypeAheadField (v5)
          TypeAheadField<_Place>(
            suggestionsCallback: _searchPlaces,
            itemBuilder: (_, p) => ListTile(
              dense: true,
              title: Text(p.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${p.lat.toStringAsFixed(5)}, ${p.lon.toStringAsFixed(5)}'),
            ),
            onSelected: (p) {
              setState(() {
                _departCtrl.text = p.displayNameShort;
                _pDepart = ll.LatLng(p.lat, p.lon);
                _map.move(_pDepart!, 14);
              });
              if (_pArrivee != null) _computeRoute();
            },
            builder: (context, controller, focusNode) => TextField(
              controller: _departCtrl,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'Point de départ',
                prefixIcon: Icon(Icons.my_location),
              ),
              onEditingComplete: () => _applyFreeText(depart: true),
              onSubmitted: (_) => _applyFreeText(depart: true),
            ),
          ),
          const SizedBox(height: 10),

          // Recherche destination — TypeAheadField (v5)
          TypeAheadField<_Place>(
            suggestionsCallback: _searchPlaces,
            itemBuilder: (_, p) => ListTile(
              dense: true,
              title: Text(p.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${p.lat.toStringAsFixed(5)}, ${p.lon.toStringAsFixed(5)}'),
            ),
            onSelected: (p) {
              setState(() {
                _arriveeCtrl.text = p.displayNameShort;
                _pArrivee = ll.LatLng(p.lat, p.lon);
                _map.move(_pArrivee!, 14);
              });
              if (_pDepart != null) _computeRoute();
            },
            builder: (context, controller, focusNode) => TextField(
              controller: _arriveeCtrl,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'Destination',
                prefixIcon: Icon(Icons.place),
              ),
              onEditingComplete: () => _applyFreeText(depart: false),
              onSubmitted: (_) => _applyFreeText(depart: false),
            ),
          ),
          const SizedBox(height: 14),

          _EstimationCard(
            distanceKm: _distanceKm,
            durationMin: _durationMin,
            priceGNF: _priceGNF,
            vehicle: _vehicle,
            routing: _routing,
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_pDepart != null && _pArrivee != null) ? _computeRoute : null,
                  icon: const Icon(Icons.route),
                  label: const Text('Recalculer'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _creating ? null : _createCourse,
                  icon: const Icon(Icons.play_arrow),
                  label: _creating ? const Text('Création...') : const Text('Créer la demande'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _VehiclePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _VehiclePill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sel = selected ? Colors.green.shade700 : Colors.black87;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: sel),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: sel, fontWeight: FontWeight.w600)),
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle, size: 16, color: Colors.green),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------- Estimation ----------
class _EstimationCard extends StatelessWidget {
  final double? distanceKm;
  final int? durationMin;
  final int? priceGNF;
  final String vehicle;
  final bool routing;

  const _EstimationCard({
    required this.distanceKm,
    required this.durationMin,
    required this.priceGNF,
    required this.vehicle,
    required this.routing,
  });

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: th.dividerColor.withOpacity(.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Icon(vehicle == 'moto' ? Icons.two_wheeler : Icons.directions_car, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estimation', style: th.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  if (routing)
                    const Text('Calcul de l’itinéraire…')
                  else
                    Text(
                      (distanceKm != null && durationMin != null)
                          ? '~ ${distanceKm!.toStringAsFixed(2)} km • ${durationMin!} min'
                          : 'Sélectionnez départ et destination…',
                      style: th.textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              priceGNF != null ? '${priceGNF!.toString()} GNF' : '—',
              style: th.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Model ----------
class _Place {
  final double lat;
  final double lon;
  final String displayName;
  final String displayNameShort;

  _Place({
    required this.lat,
    required this.lon,
    required this.displayName,
    required this.displayNameShort,
  });

  factory _Place.fromJson(Map<String, dynamic> j) {
    final full = (j['display_name'] as String?) ?? '';
    final parts = full.split(',').map((e) => e.trim()).toList();
    String short = full;
    if (parts.isNotEmpty) {
      final head = parts.take(2).join(', ');
      short = head;
    }
    return _Place(
      lat: double.tryParse(j['lat']?.toString() ?? '') ?? 0,
      lon: double.tryParse(j['lon']?.toString() ?? '') ?? 0,
      displayName: full,
      displayNameShort: short,
    );
  }
}
