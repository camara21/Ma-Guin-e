import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/prestataire_model.dart';

class PrestatairesProvider extends ChangeNotifier {
  final _client = Supabase.instance.client;

  List<PrestataireModel> _prestataires = [];
  bool _loading = false;
  String? _error;

  List<PrestataireModel> get prestataires => _prestataires;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadPrestataires() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final raw = await _client
          .from('prestataires')
          .select()
          .order('created_at', ascending: false);

      _prestataires = (raw as List)
          .map((e) => PrestataireModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _error = e.toString();
      debugPrint('loadPrestataires error: $e\n$st');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Filtre par métier exact (insensible à la casse)
  List<PrestataireModel> byMetier(String metier) {
    final m = metier.toLowerCase();
    return _prestataires.where((p) => p.metier.toLowerCase() == m).toList();
  }

  /// Recherche global
  List<PrestataireModel> search(String q) {
    final s = q.toLowerCase();
    return _prestataires.where((p) {
      return p.metier.toLowerCase().contains(s) ||
          p.category.toLowerCase().contains(s) ||
          p.ville.toLowerCase().contains(s);
    }).toList();
  }
}
