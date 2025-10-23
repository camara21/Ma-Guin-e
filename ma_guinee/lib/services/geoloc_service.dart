import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GeolocService {
  // ====== CONFIG / DEBOUNCE ======
  static const _prefsKeyLat = 'loc_last_sent_lat';
  static const _prefsKeyLon = 'loc_last_sent_lon';
  static const _prefsKeyTs  = 'loc_last_sent_ts';
  static const double _minMoveMeters = 200.0;           // min déplacement pour renvoyer
  static const Duration _minInterval = Duration(minutes: 30); // min délai entre envois

  static SupabaseClient get _sb => Supabase.instance.client;

  // ====== PERMISSIONS / POSITION ======
  /// Demande la permission si nécessaire.
  static Future<bool> checkPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
           permission == LocationPermission.whileInUse;
  }

  /// Obtient la position actuelle (HAUTE précision par défaut).
  static Future<Position?> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    final ok = await checkPermission();
    if (!ok || !await Geolocator.isLocationServiceEnabled()) return null;
    return Geolocator.getCurrentPosition(desiredAccuracy: accuracy);
  }

  /// Wrapper pratique : récupère la position **et** la pousse en base.
  /// Retourne la position (ou null si indisponible).
  static Future<Position?> getCurrentPositionAndReport({
    LocationAccuracy accuracy = LocationAccuracy.medium,
  }) async {
    final pos = await getCurrentPosition(accuracy: accuracy);
    if (pos != null) {
      await reportPosition(pos); // envoie dans la table `utilisateurs`
    }
    return pos;
  }

  /// Calcul de distance (mètres) entre deux points.
  static double distanceBetween(
    double startLat, double startLng, double endLat, double endLng,
  ) => Geolocator.distanceBetween(startLat, startLng, endLat, endLng);

  // ====== ENVOI EN BASE / RPC ======
  /// À appeler **où que ce soit** quand tu as déjà un `Position`.
  /// Déduplication automatique (>=200m ou >=30min).
  static Future<void> reportPosition(Position pos) async {
    try {
      final lat = pos.latitude;
      final lon = pos.longitude;

      final prefs = await SharedPreferences.getInstance();
      final lastLat = prefs.getDouble(_prefsKeyLat);
      final lastLon = prefs.getDouble(_prefsKeyLon);
      final lastTs  = prefs.getInt(_prefsKeyTs);

      final now = DateTime.now();
      final movedEnough = (lastLat == null || lastLon == null)
          ? true
          : _haversineMeters(lastLat, lastLon, lat, lon) > _minMoveMeters;
      final timeEnough = (lastTs == null)
          ? true
          : now.difference(DateTime.fromMillisecondsSinceEpoch(lastTs)) > _minInterval;

      if (!movedEnough && !timeEnough) return;

      // Optionnel : reverse geocoding -> ville
      String? city;
      try {
        final pm = await placemarkFromCoordinates(lat, lon);
        if (pm.isNotEmpty) {
          final p = pm.first;
          city = (p.locality?.isNotEmpty == true)
              ? p.locality
              : (p.subAdministrativeArea?.isNotEmpty == true ? p.subAdministrativeArea : null);
        }
      } catch (_) {/* non bloquant */}

      // Envoi via ta RPC
      await _sb.rpc('rpc_upsert_user_location', params: {
        '_lat': lat,
        '_lon': lon,
        '_ville': city,
      });

      // Mémo local pour debounce
      await prefs.setDouble(_prefsKeyLat, lat);
      await prefs.setDouble(_prefsKeyLon, lon);
      await prefs.setInt(_prefsKeyTs, now.millisecondsSinceEpoch);
    } catch (_) {
      // silencieux côté UI
    }
  }

  // ====== LISTENER PASSIF (optionnel) ======
  static StreamSubscription<Position>? _sub;

  /// Démarre un stream passif qui envoie la position quand on bouge (150m mini).
  /// Appelle-la après login si tu veux une MAJ automatique “fond de tâche”.
  static Future<void> startPassiveListener() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final ok = await checkPermission();
      if (!ok) return;
      _sub ??= Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, distanceFilter: 150,
        ),
      ).listen(reportPosition);
    } catch (_) {}
  }

  static Future<void> stopPassiveListener() async {
    try { await _sub?.cancel(); } catch (_) {}
    _sub = null;
  }

  // ====== UTILS ======
  static double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat/2)*sin(dLat/2) +
        cos(_deg2rad(lat1))*cos(_deg2rad(lat2))*sin(dLon/2)*sin(dLon/2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
  static double _deg2rad(double d) => d * (pi / 180.0);
}
