import 'package:flutter/foundation.dart';
import '../models/annonce_model.dart';
import '../services/annonce_service.dart';

class AnnonceProvider extends ChangeNotifier {
  List<AnnonceModel> _annonces = [];
  bool _isLoading = false;

  List<AnnonceModel> get annonces => _annonces;
  bool get isLoading => _isLoading;

  /// 🔄 Charger toutes les annonces
  Future<void> loadAnnonces() async {
    _isLoading = true;
    notifyListeners();
    try {
      _annonces = await AnnonceService.getAllAnnonces();
    } catch (e) {
      debugPrint("Erreur chargement annonces: $e");
      _annonces = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ➕ Ajouter une annonce
  Future<void> addAnnonce(AnnonceModel annonce) async {
    try {
      await AnnonceService.addAnnonce(annonce);
      _annonces.insert(0, annonce);
      notifyListeners();
    } catch (e) {
      debugPrint("Erreur ajout annonce: $e");
      rethrow;
    }
  }

  /// 🗑 Supprimer une annonce
  Future<void> deleteAnnonce(String id) async {
    try {
      await AnnonceService.deleteAnnonce(id);
      _annonces.removeWhere((a) => a.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint("Erreur suppression annonce: $e");
      rethrow;
    }
  }

  /// 🔍 Filtrer par catégorie
  List<AnnonceModel> filterByCategorie(String categorie) {
    if (categorie.toLowerCase() == 'tous') return _annonces;
    return _annonces
        .where((a) => a.categorie.toLowerCase() == categorie.toLowerCase())
        .toList();
    }

  /// 🔍 Annonces par utilisateur
  List<AnnonceModel> annoncesByUser(String userId) {
    return _annonces
        .where((a) => a.userId.toLowerCase() == userId.toLowerCase())
        .toList();
  }
}
