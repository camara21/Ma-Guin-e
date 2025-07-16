import 'package:flutter/material.dart';

class FavorisProvider extends ChangeNotifier {
  final List<String> _favorisIds = []; // Liste d’IDs (annonce, lieu, etc.)

  List<String> get favoris => _favorisIds;

  bool estFavori(String id) => _favorisIds.contains(id);

  void ajouter(String id) {
    if (!_favorisIds.contains(id)) {
      _favorisIds.add(id);
      notifyListeners();
    }
  }

  void retirer(String id) {
    if (_favorisIds.contains(id)) {
      _favorisIds.remove(id);
      notifyListeners();
    }
  }

  void toggle(String id) {
    if (estFavori(id)) {
      retirer(id);
    } else {
      ajouter(id);
    }
  }

  void clear() {
    _favorisIds.clear();
    notifyListeners();
  }
}
