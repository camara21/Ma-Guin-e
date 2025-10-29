import 'dart:async'; // TimeoutException
import 'dart:io';    // SocketException
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import '../routes.dart';
import '../providers/user_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _primary = Color(0xFF0077B6);
  static const _onPrimary = Color(0xFFFFFFFF);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  Future<void> _seConnecter() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final supabase = Supabase.instance.client;
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text.trim();

      final res = await supabase.auth
          .signInWithPassword(email: email, password: password)
          .timeout(const Duration(seconds: 15));

      final user = res.user;
      if (user == null) {
        throw const AuthException('Email ou mot de passe incorrect.');
      }

      await context.read<UserProvider>().chargerUtilisateurConnecte();

      String dest = AppRoutes.mainNav;
      try {
        final row = await supabase
            .from('utilisateurs')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();

        final role = (row?['role'] as String?)?.toLowerCase() ?? '';
        if (role == 'admin' || role == 'owner') {
          dest = AppRoutes.adminCenter;
        }
      } catch (_) {
        dest = AppRoutes.mainNav;
      }

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(dest, (_) => false);
    } on SocketException {
      if (!mounted) return;
      _toast("Aucune connexion Internet. Vérifiez vos données mobiles ou le Wi-Fi.");
    } on TimeoutException {
      if (!mounted) return;
      _toast("La connexion a expiré. Réessayez lorsque vous avez Internet.");
    } on AuthException catch (e) {
      if (!mounted) return;
      final raw = (e.message ?? '').toLowerCase();
      String msg = "Une erreur d'authentification est survenue.";
      if (raw.contains('invalid login') ||
          raw.contains('invalid credentials') ||
          raw.contains('email or password') ||
          raw.contains('invalid email or password')) {
        msg = "Email ou mot de passe incorrect.";
      } else if (raw.contains('email not confirmed') ||
          raw.contains('not confirmed')) {
        msg = "Votre e-mail n'est pas encore confirmé. Consultez votre boîte mail.";
      } else if (raw.isNotEmpty) {
        msg = e.message!;
      }
      _toast(msg);
    } catch (_) {
      if (!mounted) return;
      _toast("Erreur inattendue. Veuillez réessayer.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {IconData? icon}) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      prefixIcon: icon != null ? Icon(icon, color: _primary) : null,
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: _primary, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Connexion",
          style: TextStyle(
            // ⚠️ on évite const color = variable : on laisse ce Text non-const si tu préfères
            color: _primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: _primary),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // ---------- EN-TÊTE AVEC CERCLE + ICÔNES DE SERVICES ----------
                Column(
                  children: [
                    _ServiceDial(
                      size: 150,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0E67B2), Color(0xFF22C1C3)],
                      ),
                      // 🔧 Mets les icônes de TES services ici :
                      icons: const [
                        Icons.restaurant,         // Restaurants
                        Icons.hotel,              // Hôtels
                        Icons.local_hospital,     // Santé
                        Icons.attractions,        // Tourisme & Culture
                        Icons.confirmation_num,   // Billetterie / Events
                        Icons.shopping_bag,       // Commerce
                        Icons.work_outline,       // Jobs
                        Icons.map,                // Carte / Lieux
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "Connectez-vous à l’essentiel",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  style: const TextStyle(fontSize: 16),
                  decoration: _dec("E-mail", icon: Icons.email),
                  validator: (val) {
                    final v = (val ?? '').trim();
                    if (v.isEmpty || !v.contains('@')) return "E-mail invalide";
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Mot de passe
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  style: const TextStyle(fontSize: 16),
                  decoration: _dec("Mot de passe", icon: Icons.lock).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (val) =>
                      val == null || val.trim().length < 6 ? "Mot de passe trop court" : null,
                  onFieldSubmitted: (_) => _seConnecter(),
                ),
                const SizedBox(height: 6),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.forgotPassword,
                      arguments: {'prefillEmail': _emailController.text.trim()},
                    ),
                    child: const Text(
                      "Mot de passe oublié ?",
                      style: TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Bouton Connexion
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _seConnecter,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: _onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            "Connexion",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ),

                const SizedBox(height: 22),

                // Lien création de compte
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: const Text(
                    "Créer un compte",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// “Cadran” : cercle dégradé + icône centrale + icônes de services autour,
/// reliées par des traits blancs vers le centre.
class _ServiceDial extends StatelessWidget {
  final double size;
  final LinearGradient gradient;
  final List<IconData> icons;

  const _ServiceDial({
    required this.size,
    required this.gradient,
    required this.icons,
  });

  @override
  Widget build(BuildContext context) {
    final radius = size / 2;

    final iconCount = icons.length.clamp(0, 12);
    final double orbit = radius * 0.62; // distance des icônes au centre

    final positions = <Offset>[];
    for (int i = 0; i < iconCount; i++) {
      final theta = (2 * math.pi * i / iconCount) - math.pi / 2; // départ en haut
      positions.add(Offset(
        radius + orbit * math.cos(theta),
        radius + orbit * math.sin(theta),
      ));
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Fond dégradé
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
              boxShadow: const [
                BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 8)),
              ],
            ),
          ),

          // Traits centre -> icônes (dessinés sous les icônes)
          CustomPaint(size: Size(size, size), painter: _DialLinksPainter(positions: positions)),

          // Icône centrale (halo léger)
          Center(
            child: Container(
              width: radius * 0.65,
              height: radius * 0.65,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.hub_outlined, color: Colors.white, size: 40),
              ),
            ),
          ),

          // Icônes de service autour
          ...List.generate(iconCount, (i) {
            final p = positions[i];
            return Positioned(
              left: p.dx - 16,
              top: p.dy - 16,
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: Icon(icons[i], size: 18, color: Color(0xFF0E67B2)),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DialLinksPainter extends CustomPainter {
  final List<Offset> positions;
  _DialLinksPainter({required this.positions});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final node = Paint()..color = Colors.white;

    for (final p in positions) {
      canvas.drawLine(center, p, line);
      canvas.drawCircle(p, 3.2, node);
    }

    final halo = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;
    canvas.drawCircle(center, size.width * 0.28, halo);
  }

  @override
  bool shouldRepaint(covariant _DialLinksPainter oldDelegate) =>
      oldDelegate.positions != positions;
}
