// lib/pages/auth/reset_password_flow.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../routes.dart'; // RecoveryGuard (déclaré dans routes.dart)
import '../../main.dart' show navKey; // pour la redirection finale
import '../../utils/error_messages_fr.dart'; // ⬅️ traduction FR des erreurs

/// -------- Helpers
String _resetRedirectUrl() {
  // Pour Flutter Web (HashRouter), on cible la page dédiée.
  if (kIsWeb) {
    final origin = Uri.base.origin; // ex: https://tangerine-halva-c59cd2.netlify.app
    return '$origin/#/reset_password';
  }
  // Sur mobile: deep link si disponible, sinon '' (laisse Supabase ouvrir l’app)
  return '';
}

/// ===========================
/// Page 1 : ForgotPasswordPage
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && (args['prefillEmail'] as String?)?.isNotEmpty == true) {
      _emailCtrl.text = args['prefillEmail'] as String;
    }
  }

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

    try {
      final redirect = _resetRedirectUrl();
      if (redirect.isEmpty) {
        await supa.auth.resetPasswordForEmail(email);
      } else {
        await supa.auth.resetPasswordForEmail(email, redirectTo: redirect);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Un lien de réinitialisation a été envoyé par e-mail.')),
      );
      Navigator.pop(context); // Retour (page de connexion)
    } catch (e, st) {
      if (!mounted) return;
      // 🇫🇷 message d’erreur utilisateur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(frMessageFromError(e, st))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié ?')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                "Entre ton e-mail pour recevoir un lien de réinitialisation.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final val = v?.trim() ?? '';
                  if (val.isEmpty) return 'E-mail requis';
                  if (!val.contains('@') || !val.contains('.')) return 'E-mail invalide';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sending ? null : _sendReset,
                  child: _sending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
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
/// Page 2 : ResetPasswordPage
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
  bool _busy = false;
  bool _hasRecoverySession = false;

  @override
  void initState() {
    super.initState();
    _prepareRecoverySession();

    // Met à jour l’état si la session arrive après coup
    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (!mounted) return;
      if (event.event == AuthChangeEvent.passwordRecovery ||
          event.event == AuthChangeEvent.signedIn) {
        setState(() =>
            _hasRecoverySession = Supabase.instance.client.auth.currentSession != null);
      }
    });
  }

  @override
  void dispose() {
    _pwd1Ctrl.dispose();
    _pwd2Ctrl.dispose();
    super.dispose();
  }

  /// Crée la session "recovery" à partir de l'URL (Web) ou valide la session existante.
  Future<void> _prepareRecoverySession() async {
    try {
      final uri = Uri.base;

      // 1) Format moderne : ?code=...&type=recovery (GoTrue v2)
      final code = uri.queryParameters['code'];
      final type = uri.queryParameters['type'];
      if (kIsWeb && code != null && type == 'recovery') {
        await Supabase.instance.client.auth.exchangeCodeForSession(code);
        if (mounted) {
          setState(() => _hasRecoverySession =
              Supabase.instance.client.auth.currentSession != null);
        }
        return;
      }

      // 2) Cas Netlify HashRouter: ?code=...#/reset_password (pas de type=recovery)
      final hasCode = uri.queryParameters['code'];
      final fragPath = uri.fragment.split('?').first;
      if (kIsWeb && hasCode != null && fragPath.contains('reset_password')) {
        // Certaines config renvoient déjà une session via passwordRecovery → _hasRecoverySession sera true.
        // Si aucune session, on essaie d’échanger le code comme ci-dessus.
        try {
          await Supabase.instance.client.auth.exchangeCodeForSession(hasCode);
        } catch (_) {}
        if (mounted) {
          setState(() => _hasRecoverySession =
              Supabase.instance.client.auth.currentSession != null);
        }
        return;
      }

      // 3) Ancien format : #access_token=...&refresh_token=...&type=recovery
      if (kIsWeb && uri.fragment.isNotEmpty) {
        final frag = Uri.splitQueryString(uri.fragment);
        final refresh = frag['refresh_token'];
        final fType = frag['type'];
        if (refresh != null && fType == 'recovery') {
          await Supabase.instance.client.auth.setSession(refresh);
          if (mounted) {
            setState(() => _hasRecoverySession =
                Supabase.instance.client.auth.currentSession != null);
          }
          return;
        }
      }

      // 4) Si déjà connecté (mobile/deep link) ou session déjà posée par ailleurs
      if (Supabase.instance.client.auth.currentSession != null) {
        if (mounted) setState(() => _hasRecoverySession = true);
        return;
      }

      if (mounted) setState(() => _hasRecoverySession = false);
    } catch (e, st) {
      if (mounted) {
        _hasRecoverySession = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(frMessageFromError(e, st))),
        );
        setState(() {});
      }
    }
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      final newPwd = _pwd1Ctrl.text.trim();
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPwd));

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Mot de passe mis à jour.')));

      // ✅ Désactiver le flow recovery, puis déconnecter
      RecoveryGuard.deactivate();
      await Supabase.instance.client.auth.signOut();

      // ✅ Revenir proprement sur Welcome (main.dart routera ensuite selon état)
      navKey.currentState?.pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(frMessageFromError(e, st))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau mot de passe')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _hasRecoverySession
            ? Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Text('Choisis un nouveau mot de passe.', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _pwd1Ctrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 6) ? '6 caractères minimum' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _pwd2Ctrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirmer le mot de passe',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v != _pwd1Ctrl.text) ? 'Les mots de passe ne correspondent pas' : null,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _updatePassword,
                        child: _busy
                            ? const SizedBox(
                                height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Mettre à jour'),
                      ),
                    ),
                  ],
                ),
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.error_outline, size: 48, color: Colors.red),
                    SizedBox(height: 8),
                    Text(
                      'Lien invalide ou expiré.\nRelance la procédure depuis “Mot de passe oublié ?”.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
