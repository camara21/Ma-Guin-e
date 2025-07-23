import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FavorisProvider extends ChangeNotifier {
  final List<String> _favorisIds = [];
  bool _isLoading = false;

  List<String> get favoris => _favorisIds;
  bool get isLoading => _isLoading;

  /// Charge tous les favoris de l'utilisateur connecté
  Future<void> loadFavoris() async {
    _isLoading = true;
    notifyListeners();

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _favorisIds.clear();
      _isLoading = false;
      notifyListeners();
      return;
    }

    final data = await Supabase.instance.client
        .from('favoris')
        .select('annonce_id')
        .eq('utilisateur_id', user.id);

    _favorisIds
      ..clear()
      ..addAll(
        (data as List).map<String>((e) => e['annonce_id'].toString()),
      );

    _isLoading = false;
    notifyListeners();
  }

  /// Vérifie si une annonce est dans les favoris
  bool estFavori(String annonceId) => _favorisIds.contains(annonceId);

  /// Ajoute/Supprime un favori côté base ET local
  Future<void> toggleFavori(String annonceId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    if (estFavori(annonceId)) {
      // Supprimer le favori en base
      await Supabase.instance.client
          .from('favoris')
          .delete()
          .eq('utilisateur_id', user.id)
          .eq('annonce_id', annonceId);
      _favorisIds.remove(annonceId);
    } else {
      // Ajouter dans la base
      await Supabase.instance.client.from('favoris').insert({
        'utilisateur_id': user.id,
        'annonce_id': annonceId,
        'date_ajout': DateTime.now().toIso8601String(),
      });
      _favorisIds.add(annonceId);
    }
    notifyListeners();
  }

  /// Réinitialiser les favoris (utile lors de la déconnexion)
  void clear() {
    _favorisIds.clear();
    notifyListeners();
  }
}
