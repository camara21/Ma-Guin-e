import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/annonce_model.dart';
import 'models/utilisateur_model.dart';
import 'models/job_models.dart'; // EmploiModel
import 'models/logement_models.dart'; // ✅ enums & model Logement

// Pages principales
import 'pages/splash_screen.dart';
import 'pages/welcome_page.dart';
import 'pages/home_page.dart';
import 'pages/annonces_page.dart';
import 'pages/pro_page.dart';
import 'pages/carte_page.dart';
import 'pages/divertissement_page.dart';
import 'pages/admin_page.dart';

// Alias clairs
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

// Édition & Inscription
import 'pages/edit_prestataire_page.dart';
import 'pages/edit_hotel_page.dart';
import 'pages/edit_resto_page.dart';
import 'pages/edit_annonce_page.dart';
import 'pages/edit_clinique_page.dart';
import 'pages/inscription_resto_page.dart';
import 'pages/inscription_prestataire_page.dart';
import 'pages/inscription_hotel_page.dart';

import 'providers/user_provider.dart';

// Billetterie
import 'pages/events_list_page.dart';
import 'pages/my_tickets_page.dart';
import 'pages/scanner_page.dart';

// JOB – pages existantes
import 'pages/jobs/job_home_page.dart';
import 'pages/jobs/jobs_page.dart';
import 'pages/jobs/job_detail_page.dart';

// ⚠️ IMPORTANT: alias pour éviter tout conflit
import 'pages/jobs/my_applications_page.dart' as apps;

import 'pages/cv/cv_maker_page.dart';
import 'pages/jobs/employer/mes_offres_page.dart';
import 'pages/jobs/employer/offre_edit_page.dart';

// JOB – nouvelles pages Candidatures
import 'pages/jobs/candidatures_page.dart';
import 'pages/jobs/candidature_detail_page.dart';

// Employeur & garde
import 'pages/jobs/employer/devenir_employeur_page.dart';
import 'services/employeur_service.dart';

// ✅ Module Logement (toutes les pages)
import 'pages/logement/logement_home_page.dart';
import 'pages/logement/logement_list_page.dart';
import 'pages/logement/logement_detail_page.dart';
import 'pages/logement/logement_edit_page.dart';
import 'pages/logement/logement_map_page.dart';

// ✅ AJOUTS ADMIN (nouveaux fichiers)
import 'admin/admin_dashboard.dart';
import 'admin/admin_gate.dart';
import 'admin/content_advanced_page.dart';

