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
  // +15% vs 44px
  static const double _iconSize = 51;

  int _notificationsNonLues = 0; // ← admin-only
  int _messagesNonLus = 0;

  StreamSubscription<List<Map<String, dynamic>>>? _notifSub;

  @override
  void initState() {
    super.initState();
    _verifierCGU();
    _ecouterNotificationsAdminOnly();
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

  // --------- Notifications ADMIN uniquement ---------
  void _ecouterNotificationsAdminOnly() {
    final user = context.read<UserProvider>().utilisateur;
    if (user == null) return;

    _notifSub?.cancel();

    // Stream filtré côté serveur : user + type != message
    _notifSub = Supabase.instance.client
        .from('notifications:utilisateur_id=eq.${user.id}&type=neq.message')
        .stream(primaryKey: ['id'])
        .listen((rows) {
      if (!mounted) return;

      final nonLues = rows.where((n) {
        final lu = n['lu'] == true;
        return !lu; // type!=message déjà filtré dans le canal
      }).length;

      setState(() => _notificationsNonLues = nonLues);
    });
  }

  Future<void> _chargerMessagesNonLus() async {
    final user = context.read<UserProvider>().utilisateur;
    if (user == null) return;

    try {
      // ⚠️ Filtre serveur: exclure les notifs de conversation entre utilisateurs
      final rows = await Supabase.instance.client
          .from('notifications')
          .select('id, utilisateur_id, lu, type')
          .eq('utilisateur_id', user.id)
          .neq('type', 'message');

      final nonLues = (rows as List).where((n) => n['lu'] != true).length;
      if (mounted) setState(() => _notificationsNonLues = nonLues);
    } catch (_) {}

    // Si tu utilises un compteur de messages privés ailleurs
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
      padding: const EdgeInsets.all(22), // même cadre visuel
      child: child,
    );
  }

  // Badge discret : reprend EXACTEMENT la couleur de l’icône principale
  Widget _smallBadge(Color bgColor, IconData icon) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.95),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.22),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(icon, size: 9, color: Colors.white),
    );
  }

  // Icône Material + badge accordé à la couleur principale
  Widget _iconWithBadge({
    required IconData main,
    required Color color,
    required IconData badge,
  }) {
    return _iconCard(
      Stack(
        clipBehavior: Clip.none,
        children: [
          Center(child: Icon(main, color: color, size: _iconSize)),
          Positioned(right: 2, bottom: 2, child: _smallBadge(color, badge)),
        ],
      ),
    );
  }

  // Icône Jobs
  Widget _soneyaIcon() {
    const blue = Color(0xFF1976D2);
    return _iconCard(
      Stack(
        clipBehavior: Clip.none,
        children: [
          const Center(child: Icon(Icons.work_outline, color: blue, size: _iconSize)),
          Positioned(right: 2, bottom: 2, child: _smallBadge(blue, Icons.description)),
        ],
      ),
    );
  }

  // ✅ Icône Logement (badge bleu cohérent)
  Widget _logementIcon() {
    const primary = Color(0xFF0B3A6A); // bleu profond
    return _iconCard(
      Stack(
        clipBehavior: Clip.none,
        children: [
          const Center(child: Icon(Icons.apartment_rounded, color: primary, size: _iconSize)),
          Positioned(right: 2, bottom: 2, child: _smallBadge(primary, Icons.location_on_rounded)),
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
          // 🔔 Notifications (admin-only) avec compteur rouge
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
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFF113CFC)),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.aide),
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

                // Prestataires
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

                // Tourisme (vert) — nouvelle forme globe+loupe
GestureDetector(
  onTap: () => Navigator.pushNamed(context, AppRoutes.tourisme),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _iconWithBadge(
        main: Icons.travel_explore_rounded, // ✅ forme changée
        color: const Color(0xFF009460),     // ✅ couleur identique à avant
        badge: Icons.place_rounded,         // petit badge discret
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

                // 🔁 Logement
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

  // tuile générique (utilisée pour Billetterie à venir)
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
}
