// lib/pages/aide_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../routes.dart' show AppRoutes;

// ✅ Import de la vraie CGU à jour (sans importer kAppPrimary pour éviter conflits)
import 'cgu_page.dart' show CGUPage;

// ✅ Couleur officielle app (même que Login/Splash)
const Color kAppPrimary = Color(0xFF0175C2);

class AidePage extends StatefulWidget {
  const AidePage({super.key});
  @override
  State<AidePage> createState() => _AidePageState();
}

class _AidePageState extends State<AidePage> {
  static const String kSupportEmail = 'soneya.signaler@gmail.com';
  static const String kAdminEmail = 'soneya.signaler@gmail.com';

  static const String kDisplayPhone = '00224620452964';
  static const String _waNumber = '224620452964';
  static const String _telE164 = '+224620452964';

  // ✅ Accent = couleur de l’app
  final Color cPrimary = kAppPrimary;

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _selectedCategory = 'Tous';

  late final Set<String> _availableRoutes = {
    AppRoutes.splash,
    AppRoutes.welcome,
    AppRoutes.mainNav,
    AppRoutes.home,
    AppRoutes.annonces,
    AppRoutes.pro,
    AppRoutes.carte,
    AppRoutes.divertissement,
    AppRoutes.admin,
    AppRoutes.resto,
    AppRoutes.culte,
    AppRoutes.logement,
    AppRoutes.logementList,
    AppRoutes.logementDetail,
    AppRoutes.logementEdit,
    AppRoutes.logementMap,
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.tourisme,
    AppRoutes.sante,
    AppRoutes.hotel,
    AppRoutes.notifications,
    AppRoutes.profil,
    AppRoutes.parametre,
    AppRoutes.aide,
    AppRoutes.messages,
    AppRoutes.mesAnnonces,
    AppRoutes.mesPrestations,
    AppRoutes.mesRestaurants,
    AppRoutes.mesHotels,
    AppRoutes.mesCliniques,
    AppRoutes.inscriptionResto,
    AppRoutes.inscriptionHotel,
    AppRoutes.inscriptionClinique,
    AppRoutes.annonceDetail,
    AppRoutes.restoDetail,
    AppRoutes.hotelDetail,
    AppRoutes.editPrestataire,
    AppRoutes.editHotel,
    AppRoutes.editResto,
    AppRoutes.editAnnonce,
    AppRoutes.editClinique,
    AppRoutes.billetterie,
    AppRoutes.myTickets,
    AppRoutes.scanner,
    AppRoutes.jobHome,
    AppRoutes.jobList,
    AppRoutes.jobDetail,
    AppRoutes.myApplications,
    AppRoutes.cvMaker,
    AppRoutes.employerOffers,
    AppRoutes.employerOfferEdit,
    AppRoutes.employerOfferCandidatures,
  };

  bool _hasRoute(String? name) =>
      name != null && _availableRoutes.contains(name);

