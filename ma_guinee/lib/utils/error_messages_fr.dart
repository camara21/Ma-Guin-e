// lib/utils/error_messages_fr.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui'; // ✅ pour PlatformDispatcher

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// ============================================================================
/// 1) MESSAGES FR (Supabase + réseau + fallback) — sans afficher URLs/technique
/// ============================================================================

String frMessageFromError(Object error, [StackTrace? st]) {
  // --- Réseau
  if (error is SocketException) {
    return "Pas de connexion internet. Vérifiez votre réseau et réessayez.";
  }
  if (error is TimeoutException) {
    return "Connexion trop lente. Veuillez réessayer.";
  }
  if (error is HttpException) {
    return "Erreur réseau. Vérifiez votre connexion et réessayez.";
  }

  // --- Supabase
  if (error is AuthException) return _frAuth(error.message);
  if (error is PostgrestException)
    return _frHttp(error.code ?? '', error.message);
  if (error is StorageException)
    return "Erreur de stockage. Veuillez réessayer.";

  // --- Détection offline à partir du texte (fallback)
  final raw = error.toString();
  if (_looksLikeOffline(raw)) {
    return "Pas de connexion internet. Vérifiez votre réseau et réessayez.";
  }

  // --- Erreurs Flutter techniques (zone mismatch, etc.) => message user-safe
  if (raw.toLowerCase().contains('zone mismatch')) {
    return "Une erreur s’est produite. Veuillez réessayer.";
  }

  return "Une erreur s’est produite. Veuillez réessayer.";
}

bool _looksLikeOffline(String raw) {
  final s = raw.toLowerCase();
  if (s.contains('failed host lookup')) return true;
  if (s.contains('no address associated with hostname')) return true;
  if (s.contains('socketexception')) return true;
  if (s.contains('clientexception') && s.contains('socketexception'))
    return true;
  if (s.contains('network is unreachable')) return true;

  // ⚠️ "connection refused" n’est PAS toujours offline (peut être serveur)
  // On ne le considère pas comme offline dur ici pour éviter faux positifs.
  // if (s.contains('connection refused')) return true;

  // Realtime websocket offline
  if (s.contains('realtime') &&
      (s.contains('channelerror') || s.contains('websocket'))) {
    if (s.contains('failed host lookup') || s.contains('socketexception'))
      return true;
  }
  return false;
}

String _frHttp(String code, String message) {
  final m = message.toLowerCase();

  if (m.contains('row-level security') || m.contains('rls')) {
    return "Accès refusé par la politique de sécurité.";
  }

  if ((m.contains('duplicate key') && m.contains('unique')) ||
      m.contains('23505')) {
    return "Cet enregistrement existe déjà.";
  }

  if (code == '404' || m.contains('not found')) return "Ressource introuvable.";
  if (code == '403' || m.contains('forbidden')) return "Accès refusé.";
  if (code == '401' || m.contains('unauthorized'))
    return "Authentification requise.";

  return "Une erreur serveur est survenue. Veuillez réessayer.";
}

String _frAuth(String raw) {
  final msg = raw.toLowerCase().trim();

  if (msg.contains('user already registered') ||
      msg.contains('already registered') ||
      msg.contains('user already exists')) {
    return "Cet e-mail est déjà utilisé. Connectez-vous ou utilisez un autre e-mail.";
  }

  if (msg.contains('invalid login') ||
      msg.contains('invalid credentials') ||
      msg.contains('invalid email or password')) {
    return "E-mail ou mot de passe incorrect.";
  }

  if (msg.contains('email not confirmed')) {
    return "E-mail non confirmé. Vérifiez votre boîte mail.";
  }

  if (msg.contains('password') &&
      (msg.contains('too short') ||
          msg.contains('at least') ||
          msg.contains('6 characters'))) {
    return "Mot de passe trop court. Il doit contenir au moins 6 caractères.";
  }

  if (msg.contains('password') && msg.contains('weak')) {
    return "Mot de passe trop faible.";
  }

  if (msg.contains('token has expired') ||
      msg.contains('jwt expired') ||
      (msg.contains('session') && msg.contains('expire'))) {
    return "Session expirée. Veuillez vous reconnecter.";
  }

  if (msg.contains('rate limit') || msg.contains('too many requests')) {
    return "Trop de tentatives. Réessayez plus tard.";
  }

  return "Une erreur d’authentification est survenue. Veuillez réessayer.";
}

