import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/error_messages_fr.dart';

// 🔵 même bleu que Splash & Login
const _kAuthPrimary = Color(0xFF0175C2);

/// ===============================================================
/// Helper global : force un message d'erreur en FR
/// ===============================================================
String _friendlyErrorFr(Object error, StackTrace st) {
  if (error is AuthException) {
    final msgLower = error.message.toLowerCase();

    // Cas spécifique : rate-limit reset password
    if (msgLower
        .startsWith('for security purposes, you can only request this after')) {
      return 'Pour des raisons de sécurité, vous devez attendre quelques secondes avant de refaire une demande de réinitialisation.';
    }
  }

  // Fallback : helper générique FR
  return frMessageFromError(error, st);
}

/// ===============================================================
/// Redirect URL : Web -> Netlify / Mobile -> Deep Link
/// ===============================================================
String _resetRedirectUrl() {
  if (kIsWeb) {
    final origin = Uri.base.origin; // ex: https://xxx.netlify.app
    return '$origin/#/reset_password';
  }

  // MOBILE -> deep link vers l’app (configuré dans Supabase + AndroidManifest + Info.plist)
  return 'soneya://auth/reset_password';
}

/// ===========================
/// 1. ForgotPasswordPage
/// ===========================
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sending = true);

    final email = _emailCtrl.text.trim();
    final supa = Supabase.instance.client;
    final redirect = _resetRedirectUrl();

    try {
      await supa.auth.resetPasswordForEmail(
        email,
        redirectTo: redirect.isNotEmpty ? redirect : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Un lien de réinitialisation a été envoyé.'),
        ),
      );

      Navigator.pop(context);
    } catch (e, st) {
      if (!mounted) return;
      final msg = _friendlyErrorFr(e, st);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Mot de passe oublié ?',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text(
                "Entre ton e-mail pour recevoir le lien de réinitialisation.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'E-mail requis';
                  if (!v.contains('@')) return 'E-mail invalide';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sending ? null : _sendReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAuthPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Envoyer le lien'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ===========================
/// 2. ResetPasswordPage
/// ===========================
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _pwd1Ctrl = TextEditingController();
  final _pwd2Ctrl = TextEditingController();

  bool _hasRecovery = false; // est-ce qu’on a une session “recovery”
  bool _busy = false; // bouton en cours
  bool _checkedRecovery =
      false; // est-ce qu’on a fini de vérifier (pour éviter le flash d’erreur)

  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();

    // 1) Prépare la session depuis l’URL (Web) ou mobile
    _prepareRecoverySession();

    // 2) Met à jour l’état si un event arrive après coup (mobile: deep link)
    _authSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((authState) {
      if (!mounted) return;
      final event = authState.event;
      if (event == AuthChangeEvent.passwordRecovery ||
          event == AuthChangeEvent.signedIn) {
        setState(() {
          _hasRecovery = Supabase.instance.client.auth.currentSession != null;
          _checkedRecovery = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    _pwd1Ctrl.dispose();
    _pwd2Ctrl.dispose();
    super.dispose();
  }

  /// ===========================================================
  /// Prépare la session "recovery"
  /// ===========================================================
  Future<void> _prepareRecoverySession() async {
    final supa = Supabase.instance.client;

    if (!kIsWeb) {
      // MOBILE :
      // Cette page est atteinte uniquement quand main.dart reçoit
      // l’event AuthChangeEvent.passwordRecovery et push ResetPasswordPage.
      // On peut donc considérer que le lien est valide.
      setState(() {
        _hasRecovery = true;
        _checkedRecovery = true;
      });
      return;
    }

    // WEB :
    try {
      final uri = Uri.base;

      // 1) Format moderne : ?code=...&type=recovery
      final code = uri.queryParameters['code'];
      final type = uri.queryParameters['type'];
      if (code != null && type == 'recovery') {
        await supa.auth.exchangeCodeForSession(code);
        if (mounted) {
          setState(() {
            _hasRecovery = supa.auth.currentSession != null;
            _checkedRecovery = true;
          });
        }
        return;
      }

      // 2) Cas Netlify HashRouter: ?code=...#/reset_password
      final hasCode = uri.queryParameters['code'];
      final fragPath = uri.fragment.split('?').first;
      if (hasCode != null && fragPath.contains('reset_password')) {
        try {
          await supa.auth.exchangeCodeForSession(hasCode);
        } catch (_) {}
        if (mounted) {
          setState(() {
            _hasRecovery = supa.auth.currentSession != null;
            _checkedRecovery = true;
          });
        }
        return;
      }

      // 3) Ancien format : #access_token=...&refresh_token=...&type=recovery
      if (uri.fragment.isNotEmpty) {
        final frag = Uri.splitQueryString(uri.fragment);
        final refresh = frag['refresh_token'];
        final fType = frag['type'];

        if (refresh != null && fType == 'recovery') {
          await supa.auth.setSession(refresh);
          if (mounted) {
            setState(() {
              _hasRecovery = supa.auth.currentSession != null;
              _checkedRecovery = true;
            });
          }
          return;
        }
      }

      // 4) Fallback : session déjà présente
      if (supa.auth.currentSession != null) {
        if (mounted) {
          setState(() {
            _hasRecovery = true;
            _checkedRecovery = true;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _hasRecovery = false;
          _checkedRecovery = true;
        });
      }
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _hasRecovery = false;
        _checkedRecovery = true;
      });
      final msg = _friendlyErrorFr(e, st);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  /// ===========================================================
  /// Mise à jour du mot de passe
  ///  -> après succès, redirection DIRECTE vers la home (/main)
  ///     sans passer par la page de login
  /// ===========================================================
  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      final pwd = _pwd1Ctrl.text.trim();

      // 1) Mise à jour du mot de passe via la session "recovery"
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: pwd),
      );

      if (!mounted) return;

      // 2) Message d’info en FR
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mot de passe mis à jour. Tu es maintenant connecté avec ton nouveau mot de passe.',
          ),
        ),
      );

      // 3) 👉 Nouveau comportement :
      //    - on NE fait PAS signOut
      //    - on NE va PAS sur /login
      //    - on envoie directement vers la navigation principale (/main)
      //    - on vide la stack pour éviter de revenir sur l’écran de reset
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/main', // correspond à AppRoutes.mainNav
        (_) => false,
      );
    } catch (e, st) {
      if (!mounted) return;
      final msg = _friendlyErrorFr(e, st);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1) On attend d’avoir terminé la détection (surtout Web) → évite les flashs
    if (!_checkedRecovery) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 2) Une fois checké : soit on a une vraie session, soit lien invalide
    final canReset =
        _hasRecovery || Supabase.instance.client.auth.currentSession != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Nouveau mot de passe',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: canReset
            ? Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Text(
                      'Choisis un nouveau mot de passe.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _pwd1Ctrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? '6 caractères minimum'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _pwd2Ctrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirmer le mot de passe',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v != _pwd1Ctrl.text)
                          ? 'Les mots de passe ne correspondent pas'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _updatePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kAuthPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Mettre à jour'),
                      ),
                    ),
                  ],
                ),
              )
            : const Center(
                child: Text(
                  'Lien invalide ou expiré.\nRelance la procédure depuis "Mot de passe oublié ?".',
                  textAlign: TextAlign.center,
                ),
              ),
      ),
    );
  }
}