  late final List<FAQItem> _allFaqs = [
    FAQItem.cat(
      'Annonces',
      'Publier une annonce',
      'Onglet Annonces → Publier (photos, prix en GNF, ville, etc.).',
      routeName: AppRoutes.editAnnonce,
      cta: 'Publier',
    ),
    FAQItem.cat(
      'Annonces',
      'Gérer mes annonces',
      'Profil → Mes annonces : modifier ou supprimer.',
      routeName: AppRoutes.mesAnnonces,
      cta: 'Mes annonces',
    ),
    FAQItem.cat(
      'Prestataires',
      'Trouver / devenir prestataire',
      'Parcourez les pros par ville/métier. Pour créer votre fiche : “Devenir prestataire”.',
      routeName: AppRoutes.pro,
      secondaryRouteName: AppRoutes.editPrestataire,
      secondaryCta: 'Créer ma fiche',
    ),
    FAQItem.cat(
      'Services Admin',
      'Annuaire administratif',
      'Consultez les services administratifs (horaires, contacts, adresses).',
      routeName: AppRoutes.admin,
      cta: 'Ouvrir',
    ),
    FAQItem.cat(
      'Restaurants',
      'Trouver et réserver',
      'Liste ou carte, ouvrez la fiche (menu, avis) et contactez le restaurant.',
      routeName: AppRoutes.resto,
      secondaryRouteName: AppRoutes.inscriptionResto,
      secondaryCta: 'Inscrire un resto',
    ),
    FAQItem.cat(
      'Lieux de culte',
      'Localiser un lieu de culte',
      'Sur la carte, filtre “Lieux de culte”, touchez un marqueur pour les détails.',
      routeName: AppRoutes.culte,
      secondaryRouteName: AppRoutes.carte,
      secondaryCta: 'Voir la carte',
    ),
    FAQItem.cat(
      'Divertissement',
      'Sorties et activités',
      'Cinéma, spectacles, parcs, etc. avec infos et contacts.',
      routeName: AppRoutes.divertissement,
      cta: 'Explorer',
    ),
    FAQItem.cat(
      'Tourisme',
      'Activités & circuits',
      'Circuits, lieux incontournables, bons plans, itinéraires.',
      routeName: AppRoutes.tourisme,
      cta: 'Découvrir',
    ),
    FAQItem.cat(
      'Santé',
      'Cliniques & urgences',
      'Filtrez par spécialité, voyez adresse/horaires. Urgences : section numéros utiles.',
      routeName: AppRoutes.sante,
      secondaryRouteName: AppRoutes.inscriptionClinique,
      secondaryCta: 'Inscrire une clinique',
    ),
    FAQItem.cat(
      'Hôtels',
      'Réserver un hôtel',
      'Filtrez par ville/budget, contactez l’établissement pour réserver.',
      routeName: AppRoutes.hotel,
      secondaryRouteName: AppRoutes.inscriptionHotel,
      secondaryCta: 'Inscrire un hôtel',
    ),
    FAQItem.cat(
      'Logement',
      'Trouver un logement (liste/carte)',
      'Filtrez par ville, type et budget. Contactez le propriétaire/agent depuis la fiche.',
      routeName: AppRoutes.logement,
      secondaryRouteName: AppRoutes.logementMap,
      secondaryCta: 'Voir sur la carte',
    ),
    FAQItem.cat(
      'Logement',
      'Publier un logement',
      'Ajoutez photos, prix en GNF, localisation précise et contact vérifié.',
      routeName: AppRoutes.logementEdit,
      cta: 'Publier un logement',
    ),
    FAQItem.cat(
      'Emplois',
      'Créer mon CV & postuler',
      'Jobs → Mon CV → Postuler. Suivi dans Mes candidatures.',
      routeName: AppRoutes.jobHome,
      secondaryRouteName: AppRoutes.myApplications,
      secondaryCta: 'Mes candidatures',
    ),
    FAQItem.cat(
      'Emplois',
      'Publier une offre (employeur)',
      'Espace employeur complet.',
      routeName: AppRoutes.employerOffers,
      cta: 'Espace employeur',
    ),
    FAQItem.cat(
      'Billetterie',
      'Acheter des billets',
      'Payez puis retrouvez vos billets dans “Mes billets”.',
      routeName: AppRoutes.billetterie,
      secondaryRouteName: AppRoutes.myTickets,
      secondaryCta: 'Mes billets',
    ),
    FAQItem.cat(
      'Carte',
      'Utiliser la carte interactive',
      'Activez les couches, zoom puis touchez un marqueur.',
      routeName: AppRoutes.carte,
      cta: 'Ouvrir la carte',
    ),
    FAQItem.cat(
      'Messages',
      'Retrouver mes conversations',
      'Toutes vos conversations sont dans Messages.',
      routeName: AppRoutes.messages,
      cta: 'Ouvrir Messages',
    ),
    FAQItem.cat(
      'Profil',
      'Modifier mon profil',
      'Photo, nom, bio, coordonnées…',
      routeName: AppRoutes.profil,
      cta: 'Ouvrir Profil',
    ),
    FAQItem.cat(
      'Support',
      'Contacter le support',
      'WhatsApp ou Email via Contact ci-dessous.',
    ),
  ];