/// ============================================================================
/// 2) OVERLAY GLOBAL — Centralisé ici
///    Objectif : PAS de spam, et OFFLINE uniquement si internet réellement absent
/// ============================================================================

enum SoneyaErrorKind { offline, weakNetwork, auth, server, unknown }

class SoneyaUiError {
  final SoneyaErrorKind kind;
  final String title;
  final String message;
  final String actionLabel;
  final bool dismissible;
  final Future<void> Function()? onRetry;

  const SoneyaUiError({
    required this.kind,
    required this.title,
    required this.message,
    this.actionLabel = "Veuillez réessayer",
    this.dismissible = true,
    this.onRetry,
  });
}

class SoneyaErrorCenter {
  SoneyaErrorCenter._();

  static final ValueNotifier<SoneyaUiError?> _current =
      ValueNotifier<SoneyaUiError?>(null);

  static ValueListenable<SoneyaUiError?> get listenable => _current;
  static SoneyaUiError? get current => _current.value;
  static bool get isShowing => _current.value != null;

  // Couleurs Soneya
  static const Color soneyaBlue = Color(0xFF1175F7);
  static const Color soneyaGreen = Color(0xFF16A34A);

  // Asset satellite
  static const String satelliteAsset = 'assets/satelite_soneya.png';

  // Anti-spam overlay
  static String? _lastFingerprint;
  static DateTime? _lastShownAt;

  // Préchargement asset
  static bool _assetsPrecached = false;
  static Future<void>? _precachingFuture;

  // =============================
  // Tuning réseau (anti faux positifs)
  // =============================

  /// Ne rien afficher au boot (le temps que les providers / supabase se calent)
  static const Duration startupGrace = Duration(seconds: 6);

  /// Ignore les micro-coupures (DNS/wifi switch). On vérifie après un délai.
  static const Duration offlineMinDelay = Duration(seconds: 5);

  /// Si aucun succès réseau depuis X, on commence à considérer offline sérieux.
  static const Duration offlineAfterNoSuccess = Duration(seconds: 25);

  /// Nombre d’échecs consécutifs avant de suspecter offline (évite faux positifs).
  static const int offlineFailThreshold = 6;

  /// Timeout / réseau faible : on n’affiche que si ça insiste ET sans succès récent
  static const int weakFailThreshold = 6;
  static const Duration weakAfterNoSuccess = Duration(seconds: 25);

  /// Cooldown global pour ne pas spammer la même erreur
  static const Duration overlayCooldown = Duration(seconds: 12);

  static DateTime _appStartedAt = DateTime.now();
  static DateTime _lastNetworkSuccessAt = DateTime.now();
  static int _consecutiveNetworkFails = 0;
  static int _consecutiveTimeoutFails = 0;

  static Timer? _offlineTimer;

  // état offline confirmé (évite oscillations)
  static bool _offlineConfirmed = false;

  // évite plusieurs probes en parallèle
  static bool _offlineProbeInFlight = false;

  // last message shown key for offline
  static String? _lastOfflineKey;

  // ✅ Méthodes attendues par main.dart
  static void markAppStartedNow() {
    final now = DateTime.now();
    _appStartedAt = now;
    _lastNetworkSuccessAt = now;
    _consecutiveNetworkFails = 0;
    _consecutiveTimeoutFails = 0;
    _offlineConfirmed = false;
    _offlineTimer?.cancel();
    _offlineTimer = null;
    if (_current.value?.kind == SoneyaErrorKind.offline) clear();
  }

  static void reportNetworkSuccess() {
    _lastNetworkSuccessAt = DateTime.now();
    _consecutiveNetworkFails = 0;
    _consecutiveTimeoutFails = 0;
    _offlineConfirmed = false;
    _offlineTimer?.cancel();
    _offlineTimer = null;
    if (_current.value?.kind == SoneyaErrorKind.offline) clear();
  }

  static void reportNetworkFailure() {
    _consecutiveNetworkFails += 1;
  }

  static void reportTimeoutFailure() {
    _consecutiveTimeoutFails += 1;
  }

  static bool _inStartupGrace() {
    return DateTime.now().difference(_appStartedAt) < startupGrace;
  }

  static void clear() => _current.value = null;

