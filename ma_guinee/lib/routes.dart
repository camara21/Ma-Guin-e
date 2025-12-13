// lib/routes.dart — Routes + RecoveryGuard
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/annonce_model.dart';
import 'models/utilisateur_model.dart';
import 'models/job_models.dart';
import 'models/logement_models.dart';

import 'pages/splash_screen.dart';
import 'pages/welcome_page.dart';
import 'pages/home_page.dart';
import 'pages/annonces_page.dart';
import 'pages/pro_page.dart';
import 'pages/carte_page.dart';
import 'pages/divertissement_page.dart';
import 'pages/admin_page.dart';

import 'pages/resto_page.dart' as resto_pg;
import 'pages/register_page.dart' as register_pg;

import 'pages/culte_page.dart';
import 'pages/login_page.dart';
import 'pages/tourisme_page.dart';
import 'pages/sante_page.dart';
import 'pages/hotel_page.dart';
import 'pages/notifications_page.dart';
import 'pages/profile_page.dart';
import 'pages/main_navigation_page.dart';
import 'pages/parametre_page.dart';
import 'pages/aide_page.dart';
import 'pages/messages_page.dart';
import 'pages/mes_annonces_page.dart';
import 'pages/mes_prestations_page.dart';
import 'pages/mes_restaurants_page.dart' as myresto_pg;
import 'pages/mes_hotels_page.dart' as hotel_page;
import 'pages/mes_cliniques_page.dart';
import 'pages/annonce_detail_page.dart';
import 'pages/resto_detail_page.dart';
import 'pages/hotel_detail_page.dart';

import 'pages/edit_prestataire_page.dart';
import 'pages/edit_hotel_page.dart';
import 'pages/edit_resto_page.dart';
import 'pages/edit_annonce_page.dart';
import 'pages/edit_clinique_page.dart';
import 'pages/inscription_resto_page.dart';
import 'pages/inscription_prestataire_page.dart';
import 'pages/inscription_hotel_page.dart';

import 'providers/user_provider.dart';

// ====== NOUVELLE BILLETTERIE ======
import 'pages/billetterie/billetterie_home_page.dart';
import 'pages/billetterie/event_detail_page.dart';
import 'pages/billetterie/mes_billets_page.dart';
import 'pages/billetterie/ticket_scanner_page.dart';
import 'pages/billetterie/pro_evenements_page.dart';
import 'pages/billetterie/pro_ventes_page.dart';
// ==================================

import 'pages/jobs/job_home_page.dart';
import 'pages/jobs/jobs_page.dart';
import 'pages/jobs/job_detail_page.dart';
import 'pages/jobs/my_applications_page.dart' as apps;

import 'pages/cv/cv_maker_page.dart';
import 'pages/jobs/employer/mes_offres_page.dart';
import 'pages/jobs/employer/offre_edit_page.dart';

import 'pages/jobs/candidatures_page.dart';
import 'pages/jobs/candidature_detail_page.dart';
import 'pages/jobs/employer/devenir_employeur_page.dart';
import 'services/employeur_service.dart';

import 'pages/logement/logement_home_page.dart';
import 'pages/logement/logement_list_page.dart';
import 'pages/logement/logement_detail_page.dart';
import 'pages/logement/logement_edit_page.dart';
import 'pages/logement/logement_map_page.dart';

import 'admin/admin_dashboard.dart';
import 'admin/admin_gate.dart';
import 'admin/content_advanced_page.dart';

import 'pages/auth/reset_password_flow.dart';

/// 🔒 RecoveryGuard — simple drapeau global partagé
class RecoveryGuard {
  static bool isActive = false;
  static void activate() => isActive = true;
  static void deactivate() => isActive = false;
}

class AppRoutes {
  // Core
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String mainNav = '/main';
  static const String home = '/home';

  // Existants
  static const String annonces = '/annonces';
  static const String pro = '/prestataires';
  static const String carte = '/carte';
  static const String divertissement = '/divertissement';
  static const String admin = '/administratif';

  static const String resto = '/restos';
  static const String culte = '/culte';

  // LOGEMENT
  static const String logement = '/logement';
  static const String logementList = '/logement/list';
  static const String logementDetail = '/logement/detail';
  static const String logementEdit = '/logement/edit';
  static const String logementMap = '/logement/map';

