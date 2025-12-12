// lib/services/jobs_service.dart
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/job_models.dart';

class JobsService {
  final sb = Supabase.instance.client;

  // =============================== CANDIDAT ===============================

  Future<List<EmploiModel>> chercher({
    String? q,
    String? ville,
    String? commune,
    String? typeContrat,
    bool? teletravail,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final term = (q ?? '').trim();

      // Protection contre les caractères spéciaux dans LIKE
      final pattern = term.isEmpty
          ? null
          : '%${term.replaceAll('%', r'\%').replaceAll(',', r'\,')}%';

      final List data = await sb
          .from('emplois')
          .select()
          .eq('actif', true)
          .ifNotNull(ville, (q, v) => q.eq('ville', v))
          .ifNotNull(commune, (q, v) => q.eq('commune', v))
          .ifNotNull(typeContrat, (q, v) => q.eq('type_contrat', v))
          .ifNotNull(teletravail, (q, v) => q.eq('teletravail', v))
          .ifNotNull(
              pattern, (q, p) => q.or('titre.ilike.$p,description.ilike.$p'))
          .order('cree_le', ascending: false)
          .range(offset, offset + limit - 1);

      return data
          .map((e) => EmploiModel.from(Map<String, dynamic>.from(e)))
          .toList()
          .cast<EmploiModel>();
    } catch (_) {
      return <EmploiModel>[]; // En cas d’erreur, renvoyer une liste vide
    }
  }

  /// Récupère une offre d’emploi par ID
  Future<EmploiModel?> emploiById(String id) async {
    final r = await sb.from('emplois').select().eq('id', id).maybeSingle();
    if (r == null) return null;
    return EmploiModel.from(Map<String, dynamic>.from(r));
  }

  /// Récupère les données de l’employeur lié à une offre
  Future<Map<String, dynamic>?> employeur(String id) async {
    final r = await sb.from('employeurs').select().eq('id', id).maybeSingle();
    return r == null ? null : Map<String, dynamic>.from(r);
  }

  // ---------------------------- Favoris candidat ----------------------------

  /// Ajoute ou retire un emploi des favoris
  Future<void> toggleFavori(String emploiId, bool save) async {
    if (save) {
      await sb.from('emplois_enregistres').upsert({'emploi_id': emploiId});
    } else {
      await sb.from('emplois_enregistres').delete().eq('emploi_id', emploiId);
    }
  }

  /// Vérifie si un emploi est enregistré comme favori
  Future<bool> isFavori(String emploiId) async {
    final r = await sb
        .from('emplois_enregistres')
        .select('emploi_id')
        .eq('emploi_id', emploiId)
        .maybeSingle();
    return r != null;
  }

  /// Renvoie tous les IDs des offres enregistrées par l’utilisateur
  Future<Set<String>> favorisIds() async {
    final List rows = await sb.from('emplois_enregistres').select('emploi_id');
    return rows
        .map((e) => (e['emploi_id'] as String?) ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  /// Renvoie la candidature de l’utilisateur pour une offre spécifique
  Future<CandidatureModel?> maCandidature(String emploiId) async {
    final r = await sb
        .from('candidatures')
        .select()
        .eq('emploi_id', emploiId)
        .maybeSingle();
    if (r == null) return null;
    return CandidatureModel.from(Map<String, dynamic>.from(r));
  }

  /// Dépose une candidature (respecte la policy : candidat = auth.uid())
  Future<void> postuler({
    required String emploiId,
    String? cvUrl,
    String? lettre,
    String? telephone,
    String? email,
    String? nom,
    String? prenom,
  }) async {
    final uid = sb.auth.currentUser?.id;
    if (uid == null) throw 'Utilisateur non connecté';

    await sb.from('candidatures').insert({
      'emploi_id': emploiId,
      'candidat': uid,
      'cv_url': cvUrl,
      'lettre': lettre,
      'telephone': telephone,
      'email': email,
      if (nom != null) 'nom': nom,
      if (prenom != null) 'prenom': prenom,
    });
  }

  /// Upload du CV PDF dans le bucket privé "cv"
  Future<String> uploadCv(Uint8List bytes, {String filename = 'cv.pdf'}) async {
    final uid = sb.auth.currentUser?.id;
    if (uid == null) throw 'Utilisateur non connecté';
    final path = '$uid/$filename';

    await sb.storage.from('cv').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return path;
  }

  // ============================= EMPLOYEUR =============================

  /// Liste les offres de l’employeur courant (via RPC mes_offres_employeur)
  Future<List<EmploiModel>> mesOffres() async {
    final rows = await sb.rpc('mes_offres_employeur');
    final list = (rows as List?) ?? const [];
    return list
        .map((e) => EmploiModel.from(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Crée une nouvelle offre d’emploi
  Future<String> creerOffre(Map<String, dynamic> payload) async {
    final r = await sb.from('emplois').insert(payload).select('id').single();
    return (r['id'] as String);
  }

  /// Met à jour une offre existante
  Future<void> majOffre(String id, Map<String, dynamic> payload) async {
    await sb.from('emplois').update(payload).eq('id', id);
  }

  /// Supprime une offre (policy DELETE propriétaire requise)
  Future<void> supprimerOffre(String id) async {
    await sb.from('emplois').delete().eq('id', id).select('id').maybeSingle();
  }

  /// Active ou désactive une offre (champ actif)
  Future<void> setActif(String id, bool actif) async {
    await sb.from('emplois').update({'actif': actif}).eq('id', id);
  }

  /// Liste les candidatures reçues pour une offre
  Future<List<Map<String, dynamic>>> candidaturesRecues(String emploiId) async {
    final List data = await sb
        .from('candidatures')
        .select('id, statut, cree_le, telephone, email, lettre, nom, prenom')
        .eq('emploi_id', emploiId)
        .order('cree_le', ascending: false);

    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Change le statut d’une candidature (ex: accepté / refusé / en attente)
  Future<void> setStatutCandidature(String candId, String statut) async {
    await sb.from('candidatures').update({'statut': statut}).eq('id', candId);
  }
}

/// Extension pratique qui applique un filtre uniquement si la valeur n’est pas nulle
extension _FilterIfNotNull on PostgrestFilterBuilder {
  PostgrestFilterBuilder ifNotNull<T>(
    T? value,
    PostgrestFilterBuilder Function(PostgrestFilterBuilder q, T v) apply,
  ) {
    if (value == null) return this;
    return apply(this, value);
  }
}
