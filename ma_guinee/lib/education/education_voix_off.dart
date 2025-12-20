// lib/education/education_voix_off.dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tts_text_normalizer.dart';

class EducationVoixOff {
  EducationVoixOff._();
  static final EducationVoixOff instance = EducationVoixOff._();

  static const String _clePrefsActif = 'education_voix_off_actif';

  final FlutterTts _tts = FlutterTts();
  final Random _rng = Random();

  bool _initialise = false;
  bool _prefsChargees = false;

  bool actif = true;

  final List<String> _queue = <String>[];
  bool _isSpeaking = false;

  static const List<String> _pCorrect = [
    'Bonne réponse !',
    'Bravo !',
    'Excellent !',
    'Génial !',
    'Parfait !',
    'Correct !',
    'Tu as raison !',
    'Super !',
    'Bien joué !',
  ];

  static const List<String> _pFaux = [
    'Mauvaise réponse.',
    'Ce n’est pas correct.',
    'Pas tout à fait.',
  ];

  Future<void> initialiser() async {
    // Charger préférence actif (une seule fois)
    if (!_prefsChargees) {
      _prefsChargees = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        actif = prefs.getBool(_clePrefsActif) ?? true;
      } catch (_) {
        actif = true;
      }
    }

    if (_initialise) return;
    _initialise = true;

    try {
      if (!kIsWeb) {
        await _tts.awaitSpeakCompletion(true);
      }

      // ✅ Réglages plus "humains" (à ajuster si besoin)
      // Trop lent => robot. Trop rapide => avale les mots.
      await _tts.setSpeechRate(0.56);
      await _tts.setPitch(1.03);
      await _tts.setVolume(1.0);

      await _setLangueFrFallback();
      await _choisirVoixFrSiPossible();

      _tts.setCompletionHandler(() async {
        _isSpeaking = false;

        // ✅ mini pause pour laisser la phrase "se poser"
        await Future.delayed(const Duration(milliseconds: 180));

        _dequeueAndSpeak();
      });

      _tts.setCancelHandler(() async {
        _isSpeaking = false;
        await Future.delayed(const Duration(milliseconds: 120));
        _dequeueAndSpeak();
      });

      _tts.setErrorHandler((msg) async {
        debugPrint('TTS error: $msg');
        _isSpeaking = false;
        await Future.delayed(const Duration(milliseconds: 120));
        _dequeueAndSpeak();
      });
    } catch (e) {
      debugPrint('TTS init erreur: $e');
    }
  }

  Future<void> definirActif(bool valeur) async {
    actif = valeur;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_clePrefsActif, valeur);
    } catch (_) {}

    if (!actif) {
      await arreter();
    }
  }

  Future<void> basculer() => definirActif(!actif);

  Future<void> arreter() async {
    try {
      _queue.clear();
      _isSpeaking = false;
      await _tts.stop();
    } catch (_) {}
  }

  /// Relire la question: stop, vide la file, puis relit.
  Future<void> relireQuestion(String question) async {
    await initialiser();
    if (!actif) return;

    await arreter();
    final t = _normaliserPourTts(question);
    if (t.isEmpty) return;

    _enqueue(t);
  }

  /// Lire la question: ajoute dans la file
  Future<void> lireQuestion(String question) async {
    await initialiser();
    if (!actif) return;

    final t = _normaliserPourTts(question);
    if (t.isEmpty) return;

    _enqueue(t);
  }

  /// Feedback après validation
  Future<void> feedback({
    required bool correct,
    String? explicationSiFaux,
  }) async {
    await initialiser();
    if (!actif) return;

    if (correct) {
      final msg = _pCorrect[_rng.nextInt(_pCorrect.length)];
      _enqueue(_normaliserPourTts(msg));
      return;
    }

    final msg = _pFaux[_rng.nextInt(_pFaux.length)];
    _enqueue(_normaliserPourTts(msg));

    final exp = (explicationSiFaux ?? '').trim();
    if (exp.isNotEmpty) {
      _enqueue(_normaliserPourTts(exp));
    }
  }

  void _enqueue(String texte) {
    final t = texte.trim();
    if (t.isEmpty) return;

    _queue.add(t);

    // ✅ Si rien ne parle, on démarre
    if (!_isSpeaking) _dequeueAndSpeak();
  }

  Future<void> _dequeueAndSpeak() async {
    if (!actif) return;
    if (_isSpeaking) return;
    if (_queue.isEmpty) return;

    final next = _queue.removeAt(0);
    _isSpeaking = true;

    try {
      // ❌ Avant: stop() ici => coupe la fin des phrases sur certains moteurs
      // ✅ Maintenant: on laisse le moteur gérer correctement la fin.
      await _tts.speak(next);
    } catch (e) {
      debugPrint('TTS speak erreur: $e');
      _isSpeaking = false;
      Future.microtask(_dequeueAndSpeak);
    }
  }

  Future<void> _setLangueFrFallback() async {
    try {
      final r1 = await _tts.setLanguage('fr-FR');
      if (_ok(r1)) return;
      final r2 = await _tts.setLanguage('fr_FR');
      if (_ok(r2)) return;
      final r3 = await _tts.setLanguage('fr');
      if (_ok(r3)) return;
    } catch (_) {}
  }

  Future<void> _choisirVoixFrSiPossible() async {
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) return;

      Map? chosen;

      // 1) préférer une voix fr + "network/enhanced" si dispo
      for (final v in voices) {
        if (v is! Map) continue;
        final locale = (v['locale'] ?? v['language'] ?? '').toString().toLowerCase();
        final name = (v['name'] ?? '').toString().toLowerCase();

        final isFr = locale.contains('fr') || name.contains('fr');
        if (!isFr) continue;

        // heuristique: certaines voix contiennent "enhanced"/"network"/"premium"
        final qualityHint = name.contains('enhanced') ||
            name.contains('network') ||
            name.contains('premium');

        if (qualityHint) {
          chosen = v;
          break;
        }
        chosen ??= v;
      }

      if (chosen != null) {
        final name = chosen['name'];
        final locale = chosen['locale'] ?? chosen['language'];
        if (name != null && locale != null) {
          await _tts.setVoice({'name': name, 'locale': locale});
        }
      }
    } catch (_) {}
  }

  bool _ok(dynamic res) {
    if (res == null) return true;
    if (res is int) return res == 1;
    if (res is String) return res.toLowerCase().contains('success');
    return true;
  }

  String _normaliserPourTts(String input) {
    final t = input.trim();
    if (t.isEmpty) return '';
    return TtsTextNormalizer.normalizeFr(t);
  }
}
