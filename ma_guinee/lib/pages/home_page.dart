// lib/pages/home_page.dart
// (fichier complet – différences principales : _openNotifications force un recalcul au retour)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/user_provider.dart';
import 'cgu_bottom_sheet.dart';
import '../services/message_service.dart';
import '../routes.dart';

// Jobs
import 'package:ma_guinee/pages/jobs/job_home_page.dart';

/// --- Palette locale (indépendante) ---
const _kMainPrimary         = Color(0xFF0077B6);
const _kMainSecondary       = Color(0xFF00B4D8);
const _kSantePrimary        = Color(0xFF009460);
const _kRestoPrimary        = Color(0xFFE76F51);
const _kTourismePrimary     = Color(0xFFDAA520);
const _kHotelsPrimary       = Color(0xFF264653);
const _kEventPrimary        = Color(0xFF7B2CBF);
const _kEventSecondary      = Color(0xFFB5179E);
const _kPrestatairesPrimary = Color(0xFF0F766E);
const _kAnnoncesPrimary     = Color(0xFFDC2626);
const _kNotifPrimary        = Color(0xFFB91C1C);
const _kMapPrimary          = Color(0xFF2B6CB0);
const _kAidePrimary         = Color(0xFF475569);
const _kCommercePrimary     = Color(0xFF6B21A8);

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _notificationsNonLues = 0; // admin-only (type != message)
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
  void didChangeDependencies() {
    _ecouterNotificationsAdminOnly();
    super.didChangeDependencies();
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

  bool _estNonLue(Map<String, dynamic> n) {
    final lu = n['lu'] == true;
    final isRead = n['is_read'] == true;
    return !(lu || isRead);
  }

  void _ecouterNotificationsAdminOnly() {
    final user = context.read<UserProvider>().utilisateur;
    if (user == null) return;

    _notifSub?.cancel();

    _notifSub = Supabase.instance.client
        .from('notifications:utilisateur_id=eq.${user.id}&type=neq.message')
        .stream(primaryKey: ['id']).listen((rows) {
      if (!mounted) return;
      final nonLues = rows.where((n) => _estNonLue(n)).length;
      setState(() => _notificationsNonLues = nonLues);
    });
  }

  Future<void> _chargerMessagesNonLus() async {
    final user = context.read<UserProvider>().utilisateur;
    if (user == null) return;

    try {
      final rows = await Supabase.instance.client
          .from('notifications')
          .select('id, utilisateur_id, user_id, lu, is_read, type')
          .or('utilisateur_id.eq.${user.id},user_id.eq.${user.id}')
          .neq('type', 'message');

      final list = (rows as List).cast<Map<String, dynamic>>();
      final nonLues = list.where((n) => _estNonLue(n)).length;
      if (mounted) setState(() => _notificationsNonLues = nonLues);
    } catch (_) {}

    final count = await MessageService().getUnreadMessagesCount(user.id);
    if (!mounted) return;
    setState(() => _messagesNonLus = count);
  }

  // ► Ouvre la page notifications et rafraîchit le badge au retour
  Future<void> _openNotifications() async {
    await Navigator.pushNamed(context, AppRoutes.notifications);
    if (!mounted) return;
    await _chargerMessagesNonLus(); // force sync du badge après lecture
  }

  // ========== UI helpers ==========
  double _adaptiveIconSize(BuildContext context) {
    final w = MediaBox.of(context).size.width;
    if (w < 360) return 44;
    return 51;
  }

  Widget _iconCard(Widget child) {
    final w = MediaBox.of(context).size.width;
    final side = w < 360 ? 84.0 : 92.0;
    return Container(
      width: side,
      height: side,
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
      alignment: Alignment.center,
      child: child,
    );
  }

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

  Widget _iconWithBadge({
    required IconData main,
    required Color color,
    required IconData badge,
    required BuildContext context,
  }) {
    final size = _adaptiveIconSize(context);
    return _iconCard(
      Stack(
        clipBehavior: Clip.none,
        children: [
          Center(child: Icon(main, color: color, size: size)),
          Positioned(right: 6, bottom: 6, child: _smallBadge(color, badge)),
        ],
      ),
    );
  }

  Widget _soneyaIcon(BuildContext context) {
    final size = _adaptiveIconSize(context);
    const color = _kCommercePrimary;
    return _iconCard(
      Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.work_outline, color: color, size: size),
          Positioned(right: 6, bottom: 6, child: _smallBadge(color, Icons.description)),
        ],
      ),
    );
  }

  Widget _logementIcon(BuildContext context) {
    final size = _adaptiveIconSize(context);
    const primary = _kMapPrimary;
    return _iconCard(
      Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.apartment_rounded, color: primary, size: size),
          Positioned(right: 6, bottom: 6, child: _smallBadge(primary, Icons.location_on_rounded)),
        ],
      ),
    );
  }

  Widget _adminInstitutionIcon(BuildContext context) {
    final size = _adaptiveIconSize(context);
    return _iconCard(
      Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: _InstitutionGradientBaseIcon(
              size: size,
              structure: _kAidePrimary,
              gradientLeft: Color(0xFFDC2626),
              gradientMid:  Color(0xFFDAA520),
              gradientRight: Color(0xFF009460),
            ),
          ),
          Positioned(right: 6, bottom: 6, child: _smallBadge(_kAidePrimary, Icons.description_rounded)),
        ],
      ),
    );
  }

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

    final mq = MediaBox.of(context);
    final width = mq.size.width;
    final textScale = mq.textScaleFactor;

    int crossAxisCount = width > 600 ? 6 : 3;

    double childAspectRatio;
    if (width < 360 || textScale > 1.1) {
      childAspectRatio = 0.82;
    } else if (width < 420) {
      childAspectRatio = 0.92;
    } else {
      childAspectRatio = 1.05;
    }

    double spacing = width > 600 ? 10 : 6;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Bienvenue ${utilisateur.prenom}",
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: false,
        actions: [
          // Notifications (admin-only) avec compteur rouge
          Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 4),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: _kNotifPrimary),
                  onPressed: _openNotifications,
                ),
                if (_notificationsNonLues > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
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
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: _kMainPrimary),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.aide),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bannière
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
                  colors: [_kMainPrimary, _kMainSecondary],
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
                      'assets/carte_guinee.png',
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
                        shadows: [
                          Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))
                        ],
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
                        shadows: [
                          Shadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 1))
                        ],
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
                _ServiceTile(
                  icon: _iconWithBadge(
                    main: Icons.campaign,
                    color: _kAnnoncesPrimary,
                    badge: Icons.add,
                    context: context,
                  ),
                  label: "Annonces",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.annonces),
                ),
                _ServiceTile(
                  icon: _iconWithBadge(
                    main: Icons.handyman_rounded,
                    color: _kPrestatairesPrimary,
                    badge: Icons.build_rounded,
                    context: context,
                  ),
                  label: "Prestataires",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.pro),
                ),
                _ServiceTile(
                  icon: _adminInstitutionIcon(context),
                  label: "Services Admin",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.admin),
                ),
                _ServiceTile(
                  icon: _iconWithBadge(
                    main: Icons.restaurant,
                    color: _kRestoPrimary,
                    badge: Icons.delivery_dining_rounded,
                    context: context,
                  ),
                  label: "Restaurants",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.resto),
                ),
                _ServiceTile(
                  icon: _iconWithBadge(
                    main: Icons.mosque,
                    color: _kMapPrimary,
                    badge: Icons.schedule_rounded,
                    context: context,
                  ),
                  label: "Lieux de culte",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.culte),
                ),
                _ServiceTile(
                  icon: _iconWithBadge(
                    main: Icons.theaters,
                    color: _kEventPrimary,
                    badge: Icons.music_note_rounded,
                    context: context,
                  ),
                  label: "Divertissement",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.divertissement),
                ),
                _ServiceTile(
                  icon: _iconWithBadge(
                    main: Icons.travel_explore_rounded,
                    color: _kTourismePrimary,
                    badge: Icons.place_rounded,
                    context: context,
                  ),
                  label: "Tourisme",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.tourisme),
                ),
                _ServiceTile(
                  icon: _iconWithBadge(
                    main: Icons.local_hospital,
                    color: _kSantePrimary,
                    badge: Icons.health_and_safety_rounded,
                    context: context,
                  ),
                  label: "Santé",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.sante),
                ),
                _ServiceTile(
                  icon: _iconWithBadge(
                    main: Icons.hotel,
                    color: _kHotelsPrimary,
                    badge: Icons.star_rate_rounded,
                    context: context,
                  ),
                  label: "Hôtels",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.hotel),
                ),
                _ServiceTile(
                  icon: _logementIcon(context),
                  label: "Logement",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.logement),
                ),
                _ServiceTile(
                  icon: _soneyaIcon(context),
                  label: "Wali fen",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const JobHomePage()),
                  ),
                ),
                _ServiceTile(
                  icon: _iconWithBadge(
                    main: Icons.confirmation_num,
                    color: _kEventSecondary,
                    badge: Icons.lock_clock,
                    context: context,
                  ),
                  label: "Billetterie",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.billetterie),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ======= Widgets/utilitaires =======

