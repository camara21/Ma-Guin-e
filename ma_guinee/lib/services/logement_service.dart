// lib/services/logement_service.dart
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/logement_models.dart';

const String _kTable = 'logements';
const String _kTablePhotos = 'logement_photos';
const String _kBucketPhotos = 'logements'; // Nom exact du bucket (avec le "s")

class LogementService {
  LogementService({SupabaseClient? client})
      : _sb = client ?? Supabase.instance.client;

  final SupabaseClient _sb;

  // ========================= Helpers généraux =========================

  /// Renvoie l'ID de l'utilisateur connecté ou lance une erreur s'il n'est pas connecté.
  String _uidOrThrow() {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Utilisateur non connecté');
    }
    return uid;
  }

  /// Construit un pattern pour les recherches ILIKE.
  String _like(String s) => '%${s.trim()}%';

  /// Compatible toutes versions: utilise `inFilter` si disponible, sinon `filter('in', ...)`.
  PostgrestFilterBuilder _applyIn(
    PostgrestFilterBuilder q,
    String column,
    List<String> values,
  ) {
    if (values.isEmpty) return q;
    try {
      final dynamic dyn =
          q; // évite les erreurs de compilation si inFilter n'existe pas
      return dyn.inFilter(column, values) as PostgrestFilterBuilder;
    } catch (_) {
      final list = values.map((e) => '"$e"').join(',');
      return q.filter(column, 'in', '($list)');
    }
  }

  /// Map prêt pour la DB **sans** le champ `photos`.
  Map<String, dynamic> _modelToDbMap(LogementModel m) {
    final map = <String, dynamic>{
      'titre': m.titre,
      'description': m.description,
      'mode': logementModeToString(m.mode),
      'categorie': logementCategorieToString(m.categorie),
      'prix_gnf': m.prixGnf,
      'ville': m.ville,
      'commune': m.commune,
      'adresse': m.adresse,
      'superficie_m2': m.superficieM2,
      'chambres': m.chambres,
      'lat': m.lat,
      'lng': m.lng,
      'contact_telephone': m.contactTelephone,
    };
    // On supprime les valeurs nulles (on garde 0 / false)
    map.removeWhere((_, v) => v == null);
    return map;
  }

  /// Injecte `photos` si fourni pour alimenter correctement LogementModel.
  LogementModel _rowToModel(
    Map<String, dynamic> row, {
    List<String>? photos,
  }) {
    final m = Map<String, dynamic>.from(row);
    if (photos != null) {
      // uniquement pour le modèle
      m['photos'] = photos;
    }
    return LogementModel.fromMap(m);
  }

  /// Récupère les photos (url, position) pour une liste d'IDs de logements.
  Future<Map<String, List<String>>> _fetchPhotosByIds(List<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await _applyIn(
      _sb.from(_kTablePhotos).select('logement_id, url, position'),
      'logement_id',
      ids,
    ).order('logement_id', ascending: true).order('position', ascending: true);

    final tmp = <String, List<Map<String, dynamic>>>{};
    for (final r in (rows as List)) {
      final m = Map<String, dynamic>.from(r as Map);
      final id = m['logement_id'].toString();
      tmp.putIfAbsent(id, () => []).add(m);
    }

    final out = <String, List<String>>{};
    tmp.forEach((id, list) {
      list.sort((a, b) => (a['position'] ?? 0).compareTo(b['position'] ?? 0));
      out[id] = list
          .map((e) => (e['url'] ?? '').toString())
          .where((u) => u.isNotEmpty)
          .toList();
    });
    return out;
  }

  // ============================== Lecture ==============================

  /// Récupère un logement par son ID (avec ses photos).
  Future<LogementModel?> getById(String id) async {
    try {
      final row = await _sb.from(_kTable).select().eq('id', id).maybeSingle();
      if (row == null) return null;

      final photos = await _fetchPhotosByIds([id]);
      return _rowToModel(
        Map<String, dynamic>.from(row as Map),
        photos: photos[id] ?? const [],
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  /// Mes annonces logement (avec sous-table `logement_photos`), triées par `cree_le` desc.
  Future<List<LogementModel>> myListings(String userId) async {
    final rows = await _sb.from(_kTable).select('''
          id, user_id, titre, description, mode, categorie, prix_gnf,
          ville, commune, adresse, superficie_m2, chambres, lat, lng,
          contact_telephone, cree_le, maj_le,
          logement_photos (url, position)
        ''').eq('user_id', userId).order('cree_le', ascending: false);

    final list = (rows as List).cast<Map<String, dynamic>>();

    return list.map((r) {
      final m = Map<String, dynamic>.from(r);
      final photosRaw =
          (r['logement_photos'] as List?)?.cast<Map<String, dynamic>>() ??
              const <Map<String, dynamic>>[];

      photosRaw
          .sort((a, b) => (a['position'] ?? 0).compareTo(b['position'] ?? 0));

      m['photos'] = photosRaw
          .map((e) => (e['url'] ?? '').toString())
          .where((u) => u.isNotEmpty)
          .toList();

      return LogementModel.fromMap(m);
    }).toList();
  }

  /// Récupération de plusieurs biens par leurs IDs.
  Future<List<LogementModel>> getManyByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final rows = await _applyIn(_sb.from(_kTable).select('*'), 'id', ids)
          .order('cree_le', ascending: false);

      final list = (rows as List).cast<Map<String, dynamic>>();
      final photosMap = await _fetchPhotosByIds(
        list.map((e) => e['id'].toString()).toList(),
      );

      return list
          .map(
            (r) => _rowToModel(
              r,
              photos: photosMap[r['id'].toString()] ?? const [],
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  /// Derniers logements publiés (limit par défaut : 10).
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
          .map(
            (r) => _rowToModel(
              r,
              photos: photosMap[r['id'].toString()] ?? const [],
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  /// Logements proches (par ville/commune) avec limite de résultats.
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
          .map(
            (r) => _rowToModel(
              r,
              photos: photosMap[r['id'].toString()] ?? const [],
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  /// Recherche paginée avec filtres (mode, catégorie, ville, prix, surface, etc.).
  Future<List<LogementModel>> search(LogementSearchParams params) async {
    try {
      var q = _sb.from(_kTable).select('*');

      // Filtres structurés
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
      if (params.surfaceMin != null) {
        q = q.gte('superficie_m2', params.surfaceMin!);
      }
      if (params.surfaceMax != null) {
        q = q.lte('superficie_m2', params.surfaceMax!);
      }
      if (params.chambres != null && params.chambres! > 0) {
        q = q.eq('chambres', params.chambres!);
      }

      // Recherche plein texte simple
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
          .map(
            (r) => _rowToModel(
              r,
              photos: photosMap[r['id'].toString()] ?? const [],
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  // =============================== CRUD ===============================

  /// Crée un logement et renvoie son ID.
  Future<String> create(LogementModel data) async {
    try {
      final uid = _uidOrThrow();
      final payload = _modelToDbMap(data)
        // pas de `photos` ici, uniquement les champs de la table
        ..['user_id'] = uid;

      final row = await _sb.from(_kTable).insert(payload).select('id').single();
      return row['id'].toString();
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  /// Met à jour un logement avec un patch de champs.
  Future<void> update(String id, Map<String, dynamic> changes) async {
    if (changes.isEmpty) return;
    try {
      await _sb.from(_kTable).update(changes).eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  /// Met à jour un logement à partir d'un modèle (sans gérer les photos).
  Future<void> updateFromModel(String id, LogementModel patch) async {
    await update(id, _modelToDbMap(patch)); // toujours sans `photos` ici
  }

  /// Supprime un logement (et ses photos si la cascade n'est pas configurée).
  Future<void> delete(String id) async {
    try {
      // Nettoyage des photos au cas où la contrainte ON CASCADE n'est pas en place
      await _sb.from(_kTablePhotos).delete().eq('logement_id', id);
      await _sb.from(_kTable).delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  /// Remplace toutes les photos d'un logement par la liste `urls` (position = index).
  Future<void> setPhotos(String logementId, List<String> urls) async {
    try {
      await _sb.from(_kTablePhotos).delete().eq('logement_id', logementId);
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }

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
    if (payload.isEmpty) return;

    try {
      await _sb.from(_kTablePhotos).insert(payload);
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  // ============================ Contact ============================

  /// Récupère le numéro de téléphone de contact d'un logement.
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

  /// Met à jour le numéro de téléphone de contact d'un logement.
  Future<void> updateContactPhone(String logementId, String phone) async {
    try {
      await _sb
          .from(_kTable)
          .update({'contact_telephone': phone}).eq('id', logementId);
    } on PostgrestException catch (e) {
      throw Exception(e.message ?? 'Erreur base de données');
    }
  }

  // ========================= Storage (photos) =========================

  /// Upload une photo dans le bucket "logements" et renvoie la clé + URL publique.
  Future<({String key, String publicUrl})> uploadPhoto({
    required Uint8List bytes,
    required String filename,
    String? logementId,
  }) async {
    final uid =
        _uidOrThrow(); // impose l'authentification et fournit le 1er segment

    // Nom de fichier “safe”
    final safeName =
        filename.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]+'), '_');

    // chemin = <UID>/<logementId|tmp>/<timestamp>_<safeName>
    final ts = DateTime.now().millisecondsSinceEpoch;
    final base = (logementId != null && logementId.isNotEmpty)
        ? '$uid/$logementId'
        : '$uid/tmp';
    final key = '$base/${ts}_$safeName';

    try {
      await _sb.storage.from(_kBucketPhotos).uploadBinary(
            key,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/*',
            ),
          );
      final url = _sb.storage.from(_kBucketPhotos).getPublicUrl(key);
      return (key: key, publicUrl: url);
    } on StorageException catch (e) {
      throw Exception(e.message ?? 'Erreur upload');
    }
  }

  /// Crée une URL signée temporaire pour une photo.
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
