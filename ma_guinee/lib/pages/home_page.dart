// lib/pages/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/user_provider.dart';
import 'cgu_bottom_sheet.dart';
import '../services/message_service.dart';
import '../routes.dart';

// ✅ Jobs
import 'package:ma_guinee/pages/jobs/job_home_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _notificationsNonLues = 0;
  int _messagesNonLus = 0;

  StreamSubscription<List<Map<String, dynamic>>>? _notifSub;

  @override
  void initState() {
    super.initState();
    _verifierCGU();
    _ecouterNotifications();
    _chargerMessagesNonLus();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  Future<void> _verifierCGU() async {
    final utilisateur = context.read<UserProvider>().utilisateur;
    if (utilisateur != null && utilisateur.cguAccepte != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => const CGUBottomSheet(),
        );
      });
    }
  }

  void _ecouterNotifications() {
    final user = context.read<UserProvider>().utilisateur;
    if (user == null) return;

    _notifSub?.cancel();

    _notifSub = Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .listen((rows) {
      if (!mounted) return;

      final nonLues = rows.where((n) {
        final uid = n['utilisateur_id']?.toString();
        final lu = n['lu'] == true;
        return uid == user.id && !lu;
      }).length;

      setState(() => _notificationsNonLues = nonLues);
    });
  }

  Future<void> _chargerMessagesNonLus() async {
    final user = context.read<UserProvider>().utilisateur;
    if (user == null) return;

    try {
      final rows = await Supabase.instance.client
          .from('notifications')
          .select('id, utilisateur_id, lu');

      final nonLues = (rows as List).where((n) {
        final uid = n['utilisateur_id']?.toString();
        final lu = n['lu'] == true;
        return uid == user.id && !lu;
      }).length;

      if (mounted) setState(() => _notificationsNonLues = nonLues);
    } catch (_) {}

    final count = await MessageService().getUnreadMessagesCount(user.id);
    if (!mounted) return;
    setState(() => _messagesNonLus = count);
  }

  // ---------- helpers d'icône (même style/taille pour tous) ----------
  Widget _iconCard(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22), // même taille visuelle
      child: child,
    );
  }

  // Petit badge commun (en bas à droite)
  static const Color _badgeColor = Color(0xFFE1005A); // fuchsia Soneya
  Widget _smallBadge(IconData icon) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: _badgeColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(child: Icon(icon, size: 12, color: Colors.white)),
    );
  }

  // Icône Material + badge
  Widget _iconWithBadge({
    required IconData main,
    required Color color,
    required IconData badge,
  }) {
    return _iconCard(
      Stack(
        clipBehavior: Clip.none,
        children: [
          Center(child: Icon(main, color: color, size: 44)),
          Positioned(right: 2, bottom: 2, child: _smallBadge(badge)),
        ],
      ),
    );
  }

  // Icône Soneya (Jobs) – conserve ton style + badge CV
  Widget _soneyaIcon() {
    const blue = Color(0xFF1976D2);
    return _iconCard(
      Stack(
        clipBehavior: Clip.none,
        children: [
          const Center(child: Icon(Icons.work_outline, color: blue, size: 44)),
          Positioned(right: 2, bottom: 2, child: _smallBadge(Icons.description)),
        ],
      ),
    );
  }

  // ✅ Icône Logement alignée & cohérente (44px + badge discret)
  Widget _logementIcon() {
    const primary = Color(0xFF0B3A6A); // bleu profond
    return _iconCard(
      Stack(
        clipBehavior: Clip.none,
        children: [
          const Center(
            child: Icon(Icons.apartment_rounded, color: primary, size: 44),
          ),
          Positioned(right: 2, bottom: 2, child: _smallBadge(Icons.location_on_rounded)),
        ],
      ),
    );
  }

  // Tuile utilisant un widget d'icône custom
  Widget _serviceTileCustom(Widget iconWidget, String label, String route) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final utilisateur = context.watch<UserProvider>().utilisateur;

    if (utilisateur == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = 3;
    double childAspectRatio = 1.03;
    double spacing = 6;
    if (width > 600) {
      crossAxisCount = 6;
      childAspectRatio = 1.18;
      spacing = 10;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Bienvenue ${utilisateur.prenom} 👋",
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 4),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Color(0xFFCE1126)),
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
                ),
                if (_notificationsNonLues > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _notificationsNonLues.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 12),
            child: IconButton(
              icon: const Icon(Icons.help_outline, color: Color(0xFF113CFC)),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.aide),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bannière (inchangée)
            Container(
              margin: const EdgeInsets.only(bottom: 18),
              width: double.infinity,
              height: 142,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
                gradient: const LinearGradient(
                  colors: [Color(0xFFCE1126), Color(0xFFFCD116)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 12,
                    top: 10,
                    child: Image.asset(
                      'assets/logo_guinee.png',
                      height: 124,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const Positioned(
                    top: 29,
                    left: 26,
                    child: Text(
                      "Soneya",
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 75,
                    left: 26,
                    child: Text(
                      "Tous les services à portée de main",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                        shadows: [Shadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 1))],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Grille
            GridView.count(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              shrinkWrap: true,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Annonces (rouge)
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.annonces),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _iconWithBadge(
                        main: Icons.campaign,
                        color: const Color(0xFFCE1126),
                        badge: Icons.add,
                      ),
                      const SizedBox(height: 6),
                      const Text("Annonces", textAlign: TextAlign.center),
                    ],
                  ),
                ),

                // Prestataires (icône Flutter : handyman)
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.pro),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _iconWithBadge(
                        main: Icons.handyman_rounded,
                        color: const Color(0xFFFCD116),
                        badge: Icons.build_rounded,
                      ),
                      const SizedBox(height: 6),
                      const Text("Prestataires", textAlign: TextAlign.center),
                    ],
                  ),
                ),

                // Services Admin (vert)
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.admin),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _iconWithBadge(
                        main: Icons.account_balance,
                        color: const Color(0xFF009460),
                        badge: Icons.description_rounded,
                      ),
                      const SizedBox(height: 6),
                      const Text("Services Admin", textAlign: TextAlign.center),
                    ],
                  ),
                ),

                // Restaurants (jaune)
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.resto),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _iconWithBadge(
                        main: Icons.restaurant,
                        color: const Color(0xFFFCD116),
                        badge: Icons.delivery_dining_rounded,
                      ),
                      const SizedBox(height: 6),
                      const Text("Restaurants", textAlign: TextAlign.center),
                    ],
                  ),
                ),

                // Lieux de culte (vert)
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.culte),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _iconWithBadge(
                        main: Icons.mosque,
                        color: const Color(0xFF009460),
                        badge: Icons.schedule_rounded,
                      ),
                      const SizedBox(height: 6),
                      const Text("Lieux de culte", textAlign: TextAlign.center),
                    ],
                  ),
                ),

                // Divertissement (rouge)
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.divertissement),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _iconWithBadge(
                        main: Icons.theaters,
                        color: const Color(0xFFCE1126),
                        badge: Icons.music_note_rounded,
                      ),
                      const SizedBox(height: 6),
                      const Text("Divertissement", textAlign: TextAlign.center),
                    ],
                  ),
                ),

                // Tourisme (vert)
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.tourisme),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _iconWithBadge(
                        main: Icons.museum,
                        color: const Color(0xFF009460),
                        badge: Icons.place_rounded,
                      ),
                      const SizedBox(height: 6),
                      const Text("Tourisme", textAlign: TextAlign.center),
                    ],
                  ),
                ),

                // Santé (jaune)
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.sante),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _iconWithBadge(
                        main: Icons.local_hospital,
                        color: const Color(0xFFFCD116),
                        badge: Icons.health_and_safety_rounded,
                      ),
                      const SizedBox(height: 6),
                      const Text("Santé", textAlign: TextAlign.center),
                    ],
                  ),
                ),

                // Hôtels (rouge)
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.hotel),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _iconWithBadge(
                        main: Icons.hotel,
                        color: const Color(0xFFCE1126),
                        badge: Icons.star_rate_rounded,
                      ),
                      const SizedBox(height: 6),
                      const Text("Hôtels", textAlign: TextAlign.center),
                    ],
                  ),
                ),

                // 🔁 Logement (icône custom cohérente)
                _serviceTileCustom(_logementIcon(), "Logement", AppRoutes.logement),

                // 🔹 Emplois (Wali fen)
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const JobHomePage()),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _soneyaIcon(),
                      const SizedBox(height: 6),
                      const Text("Wali fen", textAlign: TextAlign.center),
                    ],
                  ),
                ),

                // 🔹 Billetterie (bientôt)
                _serviceTileFuture(
                  Icons.confirmation_num,
                  "Billetterie",
                  const Color(0xFFFCD116),
                  "Un service de billetterie sera bientôt disponible pour vendre vos billets d’événements "
                  "avec un système de QR Code sécurisé et traçable pour toutes vos organisations.",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceTile(IconData icon, String label, String route, Color color) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _iconWithBadge(main: icon, color: color, badge: Icons.info_outline), // générique
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _serviceTileFuture(IconData icon, String label, Color color, String message) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(label),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
            ],
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _iconWithBadge(main: icon, color: color, badge: Icons.lock_clock),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _serviceTileFutureCustom(Widget iconWidget, String label, String message) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(label),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
            ],
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
