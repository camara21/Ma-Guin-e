// lib/anp/service_anp_entreprise.dart

import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exception métier spécifique ANP ENTREPRISE
class ExceptionAnpEntreprise implements Exception {
  final String message;
  ExceptionAnpEntreprise(this.message);

  @override
  String toString() => message;
}

/// Service ANP pour les ENTREPRISES
///
/// - Gère la création / mise à jour d’une entreprise (anp_entreprises)
/// - Gère la création / mise à jour du site PRINCIPAL
/// - Gère la création de sites secondaires (agences, dépôts, etc.)
/// - Génère des codes ANP uniques pour `anp_entreprise_sites.code`
class ServiceAnpEntreprise {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ------------------ ZONE GEOGRAPHIQUE GUINÉE ------------------

  /// Approximation de la zone de la Guinée pour la règle métier.
  /// Conservé si tu veux réactiver la contrainte plus tard.
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

  // ------------------ GENERATION CODE ANP ENTREPRISE ------------------

  /// Génère un code ANP du type :
  ///   GN-27-48-PN-XH
  ///
  /// 👉 2 premiers blocs (4 caractères) = CHIFFRES (2–9)
  /// 👉 2 derniers blocs (4 caractères) = LETTRES (A–Z sans O,I)
  String _genererCodeAnp() {
    const prefixe = "GN";
    const digits = "23456789"; // pas de 0 ni 1 pour éviter confusion
    const letters = "ABCDEFGHJKLMNPQRSTUVWXYZ"; // pas de O,I
    final rand = Random.secure();

    String blocDigits() {
      return List.generate(
        2,
        (_) => digits[rand.nextInt(digits.length)],
      ).join();
    }

    String blocLetters() {
      return List.generate(
        2,
        (_) => letters[rand.nextInt(letters.length)],
      ).join();
    }

    final d1 = blocDigits(); // ex : 27
    final d2 = blocDigits(); // ex : 48
    final l1 = blocLetters(); // ex : PN
    final l2 = blocLetters(); // ex : XH

    return "$prefixe-$d1-$d2-$l1-$l2";
  }

  /// Génère un code ANP ENTREPRISE qui n'existe pas encore
  /// dans `public.anp_entreprise_sites.code`.
  Future<String> _genererCodeAnpUnique() async {
    String code;
    bool existeDeja;

    do {
      code = _genererCodeAnp();

      final Map<String, dynamic>? row = await _supabase
          .from('anp_entreprise_sites')
          .select()
          .eq('code', code)
          .maybeSingle();

      existeDeja = row != null;
    } while (existeDeja);

    return code;
  }

  // ------------------ ENTREPRISE : CREATE / UPDATE ------------------

  /// Crée ou met à jour une ENTREPRISE.
  ///
  /// - Si [entrepriseId] est null → création (owner = user connecté)
  /// - Sinon → mise à jour de l’entreprise (vérifie que l’utilisateur est owner)
  ///
  /// Retourne la ligne complète de `anp_entreprises`.
  Future<Map<String, dynamic>> creerOuMettreAJourEntreprise({
    String? entrepriseId,
    required String nom,
    String? secteur,
    String? contactEmail,
    String? contactTelephone,
    String? siteWeb,
    bool actif = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw ExceptionAnpEntreprise(
        "Vous devez être connecté pour gérer une entreprise ANP.",
      );
    }
    final userId = user.id;

    if (entrepriseId == null) {
      // ---------- CREATION ----------
      final inserted = await _supabase
          .from('anp_entreprises')
          .insert({
            'nom': nom,
            // on peut laisser slug nul ou le gérer plus tard côté back-office
            'secteur': secteur,
            'contact_email': contactEmail,
            'contact_telephone': contactTelephone,
            'site_web': siteWeb,
            'owner_user_id': userId,
            'actif': actif,
          })
          .select()
          .single();

      return inserted;
    } else {
      // ---------- MISE A JOUR ----------
      // RLS impose déjà owner_user_id = auth.uid(),
      // mais on vérifie quand même côté client pour message plus clair.
      final existant = await _supabase
          .from('anp_entreprises')
          .select()
          .eq('id', entrepriseId)
          .eq('owner_user_id', userId)
          .maybeSingle();

      if (existant == null) {
        throw ExceptionAnpEntreprise(
          "Vous n'êtes pas propriétaire de cette entreprise ou elle n'existe pas.",
        );
      }

      final updated = await _supabase
          .from('anp_entreprises')
          .update({
            'nom': nom,
            'secteur': secteur,
            'contact_email': contactEmail,
            'contact_telephone': contactTelephone,
            'site_web': siteWeb,
            'actif': actif,
          })
          .eq('id', entrepriseId)
          .select()
          .single();

      return updated;
    }
  }

  // ------------------ SITE PRINCIPAL ------------------

