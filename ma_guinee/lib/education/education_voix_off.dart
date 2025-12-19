// lib/education/education_voix_off.dart

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tts_text_normalizer.dart';

/// Service Voix-Off (TTS)
/// Règles :
/// - Lire uniquement la question (jamais les réponses)
/// - Lire l'explication uniquement si la réponse est fausse
/// - Possibilité d'activer/désactiver (persisté)
///
/// Améliorations :
/// - File d'attente pour éviter que certaines phrases ne soient "sautées"
/// - Relire = stop + vider file + speak
/// - Feedback motivant (phrases correctes aléatoires)
/// - Normalisation FR (chiffres / symboles / ponctuation) via TtsTextNormalizer
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

      // Paramètres (ajustables)
      await _tts.setSpeechRate(0.50); // un peu plus naturel
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);

      await _setLangueFrFallback();
      await _choisirVoixFrSiPossible();

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        _dequeueAndSpeak();
      });
      _tts.setCancelHandler(() {
        _isSpeaking = false;
        _dequeueAndSpeak();
      });
      _tts.setErrorHandler((msg) {
        debugPrint('TTS error: $msg');
        _isSpeaking = false;
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

  /// Compat: ancien appel éventuel
  Future<void> lireExplicationSiFaux({
    required bool estCorrect,
    required String explication,
  }) async {
    await feedback(
      correct: estCorrect,
      explicationSiFaux: estCorrect ? null : explication,
    );
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
    _queue.add(texte);
    if (!_isSpeaking) _dequeueAndSpeak();
  }

  Future<void> _dequeueAndSpeak() async {
    if (!actif) return;
    if (_isSpeaking) return;
    if (_queue.isEmpty) return;

    final next = _queue.removeAt(0);
    _isSpeaking = true;

    try {
      // Stop léger pour éviter superposition
      await _tts.stop();
      await Future.delayed(const Duration(milliseconds: 90));
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
      for (final v in voices) {
        if (v is Map) {
          final locale =
              (v['locale'] ?? v['language'] ?? '').toString().toLowerCase();
          final name = (v['name'] ?? '').toString().toLowerCase();
          if (locale.contains('fr') || name.contains('fr')) {
            chosen = v;
            break;
          }
        }
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

  /// ✅ IMPORTANT : normalisation "naturelle" via ton fichier:
  /// lib/education/tts_text_normalizer.dart
  String _normaliserPourTts(String input) {
    final t = input.trim();
    if (t.isEmpty) return '';
    return TtsTextNormalizer.normalizeFr(t);
  }
}
