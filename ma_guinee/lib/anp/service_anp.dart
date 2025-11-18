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
class ServiceAnp {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Approximation de la zone géographique de la Guinée
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

  /// Génère un code ANP du type GN-27-48-PN-XH
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
  Future<String> creerOuMettreAJourAnp({
    required Position position,
    bool autoriserHorsGuineePourTests = true, // pour tes tests en France
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw ExceptionAnp(
        "Vous devez être connecté pour créer votre ANP.",
      );
    }

    final userId = user.id;

    try {
      // 1. Vérifier s’il existe déjà une ANP pour cet utilisateur
      final Map<String, dynamic>? existant = await _supabase
          .from('anp_adresses')
          .select('id, code')
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
      final row = await _supabase
          .from('anp_adresses')
          .upsert(
            {
              'user_id': userId,
              'code': code,
              'latitude': position.latitude,
              'longitude': position.longitude,
            },
            onConflict: 'user_id', // 🔑 très important : on se base sur user_id
          )
          .select('code')
          .single();

      return row['code'] as String;
    } on PostgrestException catch (e) {
      // Si ça plante côté RLS ou contrainte, on remonte un message clair
      throw ExceptionAnp(
        "Erreur lors de l’enregistrement de votre ANP : ${e.message}",
      );
    } catch (_) {
      // Laisse la page gérer l’erreur technique générique
      rethrow;
    }
  }
}