// ✅ Auth – Reset password flow (ForgotPasswordPage & ResetPasswordPage)
import 'pages/auth/reset_password_flow.dart';

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
  static const String admin = '/administratif'; // ⚠️ inchangé

  static const String resto = '/restos';
  static const String culte = '/culte';

  // ✅ LOGEMENT
  static const String logement = '/logement'; // Home
  static const String logementList = '/logement/list'; // Liste
  static const String logementDetail = '/logement/detail'; // Détail
  static const String logementEdit = '/logement/edit'; // Créer/éditer
  static const String logementMap = '/logement/map'; // Carte

  static const String login = '/login';
  static const String register = '/register';
  static const String tourisme = '/tourisme';
  static const String sante = '/sante';
  static const String hotel = '/hotels';
  static const String notifications = '/notifications';
  static const String profil = '/profil';

  // Paramètres
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

  // Billetterie
  static const String billetterie = '/billetterie';
  static const String myTickets = '/mes_billets';
  static const String scanner = '/scanner';

  // JOB
  static const String jobHome = '/jobs';
  static const String jobList = '/jobs/list';
  static const String jobDetail = '/jobs/detail';
  static const String myApplications = '/jobs/my_applications';
  static const String cvMaker = '/jobs/cv';
  static const String employerOffers = '/jobs/employer/offres';
  static const String employerOfferEdit = '/jobs/employer/offre_edit';
  static const String employerOfferCandidatures = '/jobs/employer/candidatures';

  // ✅ NOUVEL ESPACE ADMIN (en plus, séparé de /administratif)
  static const String adminCenter = '/admin';
  static const String adminManage = '/admin/manage';

  // ✅ Auth – reset password
  static const String forgotPassword = '/forgot_password';
  static const String resetPassword = '/reset_password';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // ✅ Nouvelles routes admin (indépendantes de /administratif)
      case adminCenter:
        return MaterialPageRoute(
          builder: (_) => const AdminGate(child: AdminDashboard()),
        );

      case adminManage:
        {
          final a = _argsMap(settings);
          final table =
              (a['table']?.toString().trim().toLowerCase() ?? 'logements');
          final title = (a['title']?.toString().trim().isNotEmpty == true)
              ? a['title'].toString()
              : _prettyServiceName(table);
          return MaterialPageRoute(
            builder: (_) => AdminGate(
              child: ContentAdvancedPage(title: title, table: table),
            ),
          );
        }

      // Core
      case splash:       return _page(const SplashScreen());
      case welcome:      return _page(const WelcomePage());
      case mainNav:      return _page(const MainNavigationPage());
      case home:         return _page(const HomePage());

      // Existants
      case annonces:         return _page(const AnnoncesPage());
      case pro:              return _page(const ProPage());
      case carte:            return _page(const CartePage());
      case divertissement:   return _page(const DivertissementPage());
      case admin:            return _page(const AdminPage()); // ⚠️ inchangé
      case resto:            return _page(const resto_pg.RestoPage());
      case culte:            return _page(const CultePage());

      // ===================== LOGEMENT =====================
      case logement:         return _page(const LogementHomePage());
      case logementList: {
        final a = _argsMap(settings);
        final String? q = a['q'] as String?;
        final LogementMode mode = _parseMode(a['mode']);
        final LogementCategorie? cat = _parseCategorieOrNull(a['categorie']);
        return _page(LogementListPage(
          initialQuery: q,
          initialMode: mode,
          initialCategorie: cat ?? LogementCategorie.autres,
        ));
      }
      case logementDetail: {
        final a = settings.arguments;
        final id = (a is String) ? a : (a is Map ? (a['id']?.toString()) : null);
        if (id == null || id.isEmpty) return _error('ID requis pour $logementDetail');
        return _page(LogementDetailPage(logementId: id));
      }
      case logementEdit: {
        final a = _argsMap(settings);
        final existing = a['existing'];
        if (existing != null && existing is! LogementModel) {
          return _error('Argument "existing" invalide pour $logementEdit');
        }
        return _userProtected((_) => LogementEditPage(existing: existing as LogementModel?));
      }
      case logementMap: {
        final a = _argsMap(settings);
        double? _d(dynamic v) {
          if (v == null) return null;
          if (v is num) return v.toDouble();
          return double.tryParse(v.toString());
        }
        return MaterialPageRoute(
          builder: (_) => LogementMapPage(
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
      // ===================== /LOGEMENT =====================

      // Auth / profil / divers
      case login:           return _page(const LoginPage());
      case register:        return _page(const register_pg.RegisterPage());
      case tourisme:        return _page(const TourismePage());
      case sante:           return _page(const SantePage());
      case hotel:           return _page(const HotelPage());
      case notifications:   return _page(const NotificationsPage());
      case profil:          return _userProtected((u) => ProfilePage(user: u));

      // Paramètres
      case parametre:       return _userProtected((u) => ParametrePage(user: u));

      case aide:            return _page(const AidePage());
      case messages:        return _page(const MessagesPage());

      case mesAnnonces:     return _userProtected((_) => const MesAnnoncesPage());
      case mesPrestations:  return _userProtected((u) {
        final prestations = u.espacePrestataire != null
            ? [u.espacePrestataire!]
            : <Map<String, dynamic>>[];
        return MesPrestationsPage(prestations: prestations);
      });
      case mesRestaurants:  return _userProtected(
        (u) => myresto_pg.MesRestaurantsPage(restaurants: u.restos ?? []),
      );
      case mesHotels:       return _userProtected(
        (u) => hotel_page.MesHotelsPage(hotels: u.hotels ?? []),
      );
      case mesCliniques:    return _userProtected(
        (u) => MesCliniquesPage(cliniques: u.cliniques ?? []),
      );

      case inscriptionResto: {
        final arg = settings.arguments;
        if (arg == null || arg is Map<String, dynamic>) {
          return _page(InscriptionRestoPage(restaurant: arg as Map<String, dynamic>?));
        }
        return _error('Argument invalide pour $inscriptionResto');
      }
      case inscriptionHotel: {
        final arg = settings.arguments;
        if (arg == null || arg is Map<String, dynamic>) {
          return _page(InscriptionHotelPage(hotel: arg as Map<String, dynamic>?));
        }
        return _error('Argument invalide pour $inscriptionHotel');
      }
      case inscriptionClinique: {
        final arg = settings.arguments;
        if (arg == null || arg is Map<String, dynamic>) {
          return _page(EditCliniquePage(clinique: arg as Map<String, dynamic>?));
        }
        return _error('Argument invalide pour $inscriptionClinique');
      }

      case annonceDetail: {
        final arg = settings.arguments;
        if (arg is AnnonceModel) return _page(AnnonceDetailPage(annonce: arg));
        return _error('Argument invalide pour $annonceDetail');
      }
      case restoDetail: {
        final arg = settings.arguments;
        final String? restoId = (arg is String) ? arg : arg?.toString();
        if (restoId == null || restoId.isEmpty) return _error('ID invalide pour $restoDetail');
        return _page(RestoDetailPage(restoId: restoId));
      }
      case hotelDetail: {
        final id = settings.arguments;
        if (id is int) return _page(HotelDetailPage(hotelId: id));
        return _error('ID invalide pour $hotelDetail');
      }

      case editPrestataire: return _page(EditPrestatairePage(prestataire: _argsMap(settings)));
      case editHotel:       return _page(EditHotelPage(hotelId: _argsMap(settings)['id']));
      case editResto:       return _page(EditRestoPage(resto: _argsMap(settings)));
      case editAnnonce:     return _page(EditAnnoncePage(annonce: _argsMap(settings)));
      case editClinique:    return _page(EditCliniquePage(clinique: _argsMap(settings)));

      // Billetterie
      case billetterie:     return _page(const EventsListPage());
      case myTickets:       return _userProtected((_) => const MyTicketsPage());
      case scanner:         return _userProtected((_) => const ScannerPage());

      // JOB
      case jobHome:         return _page(const JobHomePage());
      case jobList:         return _page(const JobsPage());
      case jobDetail: {
        final a = settings.arguments;
        String? jobId;
        if (a is String && a.isNotEmpty) {
          jobId = a;
        } else if (a is Map) {
          final m = Map<String, dynamic>.from(a as Map);
          jobId = (m['jobId'] as String?) ?? (m['id'] as String?);
        }
        if (jobId == null || jobId.isEmpty) {
          return _error('jobId requis pour $jobDetail');
        }
        return MaterialPageRoute(builder: (_) => JobDetailPage(jobId: jobId!));
      }

      case myApplications:  return _userProtected((_) => const apps.MyApplicationsPage());
      case cvMaker:         return _userProtected((_) => const CvMakerPage());

      // ---------- ESPACE EMPLOYEUR ----------
      case employerOffers:  return _userProtected(
        (_) => _EmployeurGate(
          builder: (empId) => MesOffresPage(employeurId: empId),
          onMissing: const DevenirEmployeurPage(),
        ),
      );

      case employerOfferEdit: {
        final arg = settings.arguments;
        return _userProtected(
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

      case employerOfferCandidatures: {
        final m = _argsMap(settings);
        final id = (m['emploiId'] as String?) ?? (m['id'] as String?);
        final titre = (m['titre'] as String?) ?? 'Candidatures';
        if (id == null || id.isEmpty) {
          return _error('emploiId requis pour $employerOfferCandidatures');
        }
        return _userProtected(
          (_) => _EmployeurGate(
            builder: (_) => CandidaturesPage(jobId: id, jobTitle: titre),
            onMissing: const DevenirEmployeurPage(),
          ),
        );
      }

      // ----- Auth: reset password -----
      case forgotPassword:  return _page(const ForgotPasswordPage());
      case resetPassword:   return _page(const ResetPasswordPage());

      default:
        return _error('Page non trouvée : ${settings.name}');
    }
  }

  // Helpers
  static Map<String, dynamic> _argsMap(RouteSettings s) {
    final a = s.arguments;
    return (a is Map)
        ? Map<String, dynamic>.from(a as Map)
        : <String, dynamic>{};
  }

  static MaterialPageRoute _page(Widget child) =>
      MaterialPageRoute(builder: (_) => child);

  static MaterialPageRoute _error(String msg) => MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Erreur')),
          body: Center(child: Text(msg)),
        ),
      );

  static MaterialPageRoute _userProtected(
    Widget Function(UtilisateurModel) builder,
  ) {
    return MaterialPageRoute(
      builder: (context) {
        final user =
            Provider.of<UserProvider>(context, listen: false).utilisateur;
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ModalRoute.of(context)?.settings.name != login) {
              Navigator.pushNamed(context, login);
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

// ------------------ Helpers ajoutés pour JOB ------------------

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
        return null; // important: pas de filtre
    }
  }
  return LogementCategorie.autres;
}

// ✅ Helper lisible pour les titres de /admin/manage quand "title" n’est pas fourni
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
      return table[0].toUpperCase() + table.substring(1);
  }
}