  final List<String> _categories = const [
    'Tous',
    'Annonces',
    'Prestataires',
    'Services Admin',
    'Restaurants',
    'Lieux de culte',
    'Divertissement',
    'Tourisme',
    'Santé',
    'Hôtels',
    'Entreprises',
    'Logement',
    'Emplois',
    'Billetterie',
    'Carte',
    'Messages',
    'Profil',
    'Paiements',
    'Sécurité',
    'Support',
  ];

  List<FAQItem> get _filtered {
    final q = _query.trim().toLowerCase();
    return _allFaqs.where((f) {
      final byCat =
          _selectedCategory == 'Tous' ? true : f.category == _selectedCategory;
      final byText =
          q.isEmpty ? true : (f.questionL.contains(q) || f.answerL.contains(q));
      return byCat && byText;
    }).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
            backgroundColor: const Color(0xFFF2F3F5),
            elevation: 0.4,
            iconTheme: IconThemeData(color: cPrimary),
            title: Text(
              'Aide & FAQ',
              style: TextStyle(
                color: cPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearch(),
                  const SizedBox(height: 12),
                  _buildCategoryChips(),
                ],
              ),
            ),
          ),
          SliverList.list(
            children: [
              ..._filtered.map(
                (f) => _FAQTile(
                  item: f,
                  accent: cPrimary,
                  enabledPrimary: _hasRoute(f.routeName),
                  enabledSecondary: _hasRoute(f.secondaryRouteName),
                  onOpenPrimary: () => _pushIfAvailable(f.routeName),
                  onOpenSecondary: () => _pushIfAvailable(f.secondaryRouteName),
                ),
              ),
              const SizedBox(height: 16),
              _buildContactSection(),
              const SizedBox(height: 28),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFFF2F3F5),
      padding: const EdgeInsets.fromLTRB(16, 72, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Besoin d’aide ?\nToutes les rubriques de l’application.',
              style: TextStyle(
                color: Colors.grey.shade900,
                fontSize: 18,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cPrimary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.help_outline, size: 26, color: cPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Rechercher dans la FAQ…',
          prefixIcon: Icon(Icons.search, color: cPrimary),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((c) {
          final selected = _selectedCategory == c;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(c),
              selected: selected,
              onSelected: (_) => setState(() => _selectedCategory = c),
              selectedColor: cPrimary.withOpacity(.10),
              labelStyle: TextStyle(
                color: selected ? cPrimary : Colors.black87,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              shape: StadiumBorder(
                side: BorderSide(
                  color: selected ? cPrimary : Colors.grey.shade300,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContactSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Material(
        color: Colors.white,
        elevation: 0,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.support_agent, color: cPrimary),
                  const SizedBox(width: 8),
                  const Text(
                    'Support, Administration & CGU',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.contact_phone, color: cPrimary),
                title: const Text('Contact'),
                subtitle: const Text('Support'),
                trailing: const Icon(Icons.expand_more),
                onTap: _showContactSheet,
              ),
              const Divider(height: 16),
              _ContactRow(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Administration',
                value: kAdminEmail,
                accent: cPrimary,
                onTap: _openAdminEmail,
              ),
              const SizedBox(height: 6),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.description_outlined, color: cPrimary),
                title: const Text('CGU'),
                subtitle: const Text('Consulter'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openCgu,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pushIfAvailable(String? routeName) {
    if (!_hasRoute(routeName)) return;
    Navigator.of(context).pushNamed(routeName!);
  }

  void _showContactSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              const ListTile(
                title: Text(
                  'Contacter le support',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: Icon(Icons.chat_bubble_outline, color: cPrimary),
                title: const Text('WhatsApp'),
                subtitle: const Text('Ouvrir WhatsApp'),
                onTap: () {
                  Navigator.pop(context);
                  _openWhatsApp();
                },
              ),
              ListTile(
                leading: Icon(Icons.email_outlined, color: cPrimary),
                title: const Text('Envoyer un e-mail'),
                subtitle: const Text(kSupportEmail),
                onTap: () {
                  Navigator.pop(context);
                  _openSupportEmail();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/$_waNumber');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      await _openSupportEmail();
    }
  }

  Future<void> _openSupportEmail() async {
    final params = {
      'subject': 'Support - Soneya',
      'body': 'Bonjour,%0D%0A%0D%0A',
    };
    final uri = Uri(
      scheme: 'mailto',
      path: kSupportEmail,
      query: params.entries.map((e) => '${e.key}=${e.value}').join('&'),
    );
    await launchUrl(uri);
  }

  Future<void> _openAdminEmail() async {
    final params = {
      'subject': 'Administration - Soneya',
      'body': 'Bonjour,%0D%0A%0D%0A',
    };
    final uri = Uri(
      scheme: 'mailto',
      path: kAdminEmail,
      query: params.entries.map((e) => '${e.key}=${e.value}').join('&'),
    );
    await launchUrl(uri);
  }

  Future<void> _openCgu() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CGUPage()),
    );
  }
}

// ==========================================================
// WIDGETS INTERNES
// ==========================================================
class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final VoidCallback onTap;
  final Color accent;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: accent),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(value),
      trailing: const Icon(Icons.open_in_new),
      onTap: onTap,
    );
  }
}

