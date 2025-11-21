// lib/anp/service_localisation_anp.dart

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
  // 🔥 NOUVELLE FONCTION : TRILATÉRATION MULTI-MESURES
  // ----------------------------------------------------------------------
  Future<Position> _obtenirPositionTrilateration() async {
    List<Position> samples = [];

    // Collecte 7 mesures GPS espacées de 300 ms
    for (int i = 0; i < 7; i++) {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      samples.add(pos);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // On trie par meilleure précision (accuracy)
    samples.sort((a, b) => a.accuracy.compareTo(b.accuracy));

    // On prend les 4 meilleurs points
    samples = samples.take(4).toList();

    // Calcul pondéré
    double totalWeight = samples.fold(0, (sum, p) => sum + 1 / p.accuracy);

    double lat = 0;
    double lng = 0;

    for (final p in samples) {
      final w = (1 / p.accuracy) / totalWeight;
      lat += p.latitude * w;
      lng += p.longitude * w;
    }

    // Précision finale estimée
    double finalAccuracy = samples.first.accuracy / 1.6; // très bon

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
  // 🔥 Version robuste + trilatération
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

    try {
      // -------------------------------------------------------------
      // 🔥 TENTATIVE 1 : TRILATÉRATION HAUTE PRÉCISION
      // -------------------------------------------------------------
      final precise = await _obtenirPositionTrilateration();

      if (appliquerFiltreGuineeEnProd && !estEnGuinee(precise)) {
        throw ExceptionLocalisationAnp(
          "Vous ne vous trouvez pas en Guinée.",
        );
      }

      return precise;
    } catch (_) {
      // -------------------------------------------------------------
      // 🔥 TENTATIVE 2 : Position simple fallback
      // -------------------------------------------------------------
      try {
        final fallback = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        return fallback;
      } catch (_) {
        // -------------------------------------------------------------
        // 🔥 TENTATIVE 3 : Dernière position connue
        // -------------------------------------------------------------
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return last;

        throw ExceptionLocalisationAnp(
          "Impossible de récupérer votre position.\n"
          "Essayez à l’extérieur ou vérifiez vos permissions.",
        );
      }
    }
  }
}
