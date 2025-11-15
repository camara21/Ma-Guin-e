// lib/anp/service_localisation_anp.dart
import 'dart:io' show Platform;

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
  static const bool appliquerFiltreGuineeEnProd =
      false; // pour l’instant: tests

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

  /// Récupère la position actuelle avec gestion des erreurs
  /// Version plus robuste :
  /// 1) essaie une position précise (bestForNavigation)
  /// 2) si ça échoue → essaie la dernière position connue
  Future<Position> recupererPositionActuelle() async {
    if (!estSurMobile) {
      throw ExceptionLocalisationAnp(
        "La création ou la mise à jour d'une ANP doit se faire depuis l'application mobile.",
      );
    }

    bool serviceActif = await Geolocator.isLocationServiceEnabled();
    if (!serviceActif) {
      throw ExceptionLocalisationAnp(
        "La localisation est désactivée. Activez le GPS de votre téléphone puis réessayez.",
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw ExceptionLocalisationAnp(
          "La permission de localisation a été refusée. "
          "Vous devez l’autoriser pour créer votre ANP.",
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw ExceptionLocalisationAnp(
        "La permission de localisation est bloquée. "
        "Allez dans les réglages de votre téléphone pour l’activer.",
      );
    }

    try {
      // 1) On essaie une position très précise
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      if (appliquerFiltreGuineeEnProd && !estEnGuinee(position)) {
        throw ExceptionLocalisationAnp(
          "Vous ne vous trouvez pas en Guinée.\n"
          "Ce service n'est pas disponible à l'international pour le moment.\n"
          "Vous devez vous trouver en Guinée pour créer votre ANP.",
        );
      }

      return position;
    } catch (_) {
      // 2) Fallback : dernière position connue (moins précise mais souvent dispo)
      final last = await Geolocator.getLastKnownPosition();

      if (last != null) {
        if (appliquerFiltreGuineeEnProd && !estEnGuinee(last)) {
          throw ExceptionLocalisationAnp(
            "Vous ne vous trouvez pas en Guinée.\n"
            "Ce service n'est pas disponible à l'international pour le moment.\n"
            "Vous devez vous trouver en Guinée pour créer votre ANP.",
          );
        }
        return last;
      }

      throw ExceptionLocalisationAnp(
        "Impossible de récupérer votre position précise.\n"
        "Vérifiez que le GPS est bien activé, que l’application a la permission "
        "et réessayez depuis un endroit dégagé (extérieur).",
      );
    }
  }
}