class _FAQTile extends StatelessWidget {
  final FAQItem item;
  final Color accent;
  final bool enabledPrimary, enabledSecondary;
  final VoidCallback? onOpenPrimary, onOpenSecondary;

  const _FAQTile({
    required this.item,
    required this.accent,
    required this.enabledPrimary,
    required this.enabledSecondary,
    this.onOpenPrimary,
    this.onOpenSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrimary = item.routeName != null && item.routeName!.isNotEmpty;
    final hasSecondary =
        item.secondaryRouteName != null && item.secondaryRouteName!.isNotEmpty;

    ButtonStyle _btnStyle(bool enabled) => OutlinedButton.styleFrom(
          foregroundColor: enabled ? accent : Colors.grey,
          side: BorderSide(color: enabled ? accent : Colors.grey.shade300),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Material(
        color: Colors.white,
        elevation: 0,
        borderRadius: BorderRadius.circular(16),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            leading: Container(
              width: 8,
              height: 32,
              decoration: BoxDecoration(
                color: accent.withOpacity(.9),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            title: Text(
              item.question,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              item.category,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item.answer,
                  style: const TextStyle(height: 1.35),
                ),
              ),
              if (hasPrimary || hasSecondary) const SizedBox(height: 10),
              if (hasPrimary || hasSecondary)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (hasPrimary)
                      OutlinedButton.icon(
                        onPressed: enabledPrimary ? onOpenPrimary : null,
                        style: _btnStyle(enabledPrimary),
                        icon: const Icon(Icons.open_in_new),
                        label: Text(item.cta ??
                            (enabledPrimary
                                ? 'Aller à la rubrique'
                                : 'Indisponible')),
                      ),
                    if (hasSecondary)
                      OutlinedButton(
                        onPressed: enabledSecondary ? onOpenSecondary : null,
                        style: _btnStyle(enabledSecondary),
                        child: Text(item.secondaryCta ??
                            (enabledSecondary ? 'Ouvrir' : 'Indisponible')),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class FAQItem {
  final String category, question, answer;
  final String? routeName, cta, secondaryRouteName, secondaryCta;

  String get questionL => question.toLowerCase();
  String get answerL => answer.toLowerCase();

  FAQItem({
    required this.category,
    required this.question,
    required this.answer,
    this.routeName,
    this.cta,
    this.secondaryRouteName,
    this.secondaryCta,
  });

  factory FAQItem.cat(
    String c,
    String q,
    String a, {
    String? routeName,
    String? cta,
    String? secondaryRouteName,
    String? secondaryCta,
  }) =>
      FAQItem(
        category: c,
        question: q,
        answer: a,
        routeName: routeName,
        cta: cta,
        secondaryRouteName: secondaryRouteName,
        secondaryCta: secondaryCta,
      );
}
