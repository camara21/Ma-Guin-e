import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _t;
  bool _navigated = false; // ← empêche tout deuxième push

  @override
  void initState() {
    super.initState();
    // Garde ton délai (5s). Tu pourras le réduire plus tard si besoin.
    _t = Timer(const Duration(milliseconds: 5000), _handleRedirectOnce);
  }

  void _handleRedirectOnce() {
    if (_navigated || !mounted) return; // ← sécurité anti-double
    _navigated = true;

    final user = Supabase.instance.client.auth.currentUser;
    final dest = (user != null) ? AppRoutes.mainNav : AppRoutes.welcome;

    // replacement = on remplace le splash (pas d’empilement)
    Navigator.of(context).pushReplacementNamed(dest);
  }

  @override
  void dispose() {
    _t?.cancel(); // ← évite un callback tardif après dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0175C2),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo_guinee.png', height: 180),
            const SizedBox(height: 38),
            Text(
              "Soneya",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
                shadows: [
                  Shadow(blurRadius: 5, color: Colors.white.withOpacity(0.95)),
                  Shadow(blurRadius: 8, color: Colors.white.withOpacity(0.5)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Là où tout commence",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.92),
                letterSpacing: 1.1,
                shadows: [
                  Shadow(blurRadius: 3, color: Colors.white.withOpacity(0.85)),
                  Shadow(blurRadius: 5, color: Colors.white.withOpacity(0.32)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