class _ServiceTile extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaBox.of(context).size.width;
    final iconZone = w < 360 ? 84.0 : 92.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: iconZone, child: Center(child: icon)),
          const SizedBox(height: 6),
          Expanded(
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// MediaQuery "safe"
class MediaBox {
  static MediaQueryData of(BuildContext context) =>
      MediaQuery.maybeOf(context) ?? const MediaQueryData();
}

/// =======================
///   DESSIN PERSONNALISÉ
/// =======================

class _InstitutionGradientBaseIcon extends StatelessWidget {
  final double size;
  final Color structure;
  final Color gradientLeft, gradientMid, gradientRight;

  const _InstitutionGradientBaseIcon({
    super.key,
    required this.size,
    required this.structure,
    required this.gradientLeft,
    required this.gradientMid,
    required this.gradientRight,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _InstitutionGradientBasePainter(
        structure: structure,
        gradientLeft: gradientLeft,
        gradientMid: gradientMid,
        gradientRight: gradientRight,
      ),
    );
  }
}

class _InstitutionGradientBasePainter extends CustomPainter {
  final Color structure;
  final Color gradientLeft, gradientMid, gradientRight;

  _InstitutionGradientBasePainter({
    required this.structure,
    required this.gradientLeft,
    required this.gradientMid,
    required this.gradientRight,
  });

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final p = Paint()..style = PaintingStyle.fill;

    // Toit
    p.color = structure;
    final pediment = Path()
      ..moveTo(w * 0.12, h * 0.28)
      ..lineTo(w * 0.50, h * 0.09)
      ..lineTo(w * 0.88, h * 0.28)
      ..close();
    canvas.drawPath(pediment, p);

    // Entablement
    final entabl = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.16, h * 0.30, w * 0.68, h * 0.05),
      const Radius.circular(1.3),
    );
    canvas.drawRRect(entabl, p);

    // Piliers
    final top = h * 0.36, bottom = h * 0.72, colW = w * 0.12, gap = w * 0.08;
    final x1 = w * 0.22, x2 = x1 + colW + gap, x3 = x2 + colW + gap;
    void col(double x) => canvas.drawRect(
          Rect.fromLTWH(x, top, colW, bottom - top),
          Paint()..color = structure,
        );
    col(x1);
    col(x2);
    col(x3);

    // Base dégradée
    final baseRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.14, h * 0.76, w * 0.72, h * 0.12),
      Radius.circular(h * 0.06),
    );

    final shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [gradientLeft, gradientMid, gradientRight],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(baseRect.outerRect);

    final basePaint = Paint()..shader = shader;
    canvas.drawRRect(baseRect, basePaint);
  }

  @override
  bool shouldRepaint(covariant _InstitutionGradientBasePainter old) {
    return structure != old.structure ||
        gradientLeft != old.gradientLeft ||
        gradientMid != old.gradientMid ||
        gradientRight != old.gradientRight;
  }
}