  static void installGlobalGuards() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (kDebugMode) {
        debugPrint('[FlutterError] ${details.exceptionAsString()}');
        if (details.stack != null) debugPrint(details.stack.toString());
      }
      showException(details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (kDebugMode) {
        debugPrint('[ZoneError] $error');
        debugPrint('$stack');
      }
      showException(error, stack);
      return true;
    };
  }

  static Future<void> runZoned(Future<void> Function() body) async {
    await runZonedGuarded(() async {
      await body();
    }, (error, stack) {
      if (kDebugMode) {
        debugPrint('[runZonedGuarded] $error');
        debugPrint('$stack');
      }
      showException(error, stack);
    });
  }

  static Future<void> precacheAssets(BuildContext context) async {
    if (_assetsPrecached) return;
    _precachingFuture ??= () async {
      try {
        await precacheImage(const AssetImage(satelliteAsset), context);
      } catch (_) {
        // silencieux
      } finally {
        _assetsPrecached = true;
      }
    }();
    await _precachingFuture;
  }

  /// ✅ Confirmation "pas d’internet" :
  /// - si connectivity == none => très probable offline
  /// - sinon (wifi/mobile) on fait un probe DNS rapide
  static Future<bool> _confirmNoInternet() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (result == ConnectivityResult.none) return true;

      // Cas fréquent en Afrique : wifi présent mais pas d’internet -> DNS probe.
      // On fait 2 tentatives très rapides pour éviter faux positifs.
      for (int i = 0; i < 2; i++) {
        try {
          final lookup = await InternetAddress.lookup('example.com')
              .timeout(const Duration(seconds: 2));
          if (lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty) {
            return false; // internet OK
          }
        } catch (_) {
          // continue
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      return true;
    } catch (_) {
      // par prudence : ne pas conclure offline si on n’est pas sûr
      return false;
    }
  }

  static void setOffline(bool offline, {Future<void> Function()? onRetry}) {
    if (_inStartupGrace()) {
      if (!offline && _current.value?.kind == SoneyaErrorKind.offline) clear();
      return;
    }

    if (!offline) {
      _offlineTimer?.cancel();
      _offlineTimer = null;
      _offlineConfirmed = false;
      if (_current.value?.kind == SoneyaErrorKind.offline) clear();
      return;
    }

    // On ne montre pas immédiatement : on attend offlineMinDelay
    _offlineTimer?.cancel();
    _offlineTimer = Timer(offlineMinDelay, () async {
      if (_offlineProbeInFlight) return;
      _offlineProbeInFlight = true;

      try {
        final now = DateTime.now();
        final sinceSuccess = now.difference(_lastNetworkSuccessAt);

        // d’abord : seuils d’échec & pas de succès récent
        final suspectByFails = _consecutiveNetworkFails >= offlineFailThreshold;
        final suspectByTime = sinceSuccess > offlineAfterNoSuccess;

        if (!suspectByFails && !suspectByTime) return;

        // ensuite : confirmation réelle (connectivity + DNS)
        final noInternet = await _confirmNoInternet();
        if (!noInternet) return;

        _offlineConfirmed = true;

        // évite de réafficher offline en boucle si déjà présent
        final key =
            'offline:${sinceSuccess.inSeconds}:${_consecutiveNetworkFails}';
        if (_lastOfflineKey == key &&
            _current.value?.kind == SoneyaErrorKind.offline) return;
        _lastOfflineKey = key;

        _show(
          SoneyaUiError(
            kind: SoneyaErrorKind.offline,
            title: "Une erreur s’est produite",
            message: "Veuillez vérifier votre connexion internet et réessayez.",
            actionLabel: "Veuillez réessayer",
            dismissible: false,
            onRetry: onRetry,
          ),
          fingerprint: "offline_confirmed",
          force: true,
        );
      } finally {
        _offlineProbeInFlight = false;
      }
    });
  }

  static void showException(Object error, [StackTrace? st]) {
    if (_inStartupGrace()) return;

    final raw = error.toString();

    // OFFLINE suspected : on incrémente, puis on passe par la confirmation
    if (error is SocketException || _looksLikeOffline(raw)) {
      reportNetworkFailure();
      setOffline(true);
      return;
    }

    // Timeout : ne pas spammer. On ne montre weakNetwork que si insisté
    if (error is TimeoutException) {
      reportNetworkFailure();
      reportTimeoutFailure();

      final sinceSuccess = DateTime.now().difference(_lastNetworkSuccessAt);
      final shouldShowWeak = (_consecutiveTimeoutFails >= weakFailThreshold) ||
          (sinceSuccess > weakAfterNoSuccess);

      // Si pas assez de signaux => rien (les pages continuent d’utiliser leur cache)
      if (!shouldShowWeak) return;

      // Si offline déjà confirmé, ne pas remplacer l’écran offline
      if (_current.value?.kind == SoneyaErrorKind.offline || _offlineConfirmed)
        return;

      _show(
        const SoneyaUiError(
          kind: SoneyaErrorKind.weakNetwork,
          title: "Connexion instable",
          message: "Votre connexion est trop lente. Veuillez réessayer.",
          actionLabel: "Veuillez réessayer",
        ),
        fingerprint: "weak_network",
      );
      return;
    }

    // Erreurs “serveur/auth/unknown” : on évite d’écraser un offline confirmé
    final msg = frMessageFromError(error, st);
    final kind = _inferKind(error);

    if ((_current.value?.kind == SoneyaErrorKind.offline ||
            _offlineConfirmed) &&
        kind != SoneyaErrorKind.offline) {
      return;
    }

    _show(
      SoneyaUiError(
        kind: kind,
        title: "Une erreur s’est produite",
        message: msg,
        actionLabel: "Veuillez réessayer",
      ),
      fingerprint: "${kind.name}:$msg",
    );
  }

  static SoneyaErrorKind _inferKind(Object e) {
    if (e is AuthException) return SoneyaErrorKind.auth;
    if (e is PostgrestException || e is StorageException)
      return SoneyaErrorKind.server;
    if (e is SocketException) return SoneyaErrorKind.offline;
    if (e is TimeoutException) return SoneyaErrorKind.weakNetwork;
    return SoneyaErrorKind.unknown;
  }

  static void _show(
    SoneyaUiError err, {
    required String fingerprint,
    bool force = false,
  }) {
    final now = DateTime.now();

    if (!force) {
      // cooldown plus strict pour limiter le spam
      if (_lastFingerprint == fingerprint &&
          _lastShownAt != null &&
          now.difference(_lastShownAt!) < overlayCooldown) {
        return;
      }
    }

    _lastFingerprint = fingerprint;
    _lastShownAt = now;
    _current.value = err;
  }

  static Widget overlay() {
    return ValueListenableBuilder<SoneyaUiError?>(
      valueListenable: _current,
      builder: (context, err, _) {
        unawaited(precacheAssets(context));

        if (err == null) return const SizedBox.shrink();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            ScaffoldMessenger.of(context).clearSnackBars();
          } catch (_) {}
        });

        final media = MediaQuery.of(context);
        final bottomSafe = media.padding.bottom;
        final viewInsets = media.viewInsets.bottom;

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: err.dismissible ? clear : null,
                child: Container(color: Colors.black.withOpacity(0.35)),
              ),
            ),

            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    14,
                    14,
                    14,
                    14 + bottomSafe + (viewInsets > 0 ? viewInsets : 0),
                  ),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(maxHeight: media.size.height * 0.62),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const SizedBox(width: 32),
                                Expanded(
                                  child: Text(
                                    err.title,
                                    textAlign: TextAlign.center,
                                    textScaler: const TextScaler.linear(1.0),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (err.dismissible)
                                  InkWell(
                                    onTap: clear,
                                    child: const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Icon(Icons.close, size: 20),
                                    ),
                                  )
                                else
                                  const SizedBox(width: 32),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Satellite
                            SizedBox(
                              height: 170,
                              child: Center(
                                child: Image.asset(
                                  satelliteAsset,
                                  height: 160,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) {
                                    return Container(
                                      width: 160,
                                      height: 160,
                                      decoration: BoxDecoration(
                                        color: soneyaBlue.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: const Icon(
                                        Icons.satellite_alt_rounded,
                                        size: 74,
                                        color: soneyaBlue,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Text(
                                  err.message,
                                  textAlign: TextAlign.center,
                                  textScaler: const TextScaler.linear(1.0),
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 13.5,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final cb = err.onRetry;
                                  if (cb != null) {
                                    await cb();
                                  } else {
                                    clear();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: soneyaBlue,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  err.actionLabel,
                                  textScaler: const TextScaler.linear(1.0),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bandeau rouge haut (uniquement offline confirmé)
            if (err.kind == SoneyaErrorKind.offline)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: const TextScaler.linear(1.0),
                    ),
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      color: Colors.red.shade600,
                      alignment: Alignment.center,
                      child: const Text(
                        "Pas de connexion internet",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.0,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