  static const String login = '/login';
  static const String register = '/register';
  static const String tourisme = '/tourisme';
  static const String sante = '/sante';
  static const String hotel = '/hotels';
  static const String notifications = '/notifications';
  static const String profil = '/profil';

  static const String parametre = '/parametre';

  static const String aide = '/aide';
  static const String messages = '/messages';

  static const String mesAnnonces = '/mes_annonces';
  static const String mesPrestations = '/mes_prestations';
  static const String mesRestaurants = '/mesRestaurants';
  static const String mesHotels = '/mesHotels';
  static const String mesCliniques = '/mesCliniques';

  static const String inscriptionResto = '/inscriptionResto';
  static const String inscriptionHotel = '/inscriptionHotel';
  static const String inscriptionClinique = '/inscriptionClinique';

  static const String annonceDetail = '/annonce_detail';
  static const String restoDetail = '/resto_detail';
  static const String hotelDetail = '/hotel_detail';

  static const String editPrestataire = '/edit_prestataire';
  static const String editHotel = '/edit_hotel';
  static const String editResto = '/edit_resto';
  static const String editAnnonce = '/edit_annonce';
  static const String editClinique = '/edit_clinique';

  // ====== BILLETTERIE (NOUVEAU) ======
  static const String billetterie = '/billetterie';
  static const String billetterieDetail = '/billetterie/detail';
  static const String myTickets = '/mes_billets';
  static const String scanner = '/scanner';
  static const String billetteriePro = '/billetterie/pro';
  static const String billetterieVentes = '/billetterie/pro/ventes';
  // ===================================

  // JOB
  static const String jobHome = '/jobs';
  static const String jobList = '/jobs/list';
  static const String jobDetail = '/jobs/detail';
  static const String myApplications = '/jobs/my_applications';
  static const String cvMaker = '/jobs/cv';
  static const String employerOffers = '/jobs/employer/offres';
  static const String employerOfferEdit = '/jobs/employer/offre_edit';
  static const String employerOfferCandidatures = '/jobs/employer/candidatures';

  // NOUVEL ESPACE ADMIN
  static const String adminCenter = '/admin';
  static const String adminManage = '/admin/manage';

  // Auth – reset password
  static const String forgotPassword = '/forgot_password';
  static const String resetPassword = '/reset_password';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final String name = settings.name ?? '';

    // ✅ Cas spécial : lien de réinitialisation Supabase
    if (name.startsWith(resetPassword)) {
      return _page(settings, const ResetPasswordPage());
    }

