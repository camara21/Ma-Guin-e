// lib/services/app_cache.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache SWR simple : mémoire (instantané) + persistant (SharedPreferences).
/// Stockage par clé `key` :
///   '${key}:data' -> JSON List<Map<String, dynamic>>
///   '${key}:ts'   -> int (epoch millis)
class AppCache {
  AppCache._();
  static final AppCache I = AppCache._();

  final Map<String, _CacheEntry> _mem = {};

  // ---------------- Mémoire ----------------

  /// Lit depuis le cache mémoire. Retourne null si expiré (maxAge) ou absent.
  List<Map<String, dynamic>>? getListMemory(String key, {Duration? maxAge}) {
    final e = _mem[key];
    if (e == null) return null;
    if (maxAge != null && DateTime.now().difference(e.time) > maxAge) return null;
    return _cloneList(e.data);
  }

  /// Écrit en mémoire (et sur disque si [persist] = true).
  void setList(String key, List<Map<String, dynamic>> data, {bool persist = true}) async {
    final cloned = _cloneList(data);
    _mem[key] = _CacheEntry(cloned, DateTime.now());

    if (persist) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('${key}:data', jsonEncode(cloned));
        await prefs.setInt('${key}:ts', DateTime.now().millisecondsSinceEpoch);
      } catch (_) {}
    }
  }

  /// Supprime une entrée en mémoire + disque.
  void invalidate(String key) async {
    _mem.remove(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${key}:data');
      await prefs.remove('${key}:ts');
    } catch (_) {}
  }

  // --------------- Persistant (disque) ---------------

  /// Lit depuis le disque. Retourne null si expiré (maxAge) ou absent.
  /// Hydrate aussi la mémoire pour les prochains appels.
  Future<List<Map<String, dynamic>>?> getListPersistent(String key, {Duration? maxAge}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString('${key}:data');
      final ts = prefs.getInt('${key}:ts');
      if (dataStr == null || ts == null) return null;

      if (maxAge != null) {
        final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
        if (age > maxAge) return null;
      }

      final raw = jsonDecode(dataStr) as List<dynamic>;
      final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);

      _mem[key] = _CacheEntry(_cloneList(list), DateTime.fromMillisecondsSinceEpoch(ts));
      return list;
    } catch (_) {
      return null;
    }
  }

  // --------------- Compatibilité arrière ---------------

  /// [DEPRECATED] Ancien nom : lecture mémoire.
  @deprecated
  List<Map<String, dynamic>>? getList(String key, {Duration? maxAge}) =>
      getListMemory(key, maxAge: maxAge);

  /// [DEPRECATED] Ancien async : lecture disque.
  @deprecated
  Future<List<Map<String, dynamic>>?> getListAsync(String key, {Duration? maxAge}) =>
      getListPersistent(key, maxAge: maxAge);

  // ---------------- Utils ----------------

  static List<Map<String, dynamic>> _cloneList(List<Map<String, dynamic>> src) =>
      List<Map<String, dynamic>>.from(src.map((e) => Map<String, dynamic>.from(e)));
}

class _CacheEntry {
  final List<Map<String, dynamic>> data;
  final DateTime time;
  _CacheEntry(this.data, this.time);
}
