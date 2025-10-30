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
        if (role == 'admin' || role == 'owner') dest = AppRoutes.adminCenter;
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
          style: TextStyle(color: _primary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: _primary),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // -------- EN-TÊTE ÉPURÉE : pas de disque, icônes + flèches --------
                Column(
                  children: const [
                    _ServiceDialMinimal(
                      size: 150,
                      icons: [
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
                    SizedBox(height: 14),
                    Text(
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

/// Version minimaliste : PAS de fond bleu.
/// Anneau intérieur discret + flèches depuis le centre vers chaque icône.
class _ServiceDialMinimal extends StatelessWidget {
  final double size;
  final List<IconData> icons;

  const _ServiceDialMinimal({
    required this.size,
    required this.icons,
  });

  @override
  Widget build(BuildContext context) {
    final iconCount = icons.length.clamp(0, 12);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DialArrowsPainter(iconCount: iconCount),
        child: Stack(
          children: List.generate(iconCount, (i) {
            final p = _DialArrowsPainter.positionFor(i, iconCount, size);
            return Positioned(
              left: p.dx - 16,
              top: p.dy - 16,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: const [
                    BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
                child: Icon(icons[i], size: 18, color: Color(0xFF0E67B2)),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _DialArrowsPainter extends CustomPainter {
  final int iconCount;

  _DialArrowsPainter({required this.iconCount});

  static Offset positionFor(int i, int count, double size) {
    final radius = size / 2;
    final orbit = radius * 0.72;
    final theta = (2 * math.pi * i / count) - math.pi / 2; // départ en haut
    return Offset(
      radius + orbit * math.cos(theta),
      radius + orbit * math.sin(theta),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // ✅ On garde UNIQUEMENT l’anneau intérieur
    final ring = Paint()
      ..color = const Color(0x11000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, size.width * 0.36, ring);
    // ❌ Anneau extérieur supprimé (avant: canvas.drawCircle(center, size.width * 0.72, ring);)

    final line = Paint()
      ..color = const Color(0x33000000)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final arrow = Paint()
      ..color = const Color(0x33000000)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < iconCount; i++) {
      final p = positionFor(i, iconCount, size.width);

      // vecteur centre -> icône
      final v = (p - center);
      final dir = v / v.distance;

      // reculer un peu la pointe pour ne pas passer sous l'icône
      final end = p - dir * 22;
      final start = center + dir * 16;

      // trait
      canvas.drawLine(start, end, line);

      // petite tête de flèche triangulaire
      const ah = 9.0; // hauteur
      const aw = 6.0; // demi-largeur
      final perp = Offset(-dir.dy, dir.dx); // perpendiculaire

      final tip = end;
      final base = end - dir * ah;
      final p1 = base + perp * aw;
      final p2 = base - perp * aw;

      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();
      canvas.drawPath(path, arrow);
    }

    // petit hub central discret
    final hubFill = Paint()..color = const Color(0x14000000);
    final hubRing = Paint()
      ..color = const Color(0x22000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, 8, hubFill);
    canvas.drawCircle(center, 8, hubRing);
  }

  @override
  bool shouldRepaint(covariant _DialArrowsPainter oldDelegate) => false;
}