    switch (name) {
      // ----- ADMIN CENTER -----
      case adminCenter:
        RecoveryGuard.deactivate();
        return _page(settings, const AdminGate(child: AdminDashboard()));

      case adminManage:
        {
          RecoveryGuard.deactivate();
          final a = _argsMap(settings);
          final table =
              (a['table']?.toString().trim().toLowerCase() ?? 'logements');
          final title = (a['title']?.toString().trim().isNotEmpty == true)
              ? a['title'].toString()
              : _prettyServiceName(table);
          return _page(
            settings,
            AdminGate(child: ContentAdvancedPage(title: title, table: table)),
          );
        }

      // ----- CORE -----
      case splash:
        return _page(settings, const SplashScreen());
      case welcome:
        RecoveryGuard.deactivate();
        return _page(settings, const WelcomePage());
      case mainNav:
        RecoveryGuard.deactivate();
        return _page(settings, const MainNavigationPage());
      case home:
        RecoveryGuard.deactivate();
        return _page(settings, const HomePage());

      // ----- EXISTANTS -----
      case annonces:
        return _page(settings, const AnnoncesPage());
      case pro:
        return _page(settings, const ProPage());
      case carte:
        return _page(settings, const CartePage());
      case divertissement:
        return _page(settings, const DivertissementPage());
      case admin:
        return _page(settings, const AdminPage());
      case resto:
        return _page(settings, const resto_pg.RestoPage());
      case culte:
        return _page(settings, const CultePage());

      // ----- LOGEMENT -----
      case logement:
        return _page(settings, const LogementHomePage());
      case logementList:
        {
          final a = _argsMap(settings);
          final String? q = a['q'] as String?;
          final LogementMode mode = _parseMode(a['mode']);
          final LogementCategorie? cat = _parseCategorieOrNull(a['categorie']);
          return _page(
            settings,
            LogementListPage(
              initialQuery: q,
              initialMode: mode,
              initialCategorie: cat ?? LogementCategorie.autres,
            ),
          );
        }
      case logementDetail:
        {
          final a = settings.arguments;
          final id =
              (a is String) ? a : (a is Map ? (a['id']?.toString()) : null);
          if (id == null || id.isEmpty) {
            return _error(settings, 'ID requis pour $logementDetail');
          }
          return _page(settings, LogementDetailPage(logementId: id));
        }
      case logementEdit:
        {
          final a = _argsMap(settings);
          final existing = a['existing'];
          if (existing != null && existing is! LogementModel) {
            return _error(
                settings, 'Argument "existing" invalide pour $logementEdit');
          }
          return _userProtected(
            settings,
            (_) => LogementEditPage(existing: existing as LogementModel?),
          );
        }
      case logementMap:
        {
          final a = _argsMap(settings);
          double? _d(dynamic v) {
            if (v == null) return null;
            if (v is num) return v.toDouble();
            return double.tryParse(v.toString());
          }

          return _page(
            settings,
            LogementMapPage(
              ville: a['ville'] as String?,
              commune: a['commune'] as String?,
              focusId: a['id']?.toString(),
              focusLat: _d(a['lat']),
              focusLng: _d(a['lng']),
              focusTitre: a['titre']?.toString(),
              focusVille: a['ville']?.toString(),
              focusCommune: a['commune']?.toString(),
            ),
          );
        }

      // ----- AUTH / PROFIL / DIVERS -----
      case login:
        RecoveryGuard.deactivate();
        return _page(settings, const LoginPage());
      case register:
        return _page(settings, const register_pg.RegisterPage());
      case tourisme:
        return _page(settings, const TourismePage());
      case sante:
        return _page(settings, const SantePage());
      case hotel:
        return _page(settings, const HotelPage());
      case notifications:
        return _page(settings, const NotificationsPage());
      case profil:
        return _userProtected(settings, (u) => ProfilePage(user: u));

      case parametre:
        return _userProtected(settings, (u) => ParametrePage(user: u));

      case aide:
        return _page(settings, const AidePage());
      case messages:
        return _page(settings, const MessagesPage());

      case mesAnnonces:
        return _userProtected(settings, (_) => const MesAnnoncesPage());

      case mesPrestations:
        return _userProtected(settings, (u) {
          final prestations = u.espacePrestataire != null
              ? [u.espacePrestataire!]
              : <Map<String, dynamic>>[];
          return MesPrestationsPage(prestations: prestations);
        });

      case mesRestaurants:
        return _userProtected(
          settings,
          (u) => myresto_pg.MesRestaurantsPage(restaurants: u.restos ?? []),
        );

      case mesHotels:
        return _userProtected(
          settings,
          (u) => hotel_page.MesHotelsPage(hotels: u.hotels ?? []),
        );

      case mesCliniques:
        return _userProtected(
          settings,
          (u) => MesCliniquesPage(cliniques: u.cliniques ?? []),
        );

      case inscriptionResto:
        {
          final arg = settings.arguments;
          if (arg == null || arg is Map<String, dynamic>) {
            return _page(
              settings,
              InscriptionRestoPage(restaurant: arg as Map<String, dynamic>?),
            );
          }
          return _error(settings, 'Argument invalide pour $inscriptionResto');
        }

      case inscriptionHotel:
        {
          final arg = settings.arguments;
          if (arg == null || arg is Map<String, dynamic>) {
            return _page(
              settings,
              InscriptionHotelPage(hotel: arg as Map<String, dynamic>?),
            );
          }
          return _error(settings, 'Argument invalide pour $inscriptionHotel');
        }

      case inscriptionClinique:
        {
          final arg = settings.arguments;
          if (arg == null || arg is Map<String, dynamic>) {
            return _page(
              settings,
              EditCliniquePage(clinique: arg as Map<String, dynamic>?),
            );
          }
          return _error(
              settings, 'Argument invalide pour $inscriptionClinique');
        }

      case annonceDetail:
        {
          final arg = settings.arguments;
          if (arg is AnnonceModel) {
            return _page(settings, AnnonceDetailPage(annonce: arg));
          }
          return _error(settings, 'Argument invalide pour $annonceDetail');
        }

      case restoDetail:
        {
          final arg = settings.arguments;
          final String? restoId = (arg is String) ? arg : arg?.toString();
          if (restoId == null || restoId.isEmpty) {
            return _error(settings, 'ID invalide pour $restoDetail');
          }
          return _page(settings, RestoDetailPage(restoId: restoId));
        }

      case hotelDetail:
        {
          final id = settings.arguments;
          if (id is int) {
            return _page(settings, HotelDetailPage(hotelId: id));
          }
          return _error(settings, 'ID invalide pour $hotelDetail');
        }

      case editPrestataire:
        return _page(
            settings, EditPrestatairePage(prestataire: _argsMap(settings)));
      case editHotel:
        return _page(
            settings, EditHotelPage(hotelId: _argsMap(settings)['id']));
      case editResto:
        return _page(settings, EditRestoPage(resto: _argsMap(settings)));
      case editAnnonce:
        return _page(settings, EditAnnoncePage(annonce: _argsMap(settings)));
      case editClinique:
        return _page(settings, EditCliniquePage(clinique: _argsMap(settings)));

      // ====== BILLETTERIE ======
      case billetterie:
        return _page(settings, const BilletterieHomePage());

      case billetterieDetail:
        {
          final a = settings.arguments;
          final String? eventId =
              (a is String) ? a : (a is Map ? a['id']?.toString() : null);
          if (eventId == null || eventId.isEmpty) {
            return _error(settings, 'eventId requis pour $billetterieDetail');
          }
          return _page(settings, EventDetailPage(eventId: eventId));
        }

      case myTickets:
        return _userProtected(settings, (_) => const MesBilletsPage());

      case scanner:
        return _userProtected(settings, (_) => const TicketScannerPage());

      case billetteriePro:
        return _userProtected(settings, (_) => const ProEvenementsPage());

      case billetterieVentes:
        return _userProtected(settings, (_) => const ProVentesPage());

      // ====== JOB ======
      case jobHome:
        return _page(settings, const JobHomePage());
      case jobList:
        return _page(settings, const JobsPage());

      case jobDetail:
        {
          final a = settings.arguments;
          String? jobId;
          if (a is String && a.isNotEmpty) {
            jobId = a;
          } else if (a is Map) {
            final m = Map<String, dynamic>.from(a as Map);
            jobId = (m['jobId'] as String?) ?? (m['id'] as String?);
          }
          if (jobId == null || jobId.isEmpty) {
            return _error(settings, 'jobId requis pour $jobDetail');
          }
          return _page(settings, JobDetailPage(jobId: jobId!));
        }

      case myApplications:
        return _userProtected(settings, (_) => const apps.MyApplicationsPage());

      case cvMaker:
        return _userProtected(settings, (_) => const CvMakerPage());

      case employerOffers:
        return _userProtected(
          settings,
          (_) => _EmployeurGate(
            builder: (empId) => MesOffresPage(employeurId: empId),
            onMissing: const DevenirEmployeurPage(),
          ),
        );

      case employerOfferEdit:
        {
          final arg = settings.arguments;
          return _userProtected(
            settings,
            (_) => _EmployeurGate(
              builder: (empId) {
                if (arg == null) {
                  return OffreEditPage(employeurId: empId);
                }
                if (arg is EmploiModel) {
                  return OffreEditPage(existing: arg, employeurId: empId);
                }
                return const _RouteErrorPage(
                  'Argument invalide pour /jobs/employer/offre_edit (attendu EmploiModel ou null)',
                );
              },
              onMissing: const DevenirEmployeurPage(),
            ),
          );
        }

      case employerOfferCandidatures:
        {
          final m = _argsMap(settings);
          final id = (m['emploiId'] as String?) ?? (m['id'] as String?);
          final titre = (m['titre'] as String?) ?? 'Candidatures';
          if (id == null || id.isEmpty) {
            return _error(
                settings, 'emploiId requis pour $employerOfferCandidatures');
          }
          return _userProtected(
            settings,
            (_) => _EmployeurGate(
              builder: (_) => CandidaturesPage(jobId: id, jobTitle: titre),
              onMissing: const DevenirEmployeurPage(),
            ),
          );
        }

      // ----- AUTH: reset password -----
      case forgotPassword:
        return _page(settings, const ForgotPasswordPage());
      case resetPassword:
        return _page(settings, const ResetPasswordPage());

      default:
        return _error(settings, 'Page non trouvée : $name');
    }
  }

  // Helpers
  static Map<String, dynamic> _argsMap(RouteSettings s) {
    final a = s.arguments;
    return (a is Map)
        ? Map<String, dynamic>.from(a as Map)
        : <String, dynamic>{};
  }

  /// ✅ Route fluide globale (slide + back-swipe iOS)
  static PageRoute<T> _page<T>(RouteSettings settings, Widget child) {
    return CupertinoPageRoute<T>(
      settings: settings,
      builder: (_) => child,
    );
  }

  static PageRoute _error(RouteSettings settings, String msg) {
    return CupertinoPageRoute(
      settings: settings,
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Erreur')),
        body: Center(child: Text(msg)),
      ),
    );
  }

  /// ✅ Gate utilisateur en gardant les mêmes transitions fluides
  static PageRoute _userProtected(
    RouteSettings settings,
    Widget Function(UtilisateurModel) builder,
  ) {
    return CupertinoPageRoute(
      settings: settings,
      builder: (context) {
        final user =
            Provider.of<UserProvider>(context, listen: false).utilisateur;

        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ModalRoute.of(context)?.settings.name != login) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                login,
                (route) => false,
              );
            }
          });

          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return builder(user);
      },
    );
  }
}