  /// Crée ou met à jour le SITE PRINCIPAL d’une entreprise.
  ///
  /// - Vérifie que l’utilisateur connecté est owner de l’entreprise
  /// - ⚠️ La contrainte "être en Guinée" est désactivée pour l’instant
  /// - S’il existe déjà un site principal → mise à jour position + infos
  /// - Sinon → création d’un nouveau site avec un code ANP unique
  ///
  /// Retourne la ligne complète de `anp_entreprise_sites`.
  Future<Map<String, dynamic>> creerOuMettreAJourSitePrincipal({
    required String entrepriseId,
    required Position position,
    required String nomSite,
    String? typeSite, // "agence", "entrepot", "point_relais", etc.
    bool autoriserHorsGuineePourTests = false, // conservé pour plus tard
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw ExceptionAnpEntreprise(
        "Vous devez être connecté pour gérer les sites d’entreprise.",
      );
    }
    final userId = user.id;

    // Vérifier que l’entreprise appartient bien à l’utilisateur et est active
    final entreprise = await _supabase
        .from('anp_entreprises')
        .select()
        .eq('id', entrepriseId)
        .eq('owner_user_id', userId)
        .eq('actif', true)
        .maybeSingle();

    if (entreprise == null) {
      throw ExceptionAnpEntreprise(
        "Entreprise introuvable ou vous n'êtes pas le propriétaire.",
      );
    }

    // 🛑 Ancienne vérif localisation Guinée (désactivée pour l’instant)
    // final estEnGuinee = _estDansZoneGuinee(position);
    // if (!estEnGuinee && !autoriserHorsGuineePourTests) {
    //   throw ExceptionAnpEntreprise(
    //     "Vous ne vous trouvez pas en Guinée.\n"
    //     "La création d’un site d’entreprise ANP est réservée "
    //     "aux positions sur le territoire guinéen.",
    //   );
    // }

    // Chercher s’il existe déjà un site principal
    final sitePrincipalExistant = await _supabase
        .from('anp_entreprise_sites')
        .select()
        .eq('entreprise_id', entrepriseId)
        .eq('est_principal', true)
        .maybeSingle();

    Map<String, dynamic> result;

    if (sitePrincipalExistant != null) {
      // --------- MISE A JOUR DU SITE PRINCIPAL EXISTANT ---------
      final siteId = sitePrincipalExistant['id'] as String;

      result = await _supabase
          .from('anp_entreprise_sites')
          .update({
            'nom_site': nomSite,
            'type_site': typeSite,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'est_principal': true,
          })
          .eq('id', siteId)
          .select()
          .single();
    } else {
      // --------- CREATION D’UN NOUVEAU SITE PRINCIPAL ---------
      final code = await _genererCodeAnpUnique();

      result = await _supabase
          .from('anp_entreprise_sites')
          .insert({
            'entreprise_id': entrepriseId,
            'code': code,
            'nom_site': nomSite,
            'type_site': typeSite,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'est_principal': true,
          })
          .select()
          .single();
    }

    return result;
  }

  // ------------------ SITES SECONDAIRES ------------------

  /// Crée un SITE SECONDAIRE pour une entreprise
  /// (agence, entrepôt, point relais...).
  ///
  /// - Ne touche pas au site principal
  /// - Génère un code ANP unique
  ///
  /// Retourne la ligne complète de `anp_entreprise_sites`.
  Future<Map<String, dynamic>> creerSiteSecondaire({
    required String entrepriseId,
    required Position position,
    required String nomSite,
    String? typeSite,
    bool autoriserHorsGuineePourTests = false, // conservé pour plus tard
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw ExceptionAnpEntreprise(
        "Vous devez être connecté pour créer un site secondaire.",
      );
    }
    final userId = user.id;

    // Vérifier que l’entreprise appartient bien à l’utilisateur et est active
    final entreprise = await _supabase
        .from('anp_entreprises')
        .select()
        .eq('id', entrepriseId)
        .eq('owner_user_id', userId)
        .eq('actif', true)
        .maybeSingle();

    if (entreprise == null) {
      throw ExceptionAnpEntreprise(
        "Entreprise introuvable ou vous n'êtes pas le propriétaire.",
      );
    }

    // 🛑 Ancienne vérif localisation Guinée (désactivée pour l’instant)
    // final estEnGuinee = _estDansZoneGuinee(position);
    // if (!estEnGuinee && !autoriserHorsGuineePourTests) {
    //   throw ExceptionAnpEntreprise(
    //     "Vous ne vous trouvez pas en Guinée.\n"
    //     "La création d’un site d’entreprise ANP est réservée "
    //     "aux positions sur le territoire guinéen.",
    //   );
    // }

    final code = await _genererCodeAnpUnique();

    final inserted = await _supabase
        .from('anp_entreprise_sites')
        .insert({
          'entreprise_id': entrepriseId,
          'code': code,
          'nom_site': nomSite,
          'type_site': typeSite,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'est_principal': false,
        })
        .select()
        .single();

    return inserted;
  }

  // ------------------ UTILITAIRE DISTANCE ------------------

  double calculerDistanceKm(
      double lat1, double lng1, double lat2, double lng2) {
    const rayonTerre = 6371; // km
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return rayonTerre * c;
  }

  double _degToRad(double deg) => deg * pi / 180.0;
}
