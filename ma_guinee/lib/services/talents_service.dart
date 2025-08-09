import 'package:supabase_flutter/supabase_flutter.dart';

class TalentsService {
  final SupabaseClient _sb = Supabase.instance.client;

  // --- Auth utils ---
  String _requireUserId() {
    final user = _sb.auth.currentUser;
    if (user == null) throw StateError('Utilisateur non connecté.');
    return user.id;
  }

  // --- READ: liste des talents ---
  Future<List<Map<String, dynamic>>> fetchTalents({
    String? genre,
    String? ville,
    int limit = 20,
    int offset = 0,
    bool onlyApproved = true,
    bool fuzzy = false, // passe à true pour un filtrage ILIKE
  }) async {
    var qb = _sb.from('talents').select('*');

    if (onlyApproved) {
      qb = qb.eq('status', 'approved');
    }
    if (genre != null && genre.isNotEmpty) {
      qb = fuzzy ? qb.ilike('genre', '%$genre%') : qb.eq('genre', genre);
    }
    if (ville != null && ville.isNotEmpty) {
      qb = fuzzy ? qb.ilike('ville', '%$ville%') : qb.eq('ville', ville);
    }

    final data = await qb
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    // Supabase Dart renvoie déjà une List<dynamic>
    return data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // --- CREATE: publier un talent (retourne la row créée) ---
  Future<Map<String, dynamic>> createTalent({
    required String titre,
    String? genre,
    String? ville,
    String? description,
    required String videoPath,      // chemin storage privé (talents-videos)
    String? thumbnailPath,          // chemin storage public (talents-thumbs) éventuel
  }) async {
    final uid = _requireUserId();

    final insert = {
      'user_id': uid,
      'titre': titre,
      'genre': genre,
      'ville': ville,
      'description': description,
      'video_url': videoPath,
      'thumbnail_url': thumbnailPath,
      'status': 'approved', // publication immédiate
    };

    final row = await _sb.from('talents').insert(insert).select().single();
    return Map<String, dynamic>.from(row as Map);
  }

  // --- VUES ---
  Future<void> incrementViews(int talentId) async {
    // Si tu as une RPC côté DB (recommandé pour l'atomicité)
    try {
      await _sb.rpc('increment_views_talent', params: {'p_talent_id': talentId});
      return;
    } catch (_) {
      // Fallback non atomique (OK pour usage "best-effort")
      final current = await _sb
          .from('talents')
          .select('views_count')
          .eq('id', talentId)
          .single();

      final views = (current['views_count'] ?? 0) as int;
      await _sb.from('talents').update({'views_count': views + 1}).eq('id', talentId);
    }
  }

  // --- LIKES ---
  Future<bool> isLiked(int talentId) async {
    final uid = _requireUserId();

    final data = await _sb
        .from('talent_likes')
        .select('id')
        .eq('talent_id', talentId)
        .eq('user_id', uid)
        .maybeSingle();

    return data != null;
  }

  Future<void> like(int talentId) async {
    final uid = _requireUserId();

    await _sb.from('talent_likes').insert({'talent_id': talentId, 'user_id': uid});

    // Mets à jour le compteur local (si pas de trigger en DB)
    try {
      final current = await _sb
          .from('talents')
          .select('likes_count')
          .eq('id', talentId)
          .single();
      final likes = (current['likes_count'] ?? 0) as int;
      await _sb.from('talents').update({'likes_count': likes + 1}).eq('id', talentId);
    } catch (_) {
      // ignore si la colonne n'existe pas / triggers en place
    }
  }

  Future<void> unlike(int talentId) async {
    final uid = _requireUserId();

    // Supprime le like
    final deleted = await _sb
        .from('talent_likes')
        .delete()
        .eq('talent_id', talentId)
        .eq('user_id', uid)
        .select()
        .maybeSingle();

    // Si rien n’a été supprimé, on ne décrémente pas
    if (deleted == null) return;

    // Mets à jour le compteur (si pas de trigger)
    try {
      final current = await _sb
          .from('talents')
          .select('likes_count')
          .eq('id', talentId)
          .single();
      final likes = (current['likes_count'] ?? 0) as int;
      final newCount = likes > 0 ? likes - 1 : 0;
      await _sb.from('talents').update({'likes_count': newCount}).eq('id', talentId);
    } catch (_) {
      // ignore
    }
  }

  // --- COMMENTAIRES ---
  Future<List<Map<String, dynamic>>> listComments(int talentId) async {
    final data = await _sb
        .from('talent_comments')
        .select('id, contenu, created_at, user_id')
        .eq('talent_id', talentId)
        .order('created_at', ascending: false);

    return data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> addComment(int talentId, String contenu) async {
    final uid = _requireUserId();

    final row = await _sb.from('talent_comments').insert({
      'talent_id': talentId,
      'user_id': uid,
      'contenu': contenu,
    }).select().single();

    return Map<String, dynamic>.from(row as Map);
  }

  // --- PROFIL PUBLIC (pour l’overlay auteur dans les Reels) ---
  Future<Map<String, dynamic>?> getUserPublic(String userId) async {
    final row = await _sb
        .from('utilisateurs')
        .select('id, prenom, nom, photo_url, rating_avg')
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row as Map);
  }

  // --- SOUTIEN (tips) ---
  Future<void> support(int talentId, int amount) async {
    final uid = _requireUserId();
    await _sb.from('talent_supports').insert({
      'talent_id': talentId,
      'user_id': uid,
      'amount': amount,
    });
  }
}
