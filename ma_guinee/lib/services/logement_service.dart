// lib/services/logement_service.dart
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/logement_models.dart';

const String _kTable        = 'logements';
const String _kTablePhotos  = 'logement_photos';
const String _kBucketPhotos = 'logement-photos';

class LogementService {
  LogementService({SupabaseClient? client})
      : _sb = client ?? Supabase.instance.client;

  final SupabaseClient _sb;

  // ───────────────────────── Helpers ─────────────────────────

  String _uidOrThrow() {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) throw StateError('Utilisateur non connecté');
    return uid;
  }

  String _like(String s) => '%${s.trim()}%';

  /// Compatible toutes versions: utilise inFilter si dispo, sinon `filter('in', '("a","b")')`.
  PostgrestFilterBuilder _applyIn(
    PostgrestFilterBuilder q,
    String column,
    List<String> values,
  ) {
    if (values.isEmpty) return q;
    try {
      final dynamic dyn = q; // évite erreur compile quand inFilter n’existe pas
      return dyn.inFilter(column, values) as PostgrestFilterBuilder;
    } catch (_) {
      final list = values.map((e) => '"$e"').join(',');
      return q.filter(column, 'in', '($list)');
    }
  }

  /// Injecte `photos` si fourni pour mapper proprement sur LogementModel.
  LogementModel _rowToModel(
    Map<String, dynamic> row, {
    List<String>? photos,
  }) {
    final m = Map<String, dynamic>.from(row);
    if (photos != null) m['photos'] = photos;
    return LogementModel.fromMap(m);
  }

  /// Récupère toutes les photos (url, position) pour des IDs logements.
  /// Retourne: logementId -> [urls triées par position].
  Future<Map<String, List<String>>> _fetchPhotosByIds(List<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await _applyIn(
      _sb.from(_kTablePhotos).select('logement_id, url, position'),
      'logement_id',
      ids,
    )
        .order('logement_id', ascending: true)
        .order('position', ascending: true);

    final map = <String, List<Map<String, dynamic>>>{};
    for (final r in (rows as List)) {
      final m = Map<String, dynamic>.from(r as Map);
      final id = m['logement_id'].toString();
      map.putIfAbsent(id, () => []).add(m);
    }

    final out = <String, List<String>>{};
    map.forEach((id, list) {
      list.sort((a, b) => (a['position'] ?? 0).compareTo(b['position'] ?? 0));
      out[id] = list
          .map((e) => (e['url'] ?? '').toString())
          .where((u) => u.isNotEmpty)
          .toList();
    });
    return out;
  }

  // ─────────────────────────── Lecture ───────────────────────────

  Future<LogementModel?> getById(String id) async {
    try {
      final row = await _sb.from(_kTable).select().eq('id', id).maybeSingle();
      if (row == null) return null;

      final photos = await _fetchPhotosByIds([id]);
      return _rowToModel(Map<String, dynamic>.from(row as Map),
          photos: photos[id] ?? const []);
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  Future<List<LogementModel>> latest({int limit = 10}) async {
    try {
      final rows = await _sb
          .from(_kTable)
          .select('*')
          .order('cree_le', ascending: false)
          .limit(limit);

      final list = (rows as List).cast<Map<String, dynamic>>();
      final ids = list.map((e) => e['id'].toString()).toList();
      final photosMap = await _fetchPhotosByIds(ids);

      return list
          .map((r) => _rowToModel(r, photos: photosMap[r['id'].toString()] ?? const []))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  Future<List<LogementModel>> nearMe({
    String? ville,
    String? commune,
    int limit = 10,
  }) async {
    try {
      var q = _sb.from(_kTable).select('*');

      if (ville != null && ville.trim().isNotEmpty) {
        q = q.ilike('ville', _like(ville));
      }
      if (commune != null && commune.trim().isNotEmpty) {
        q = q.ilike('commune', _like(commune));
      }

      final rows = await q.order('cree_le', ascending: false).limit(limit);
      final list = (rows as List).cast<Map<String, dynamic>>();
      final ids = list.map((e) => e['id'].toString()).toList();
      final photosMap = await _fetchPhotosByIds(ids);

      return list
          .map((r) => _rowToModel(r, photos: photosMap[r['id'].toString()] ?? const []))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  /// Recherche paginée + filtres. Tri & pagination inclus.
  Future<List<LogementModel>> search(LogementSearchParams params) async {
    try {
      var q = _sb.from(_kTable).select('*');

      // Filtres
      if (params.mode != null) {
        q = q.eq('mode', logementModeToString(params.mode!));
      }
      if (params.categorie != null) {
        q = q.eq('categorie', logementCategorieToString(params.categorie!));
      }
      if (params.ville != null && params.ville!.trim().isNotEmpty) {
        q = q.ilike('ville', _like(params.ville!));
      }
      if (params.commune != null && params.commune!.trim().isNotEmpty) {
        q = q.ilike('commune', _like(params.commune!));
      }
      if (params.prixMin != null) q = q.gte('prix_gnf', params.prixMin!);
      if (params.prixMax != null) q = q.lte('prix_gnf', params.prixMax!);
      if (params.surfaceMin != null) q = q.gte('superficie_m2', params.surfaceMin!);
      if (params.surfaceMax != null) q = q.lte('superficie_m2', params.surfaceMax!);
      if (params.chambres != null && params.chambres! > 0) {
        q = q.eq('chambres', params.chambres!);
      }

      // Plein-texte simple
      if (params.q != null && params.q!.trim().isNotEmpty) {
        final kw = params.q!.trim();
        q = q.or(
          'titre.ilike.${_like(kw)},'
          'ville.ilike.${_like(kw)},'
          'commune.ilike.${_like(kw)},'
          'adresse.ilike.${_like(kw)}',
        );
      }

      final rows = await q
          .order(params.orderBy, ascending: params.ascending)
          .range(params.offset, params.offset + params.limit - 1);

      final list = (rows as List).cast<Map<String, dynamic>>();
      final ids = list.map((e) => e['id'].toString()).toList();
      final photosMap = await _fetchPhotosByIds(ids);

      return list
          .map((r) => _rowToModel(r, photos: photosMap[r['id'].toString()] ?? const []))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  // ─────────────────────────── CRUD ───────────────────────────

  Future<String> create(LogementModel data) async {
    try {
      final uid = _uidOrThrow();
      final payload = data.toInsertMap()..['user_id'] = uid;

      final row = await _sb.from(_kTable).insert(payload).select('id').single();
      final id = row['id'].toString();

      // Photos initiales (si fournies)
      if (data.photos.isNotEmpty) {
        await setPhotos(id, data.photos);
      }
      return id;
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  Future<void> update(String id, Map<String, dynamic> changes) async {
    if (changes.isEmpty) return;
    try {
      await _sb.from(_kTable).update(changes).eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  /// Met à jour le logement et, si `patch.photos` est fourni, remplace les photos.
  Future<void> updateFromModel(String id, LogementModel patch) async {
    await update(id, patch.toInsertMap());
    if (patch.photos.isNotEmpty) {
      await setPhotos(id, patch.photos);
    }
  }

  Future<void> delete(String id) async {
    try {
      // Nettoyage photos (au cas où CASCADE absent)
      await _sb.from(_kTablePhotos).delete().eq('logement_id', id);
      await _sb.from(_kTable).delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  /// Remplace toutes les photos d’un logement par `urls` (position = index).
  Future<void> setPhotos(String logementId, List<String> urls) async {
    try {
      await _sb.from(_kTablePhotos).delete().eq('logement_id', logementId);

      if (urls.isEmpty) return;

      final payload = <Map<String, dynamic>>[];
      for (var i = 0; i < urls.length; i++) {
        final url = urls[i].trim();
        if (url.isEmpty) continue;
        payload.add({
          'logement_id': logementId,
          'url': url,
          'position': i,
        });
      }
      if (payload.isNotEmpty) {
        await _sb.from(_kTablePhotos).insert(payload);
      }
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  // ─────────────────────── Contact ───────────────────────

  Future<String?> getContactPhone(String logementId) async {
    try {
      final row = await _sb
          .from(_kTable)
          .select('contact_telephone')
          .eq('id', logementId)
          .maybeSingle();
      if (row == null) return null;
      return (row as Map)['contact_telephone']?.toString();
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  Future<void> updateContactPhone(String logementId, String phone) async {
    try {
      await _sb
          .from(_kTable)
          .update({'contact_telephone': phone})
          .eq('id', logementId);
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  // ─────────────────────── Storage (photos) ───────────────────────

  /// Envoie un binaire dans le bucket public et renvoie (key, publicUrl).
  Future<({String key, String publicUrl})> uploadPhoto({
    required Uint8List bytes,
    required String filename,
    String? logementId,
  }) async {
    try {
      final key =
          '${logementId ?? "tmp"}/${DateTime.now().millisecondsSinceEpoch}_$filename';

      await _sb.storage.from(_kBucketPhotos).uploadBinary(
            key,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final url = _sb.storage.from(_kBucketPhotos).getPublicUrl(key);
      return (key: key, publicUrl: url);
    } on StorageException catch (e) {
      throw Exception(e.message ?? 'Erreur upload');
    }
  }

  /// Si bucket privé, génère une URL signée temporaire.
  Future<String> createSignedUrl(String key, {int expiresInSec = 3600}) async {
    try {
      final url = await _sb.storage
          .from(_kBucketPhotos)
          .createSignedUrl(key, expiresInSec);
      return url;
    } on StorageException catch (e) {
      throw Exception(e.message ?? 'Erreur URL signée');
    }
  }
}
