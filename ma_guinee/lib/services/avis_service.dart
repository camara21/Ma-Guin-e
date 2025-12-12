import 'package:supabase_flutter/supabase_flutter.dart';

class AvisService {
  final _supabase = Supabase.instance.client;

  /// Ajoute ou modifie un avis (empêche les doublons via upsert)
  Future<void> ajouterOuModifierAvis({
    required String contexte,
    required String cibleId,
    required String utilisateurId,
    required int note,
    required String commentaire,
  }) async {
    if (!_isUuid(cibleId)) {
      throw Exception(
        "Le champ cibleId doit être un UUID valide. Reçu : $cibleId",
      );
    }

    if (!_isUuid(utilisateurId)) {
      throw Exception(
        "Le champ utilisateurId doit être un UUID valide. Reçu : $utilisateurId",
      );
    }

    await _supabase.from('avis').upsert(
      {
        'utilisateur_id': utilisateurId,
        'contexte': contexte,
        'cible_id': cibleId,
        'note': note,
        'commentaire': commentaire,
      },
      onConflict: 'utilisateur_id,contexte,cible_id',
    );
  }

  /// Récupère les avis pour une cible donnée (prestataire, resto, etc.)
  Future<List<Map<String, dynamic>>> recupererAvis({
    required String contexte,
    required String cibleId,
  }) async {
    final response = await _supabase
        .from('avis')
        .select(
          'note, commentaire, created_at, utilisateurs(nom, prenom, photo_url)',
        )
        .eq('contexte', contexte)
        .eq('cible_id', cibleId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Calcule la note moyenne pour une cible donnée
  Future<double> noteMoyenne(String contexte, String cibleId) async {
    final response = await _supabase
        .from('avis')
        .select('note')
        .eq('contexte', contexte)
        .eq('cible_id', cibleId);

    if (response.isEmpty) return 0;
    final notes = response.map((e) => e['note'] as int).toList();
    return notes.reduce((a, b) => a + b) / notes.length;
  }

  /// Vérifie si l'utilisateur a déjà laissé un avis
  Future<Map<String, dynamic>?> avisUtilisateur({
    required String contexte,
    required String cibleId,
    required String utilisateurId,
  }) async {
    final res = await _supabase
        .from('avis')
        .select()
        .eq('contexte', contexte)
        .eq('cible_id', cibleId)
        .eq('utilisateur_id', utilisateurId)
        .maybeSingle();

    return res;
  }

  /// Vérifie si la chaîne est un UUID valide
  bool _isUuid(String id) {
    final uuidRegExp = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegExp.hasMatch(id);
  }
}
