// lib/anp/service_localisation_anp.dart

import 'dart:async'; // ✅ TimeoutException
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

/// Exception personnalisée pour les erreurs de localisation ANP
class ExceptionLocalisationAnp implements Exception {
  final String message;
  ExceptionLocalisationAnp(this.message);

  @override
  String toString() => message;
}

/// Service de localisation pour l’ANP
class ServiceLocalisationAnp {
  ServiceLocalisationAnp();

  /// Quand tu passeras en PROD tu mettras à true
  /// pour BLOQUER la création ANP hors Guinée.
  static const bool appliquerFiltreGuineeEnProd = false; // tests

  // ✅ Réglages "réseau faible / GPS instable"
  static const Duration _timeLimitParMesure = Duration(seconds: 6);
  static const Duration _timeLimitFallback = Duration(seconds: 8);
  static const Duration _timeoutGlobal = Duration(seconds: 22);

  // ✅ Si on a un last known récent, on peut l’utiliser comme secours rapide
  static const Duration _lastKnownMaxAge = Duration(minutes: 5);

  bool get estSurMobile {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Vérifie si la position se trouve en Guinée (approximation)
  bool estEnGuinee(Position pos) {
    final lat = pos.latitude;
    final lon = pos.longitude;

    final dansLat = lat >= 7.0 && lat <= 13.0;
    final dansLon = lon >= -15.5 && lon <= -7.0;

    return dansLat && dansLon;
  }

  // ----------------------------------------------------------------------
  // ✅ Helper : getCurrentPosition robuste (timeouts + retries)
  // ----------------------------------------------------------------------
  Future<Position?> _safeGetCurrentPosition({
    required LocationAccuracy accuracy,
    required Duration timeLimit,
    int attempts = 2,
  }) async {
    for (int i = 0; i < attempts; i++) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: accuracy,
          timeLimit: timeLimit,
        );
        return pos;
      } on TimeoutException {
        // backoff léger
        await Future.delayed(Duration(milliseconds: 350 * (i + 1)));
      } catch (_) {
        await Future.delayed(Duration(milliseconds: 350 * (i + 1)));
      }
    }
    return null;
  }

  // ----------------------------------------------------------------------
  // 🔥 NOUVELLE FONCTION : TRILATÉRATION MULTI-MESURES (robuste)
  // ----------------------------------------------------------------------
  Future<Position> _obtenirPositionTrilateration() async {
    List<Position> samples = [];

    // ✅ On vise 7 mesures, mais on n'attend pas indéfiniment si le GPS est lent
    const targetSamples = 7;
    int failures = 0;

    for (int i = 0; i < targetSamples; i++) {
      final pos = await _safeGetCurrentPosition(
        accuracy: LocationAccuracy.bestForNavigation,
        timeLimit: _timeLimitParMesure,
        attempts: 1, // 1 essai par itération (on boucle déjà)
      );

      if (pos != null) {
        samples.add(pos);
      } else {
        failures++;
        // Si ça échoue trop, on arrête de perdre du temps
        if (failures >= 3) break;
      }

      await Future.delayed(const Duration(milliseconds: 300));
    }

    // ✅ Si on n'a pas assez d'échantillons, on force un fallback plus simple
    if (samples.length < 2) {
      throw ExceptionLocalisationAnp(
        "Localisation trop instable (signal GPS faible).",
      );
    }

    // On trie par meilleure précision (accuracy)
    samples.sort((a, b) => a.accuracy.compareTo(b.accuracy));

    // On prend les 4 meilleurs points (ou moins si on n’a pas)
    samples = samples.take(min(4, samples.length)).toList();

    // Calcul pondéré
    double totalWeight = samples.fold(0, (sum, p) {
      final acc = (p.accuracy <= 0) ? 1.0 : p.accuracy;
      return sum + 1 / acc;
    });

    double lat = 0;
    double lng = 0;

    for (final p in samples) {
      final acc = (p.accuracy <= 0) ? 1.0 : p.accuracy;
      final w = (1 / acc) / totalWeight;
      lat += p.latitude * w;
      lng += p.longitude * w;
    }

    // Précision finale estimée
    final bestAcc =
        (samples.first.accuracy <= 0) ? 10.0 : samples.first.accuracy;
    final finalAccuracy = bestAcc / 1.6;

    return Position(
      latitude: lat,
      longitude: lng,
      accuracy: finalAccuracy,
      timestamp: DateTime.now(),
      altitude: samples.first.altitude,
      altitudeAccuracy: samples.first.altitudeAccuracy,
      heading: samples.first.heading,
      headingAccuracy: samples.first.headingAccuracy,
      speed: samples.first.speed,
      speedAccuracy: samples.first.speedAccuracy,
      floor: samples.first.floor,
      isMocked: samples.first.isMocked,
    );
  }

  // ----------------------------------------------------------------------
  // 🔥 Version robuste + trilatération + timeouts + fallback last known
  // ----------------------------------------------------------------------
  Future<Position> recupererPositionActuelle() async {
    if (!estSurMobile) {
      throw ExceptionLocalisationAnp(
        "La création ou la mise à jour d'une ANP doit se faire depuis l'application mobile.",
      );
    }

    bool serviceActif = await Geolocator.isLocationServiceEnabled();
    if (!serviceActif) {
      throw ExceptionLocalisationAnp(
        "La localisation est désactivée. Activez le GPS puis réessayez.",
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw ExceptionLocalisationAnp(
          "La permission de localisation a été refusée.",
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw ExceptionLocalisationAnp(
        "La permission de localisation est bloquée.\n"
        "Activez-la dans les réglages.",
      );
    }

    // ✅ On prend un last known récent en secours (ne bloque pas)
    Position? lastKnown;
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        final ts = last.timestamp;
        if (ts != null && DateTime.now().difference(ts) <= _lastKnownMaxAge) {
          lastKnown = last;
        }
      }
    } catch (_) {}

    // ✅ Timeout global: si GPS/AGPS est trop lent, on n’attend pas indéfiniment
    try {
      final precise =
          await _obtenirPositionTrilateration().timeout(_timeoutGlobal);

      if (appliquerFiltreGuineeEnProd && !estEnGuinee(precise)) {
        throw ExceptionLocalisationAnp("Vous ne vous trouvez pas en Guinée.");
      }

      return precise;
    } on TimeoutException {
      // On passe au fallback
    } catch (_) {
      // On passe au fallback
    }

    // -------------------------------------------------------------
    // 🔥 TENTATIVE 2 : Position simple fallback (timeout + retry)
    // -------------------------------------------------------------
    try {
      final fallback = await _safeGetCurrentPosition(
        accuracy: LocationAccuracy.high,
        timeLimit: _timeLimitFallback,
        attempts: 2,
      );

      if (fallback != null) {
        if (appliquerFiltreGuineeEnProd && !estEnGuinee(fallback)) {
          throw ExceptionLocalisationAnp("Vous ne vous trouvez pas en Guinée.");
        }
        return fallback;
      }
    } catch (_) {}

    // -------------------------------------------------------------
    // 🔥 TENTATIVE 3 : Dernière position connue (si dispo)
    // -------------------------------------------------------------
    if (lastKnown != null) {
      if (appliquerFiltreGuineeEnProd && !estEnGuinee(lastKnown)) {
        throw ExceptionLocalisationAnp("Vous ne vous trouvez pas en Guinée.");
      }
      return lastKnown;
    }

    // Dernier recours : last known (même ancien), sinon erreur
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return last;

    throw ExceptionLocalisationAnp(
      "Impossible de récupérer votre position.\n"
      "Essayez à l’extérieur ou vérifiez vos permissions.",
    );
  }
}
