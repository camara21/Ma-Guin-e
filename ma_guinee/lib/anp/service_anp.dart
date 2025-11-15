// lib/anp/service_anp.dart

import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exception métier spécifique à l’ANP
class ExceptionAnp implements Exception {
  final String message;
  ExceptionAnp(this.message);

  @override
  String toString() => message;
}

/// Service ANP pour les PERSONNES (1 ANP par utilisateur)
///
/// - Vérifie que l’utilisateur est connecté
/// - (⚠️ contrainte Guinée désactivée pour l’instant si tu veux)
/// - Génère un code ANP unique (au niveau de la table anp_adresses)
/// - Crée ou met à jour la ligne dans `public.anp_adresses`
///
/// Les triggers côté base s’occupent de :
///   - remplir `geom`
///   - mettre à jour `updated_at`
///   - ajouter une ligne dans `anp_adresses_historique`
class ServiceAnp {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Approximation de la zone géographique de la Guinée
  /// (conservé si tu veux la réactiver).
  bool _estDansZoneGuinee(Position pos) {
    const double minLat = 7.0;
    const double maxLat = 13.0;
    const double minLng = -15.0;
    const double maxLng = -7.0;

    return pos.latitude >= minLat &&
        pos.latitude <= maxLat &&
        pos.longitude >= minLng &&
        pos.longitude <= maxLng;
  }

  /// Génère un code ANP du type :
  ///   GN-27-48-PN-XH
  ///
  /// → 2 premiers blocs = CHIFFRES
  /// → 2 derniers blocs = LETTRES
  String _genererCodeAnp() {
    const prefixe = "GN";
    const chiffres = "23456789"; // pas de 0 ni 1 pour éviter confusion
    const lettres = "ABCDEFGHJKLMNPQRSTUVWXYZ"; // pas de 0,1,O,I
    final rand = Random.secure();

    String blocChiffres() {
      return List.generate(
        2,
        (_) => chiffres[rand.nextInt(chiffres.length)],
      ).join();
    }

    String blocLettres() {
      return List.generate(
        2,
        (_) => lettres[rand.nextInt(lettres.length)],
      ).join();
    }

    final d1 = blocChiffres();
    final d2 = blocChiffres();
    final l1 = blocLettres();
    final l2 = blocLettres();

    return "$prefixe-$d1-$d2-$l1-$l2";
  }

  /// Génère un code ANP qui n'existe pas encore en base (table anp_adresses).
  Future<String> _genererCodeAnpUnique() async {
    String code;
    bool existeDeja;

    do {
      code = _genererCodeAnp();

      final Map<String, dynamic>? row = await _supabase
          .from('anp_adresses')
          .select()
          .eq('code', code)
          .maybeSingle();

      existeDeja = row != null;
    } while (existeDeja);

    return code;
  }

  /// Crée ou met à jour l’ANP de l’utilisateur connecté.
  ///
  /// [position] : position GPS actuelle du téléphone.
  /// [autoriserHorsGuineePourTests] : conservé si tu veux réactiver plus tard.
  Future<String> creerOuMettreAJourAnp({
    required Position position,
    bool autoriserHorsGuineePourTests = true, // ✅ contrainte désactivée
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw ExceptionAnp(
        "Vous devez être connecté pour créer votre ANP.",
      );
    }

    // 🛑 Ancienne contrainte Guinée (désactivée pour l’instant)
    // final estEnGuinee = _estDansZoneGuinee(position);
    // if (!estEnGuinee && !autoriserHorsGuineePourTests) {
    //   throw ExceptionAnp(
    //     "Vous ne vous trouvez pas en Guinée.\n"
    //     "La création d’une ANP est réservée aux utilisateurs situés "
    //     "sur le territoire guinéen.",
    //   );
    // }

    final userId = user.id;

    // 1. Vérifier s’il existe déjà une ANP pour cet utilisateur
    final Map<String, dynamic>? existant = await _supabase
        .from('anp_adresses')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    String code;

    if (existant != null && existant['code'] is String) {
      // ANP existe déjà → on garde le même code, on met à jour la position
      code = existant['code'] as String;
    } else {
      // Pas d’ANP → on génère un NOUVEAU code UNIQUE
      code = await _genererCodeAnpUnique();
    }

    // 2. Upsert en base (une ligne par user_id)
    await _supabase.from('anp_adresses').upsert({
      'user_id': userId,
      'code': code,
      'latitude': position.latitude,
      'longitude': position.longitude,
    });

    return code;
  }
}