// ------------------ Helpers JOB ------------------

class _EmployeurGate extends StatelessWidget {
  const _EmployeurGate({
    required this.builder,
    required this.onMissing,
  });

  final Widget Function(String employeurId) builder;
  final Widget onMissing;

  @override
  Widget build(BuildContext context) {
    final svc = EmployeurService();
    return FutureBuilder<String?>(
      future: svc.getEmployeurId(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return _RouteErrorPage('Erreur: ${snap.error}');
        }
        final id = snap.data;
        if (id == null) return onMissing;
        return builder(id);
      },
    );
  }
}

class _RouteErrorPage extends StatelessWidget {
  const _RouteErrorPage(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Erreur')),
      body: Center(child: Text(message)),
    );
  }
}

// ------------------ Helpers parsing Logement ------------------

LogementMode _parseMode(dynamic v) {
  if (v is LogementMode) return v;
  if (v is String) {
    switch (v.toLowerCase()) {
      case 'achat':
        return LogementMode.achat;
      case 'location':
      default:
        return LogementMode.location;
    }
  }
  return LogementMode.location;
}

LogementCategorie? _parseCategorieOrNull(dynamic v) {
  if (v == null) return null;
  if (v is LogementCategorie) return v;
  if (v is String) {
    switch (v.toLowerCase()) {
      case 'maison':
        return LogementCategorie.maison;
      case 'appartement':
        return LogementCategorie.appartement;
      case 'studio':
        return LogementCategorie.studio;
      case 'terrain':
        return LogementCategorie.terrain;
      case 'autres':
        return LogementCategorie.autres;
      case 'tous':
        return null;
    }
  }
  return LogementCategorie.autres;
}

String _prettyServiceName(String table) {
  switch (table) {
    case 'annonces':
      return 'Annonces';
    case 'prestataires':
      return 'Prestataires';
    case 'restaurants':
      return 'Restaurants';
    case 'lieux':
      return 'Lieux (Culte / Divertissement / Tourisme)';
    case 'cliniques':
      return 'Cliniques';
    case 'hotels':
      return 'Hôtels';
    case 'logements':
      return 'Logements';
    case 'emplois':
      return 'Wali fen (Emplois)';
    case 'events':
      return 'Billetterie (Events)';
    default:
      return table.isNotEmpty
          ? table[0].toUpperCase() + table.substring(1)
          : table;
  }
}
