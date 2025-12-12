// lib/services/employeur_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeurService {
  EmployeurService({SupabaseClient? client})
      : _sb = client ?? Supabase.instance.client;

  final SupabaseClient _sb;

  String _currentUserIdOrThrow() {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) throw StateError('Utilisateur non connecté');
    return uid;
  }

  // ===================== Lecture / consultation =====================

  /// ID de l'employeur de l'utilisateur courant (ou null).
  Future<String?> getEmployeurId() async {
    try {
      final uid = _currentUserIdOrThrow();
      final row = await _sb
          .from('employeurs')
          .select('id')
          .eq('proprietaire', uid)
          .maybeSingle();
      return row == null ? null : (row['id'] as String);
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  /// Ligne employeur complète (ou null).
  Future<Map<String, dynamic>?> getEmployeurRow() async {
    try {
      final uid = _currentUserIdOrThrow();
      final row = await _sb
          .from('employeurs')
          .select() // <- pas de générique
          .eq('proprietaire', uid)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row as Map);
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  /// Indique si l'utilisateur courant a déjà un employeur.
  Future<bool> isEmployeur() async => (await getEmployeurId()) != null;

  // ===================== Création / Upsert =====================

  /// Crée (si absent) ou récupère l'employeur, et retourne son **id**.
  Future<String> ensureEmployeurId({
    required String nom,
    String? telephone,
    String? email,
    String? ville,
    String? commune,
    String? secteur,
  }) async {
    try {
      final uid = _currentUserIdOrThrow();

      // Si un employeur existe déjà pour cet utilisateur, on renvoie son id.
      final exist = await getEmployeurId();
      if (exist != null) return exist;

      final payload = <String, dynamic>{
        'proprietaire': uid,
        'nom': nom,
        if (telephone != null && telephone.trim().isNotEmpty)
          'telephone': telephone.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (ville != null && ville.trim().isNotEmpty) 'ville': ville.trim(),
        if (commune != null && commune.trim().isNotEmpty)
          'commune': commune.trim(),
        if (secteur != null && secteur.trim().isNotEmpty)
          'secteur': secteur.trim(),
      };

      final row = await _sb
          .from('employeurs')
          .upsert(payload, onConflict: 'proprietaire')
          .select('id')
          .single(); // renvoie l'id même en cas de mise à jour

      return row['id'] as String;
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  /// Upsert et renvoie la ligne complète de l'employeur.
  Future<Map<String, dynamic>> upsertEmployeur({
    required String nom,
    String? telephone,
    String? email,
    String? ville,
    String? commune,
    String? secteur,
  }) async {
    try {
      final uid = _currentUserIdOrThrow();
      final payload = <String, dynamic>{
        'proprietaire': uid,
        'nom': nom,
        if (telephone != null && telephone.trim().isNotEmpty)
          'telephone': telephone.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (ville != null && ville.trim().isNotEmpty) 'ville': ville.trim(),
        if (commune != null && commune.trim().isNotEmpty)
          'commune': commune.trim(),
        if (secteur != null && secteur.trim().isNotEmpty)
          'secteur': secteur.trim(),
      };

      final row = await _sb
          .from('employeurs')
          .upsert(payload, onConflict: 'proprietaire')
          .select() // <- pas de générique
          .single();

      return Map<String, dynamic>.from(row as Map);
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  // ===================== Mise à jour partielle =====================

  /// Met à jour certains champs de l'employeur et renvoie la ligne.
  Future<Map<String, dynamic>> updateEmployeur(
      Map<String, dynamic> changes) async {
    if (changes.isEmpty) {
      throw ArgumentError('Aucun champ à mettre à jour');
    }
    try {
      final uid = _currentUserIdOrThrow();
      final row = await _sb
          .from('employeurs')
          .update(changes)
          .eq('proprietaire', uid)
          .select() // <- pas de générique
          .single();

      return Map<String, dynamic>.from(row as Map);
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  // ===================== Helpers pratiques =====================

  /// Met à jour uniquement le nom de l'employeur.
  Future<Map<String, dynamic>> updateNom(String nom) =>
      updateEmployeur({'nom': nom});

  /// Met à jour les coordonnées (téléphone, email, ville, commune).
  Future<Map<String, dynamic>> updateCoordonnees({
    String? telephone,
    String? email,
    String? ville,
    String? commune,
  }) =>
      updateEmployeur({
        if (telephone != null) 'telephone': telephone,
        if (email != null) 'email': email,
        if (ville != null) 'ville': ville,
        if (commune != null) 'commune': commune,
      });

  /// S'assure qu'un employeur existe (création si besoin) et renvoie son id.
  Future<String> assertEmployeurExists({required String nomParDefaut}) =>
      ensureEmployeurId(nom: nomParDefaut);
}
