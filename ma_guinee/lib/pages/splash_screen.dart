import 'package:flutter/material.dart';
import 'dart:async';
import '../routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 5000), _handleRedirect); // 5 secondes
  }

  void _handleRedirect() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      Navigator.pushReplacementNamed(context, AppRoutes.mainNav);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glow sous le logo
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.32),
                        blurRadius: 32,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
                Image.asset(
                  'assets/logo_guinee.png', // ou ton image uploadée
                  height: 180,
                ),
              ],
            ),
            const SizedBox(height: 38),
            // Texte avec glow très contenu
            Text(
              "Ma Guinée",
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
                shadows: [
                  Shadow(
                    blurRadius: 5, // petit flou = lumière proche
                    color: Colors.white.withOpacity(0.95),
                  ),
                  Shadow(
                    blurRadius: 8, // deuxième ombre pour renforcer le glow
                    color: Colors.white.withOpacity(0.5),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Là où tout commence",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.92),
                letterSpacing: 1.1,
                shadows: [
                  Shadow(
                    blurRadius: 3,
                    color: Colors.white.withOpacity(0.85),
                  ),
                  Shadow(
                    blurRadius: 5,
                    color: Colors.white.withOpacity(0.32),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
