import 'dart:typed_data';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final SupabaseClient _sb = Supabase.instance.client;

  /// Vérifie que l'utilisateur est connecté et retourne son ID
  String _requireUserId() {
    final user = _sb.auth.currentUser;
    if (user == null) {
      throw StateError("Vous devez être connecté pour téléverser un fichier.");
    }
    return user.id;
  }

  /// Upload d’un fichier (en bytes) dans un bucket.
  /// Retourne le chemin de l’objet dans le storage.
  Future<String> uploadFile({
    required String bucket,
    required String filePathOrBytesName,
    required Uint8List bytes,
  }) async {
    final String uid = _requireUserId(); // ✅ contrôle connexion
    final String ext = p.extension(filePathOrBytesName);
    final String filename = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final String objectPath = 'u/$uid/$filename'; // chemin lié à l’utilisateur

    final String? contentType = lookupMimeType(filePathOrBytesName);
    await _sb.storage.from(bucket).uploadBinary(
      objectPath,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: false,
      ),
    );

    return objectPath; // à stocker en BDD
  }

  /// URL publique (si le bucket est public)
  String publicUrl(String bucket, String objectPath) {
    return _sb.storage.from(bucket).getPublicUrl(objectPath);
  }

  /// URL signée (si le bucket est privé)
  Future<String> signedUrl(
    String bucket,
    String objectPath, {
    int expiresInSeconds = 3600,
  }) {
    return _sb.storage.from(bucket).createSignedUrl(objectPath, expiresInSeconds);
  }
}
