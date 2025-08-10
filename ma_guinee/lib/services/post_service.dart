// lib/services/post_service.dart
import 'dart:typed_data';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostService {
  final _sb = Supabase.instance.client;

  /// Feed principal (ramène aussi l'auteur si la FK est nommée posts_author_id_fkey)
  Future<List<Map<String, dynamic>>> fetchFeed({
    int limit = 12,
    int offset = 0,
  }) async {
    final selBase = '''
      id, author_id, text_content,
      likes_count, comments_count, views_count, shares_count, created_at,
      post_media!inner(url, type, position)
    ''';

    dynamic rows;

    // 1) Essai avec l'auteur aliasé "author"
    try {
      rows = await _sb
          .from('posts')
          .select('''
            $selBase,
            author:profiles!posts_author_id_fkey(id, full_name, avatar_url)
          ''')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
    } on PostgrestException {
      // 2) Fallback sans l'auteur si le nom de FK diffère
      rows = await _sb
          .from('posts')
          .select(selBase)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
    }

    return (rows as List)
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// URL signée pour un média du bucket "posts" (fonctionne même si le bucket est public)
  Future<String> getSignedUrl(String path, {int expiresInSeconds = 3600}) async {
    return await _sb.storage.from('posts').createSignedUrl(path, expiresInSeconds);
  }

  /// Incrémente une vue unique (RPC côté DB conseillé: increment_unique_view(p_post_id uuid))
  Future<void> incrementView(String postId) async {
    try {
      await _sb.rpc('increment_unique_view', params: {'p_post_id': postId});
    } catch (_) {
      // ignore (pas bloquant)
    }
  }

  /// Incrémente un partage (RPC conseillé: increment_share(p_post_id uuid))
  /// Fallback: insère dans post_shares si la table existe.
  Future<void> incrementShare(String postId) async {
    try {
      await _sb.rpc('increment_share', params: {'p_post_id': postId});
      return;
    } catch (_) {
      // fallback: si tu as une table "post_shares(user_id, post_id)" avec trigger qui maj shares_count
      final userId = _sb.auth.currentUser?.id;
      if (userId == null) return;
      try {
        await _sb.from('post_shares').insert({'post_id': postId, 'user_id': userId});
      } catch (_) {
        // dernier recours: mise à jour directe (nécessite politique RLS appropriée)
        try {
          await _sb.from('posts').update({'shares_count': _sb.rpc('coalesce_int', params: {'x': 0})}).eq('id', postId);
        } catch (_) {}
      }
    }
  }

  /// Like/Unlike: RPC 'toggle_like' -> { is_liked bool, likes_count int }
  Future<Map<String, dynamic>> toggleLike(String postId) async {
    final res = await _sb.rpc('toggle_like', params: {'p_post_id': postId});
    return Map<String, dynamic>.from(res as Map);
  }

  /// Liste des commentaires (les compteurs sont stockés sur posts.comments_count via trigger côté DB)
  Future<List<Map<String, dynamic>>> listComments(String postId, {int limit = 100}) async {
    final rows = await _sb
        .from('post_comments')
        .select('id, post_id, user_id, content, created_at')
        .eq('post_id', postId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Ajout d’un commentaire (utilisateur requis)
  Future<Map<String, dynamic>> addComment(String postId, String content) async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null) throw 'Connexion requise';

    final rows = await _sb
        .from('post_comments')
        .insert({
          'post_id': postId,
          'user_id': userId,
          'content': content,
        })
        .select()
        .limit(1);

    return Map<String, dynamic>.from((rows as List).first as Map);
  }

  /// Publication : upload média + création post + post_media
  Future<Map<String, dynamic>> createPostWithMedia({
    required Uint8List bytes,
    required String filename,
    String? mimeType,
    String textContent = '',
  }) async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null) throw 'Connexion requise';

    final mt = mimeType ?? lookupMimeType(filename, headerBytes: _firstBytes(bytes)) ?? 'application/octet-stream';
    final isVideo = mt.startsWith('video/');
    final isImage = mt.startsWith('image/');

    // chemin unique
    final ext = _extFromFilename(filename);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final storagePath = 'users/$userId/$stamp$ext';

    // 1) Upload (bucket "posts")
    await _sb.storage.from('posts').uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: mt, upsert: false),
        );

    try {
      // 2) Crée le post
      final postRows = await _sb
          .from('posts')
          .insert({
            'author_id': userId,
            'text_content': textContent,
          })
          .select()
          .limit(1);

      final post = Map<String, dynamic>.from((postRows as List).first as Map);
      final postId = post['id'] as String;

      // 3) Ajoute le média (position 0)
      await _sb.from('post_media').insert({
        'post_id': postId,
        'url': storagePath,
        'type': isVideo ? 'video' : (isImage ? 'image' : 'doc'),
        'position': 0,
      });

      return post;
    } catch (e) {
      // rollback du fichier si l'insert échoue
      try { await _sb.storage.from('posts').remove([storagePath]); } catch (_) {}
      rethrow;
    }
  }

  /// Suppression d’un post + TOUS ses médias
  Future<void> deletePostAndMedia(String postId) async {
    final medias = await _sb.from('post_media').select('url').eq('post_id', postId);
    final paths = (medias as List)
        .map((e) => (e as Map)['url']?.toString())
        .where((p) => p != null && p!.isNotEmpty)
        .cast<String>()
        .toList();

    if (paths.isNotEmpty) {
      await _sb.storage.from('posts').remove(paths).catchError((_) {});
    }
    await _sb.from('posts').delete().eq('id', postId);
  }

  // ---------------- utils ----------------

  String _extFromFilename(String name) {
    final i = name.lastIndexOf('.');
    if (i == -1) return '';
    return name.substring(i);
  }

  List<int> _firstBytes(Uint8List b) {
    final n = b.length < 32 ? b.length : 32;
    return b.sublist(0, n);
  }
}
