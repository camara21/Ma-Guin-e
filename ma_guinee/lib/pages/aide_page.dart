// lib/pages/aide_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Ajuste le chemin si AppRoutes est ailleurs
import '../routes.dart' show AppRoutes;

class AidePage extends StatefulWidget {
  const AidePage({super.key});
  @override
  State<AidePage> createState() => _AidePageState();
}

class _AidePageState extends State<AidePage> {
  // ===== Config contact =====
  static const String kSupportEmail = 'soneya.signaler@gmail.com';
  static const String kAdminEmail = 'soneya.signaler@gmail.com';

  // Affichage tel (comme demandé) & formats normalisés
  static const String kDisplayPhone = '00224620452964';
  static const String _waNumber = '224620452964'; // pour wa.me (sans + ni 00)
  static const String _telE164 = '+224620452964'; // pour tel:

  // ===== Thème local =====
  final Color cPrimary = const Color(0xFF475569);
  final Color cSoftBg = const Color(0xFF94A3B8).withOpacity(0.08);

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _selectedCategory = 'Tous';

  // Routes présentes (pour les CTA de la FAQ uniquement)
  late final Set<String> _availableRoutes = {
    // Core
    AppRoutes.splash, AppRoutes.welcome, AppRoutes.mainNav, AppRoutes.home,
    // Existants
    AppRoutes.annonces, AppRoutes.pro, AppRoutes.carte, AppRoutes.divertissement,
    AppRoutes.admin, AppRoutes.resto, AppRoutes.culte,
    // Logement
    AppRoutes.logement, AppRoutes.logementList, AppRoutes.logementDetail,
    AppRoutes.logementEdit, AppRoutes.logementMap,
    // Divers
    AppRoutes.login, AppRoutes.register, AppRoutes.tourisme, AppRoutes.sante,
    AppRoutes.hotel, AppRoutes.notifications, AppRoutes.profil,
    AppRoutes.parametre, AppRoutes.aide, AppRoutes.messages,
    AppRoutes.mesAnnonces, AppRoutes.mesPrestations, AppRoutes.mesRestaurants,
    AppRoutes.mesHotels, AppRoutes.mesCliniques,
    AppRoutes.inscriptionResto, AppRoutes.inscriptionHotel,
    AppRoutes.inscriptionClinique,
    AppRoutes.annonceDetail, AppRoutes.restoDetail, AppRoutes.hotelDetail,
    AppRoutes.editPrestataire, AppRoutes.editHotel, AppRoutes.editResto,
    AppRoutes.editAnnonce, AppRoutes.editClinique,
    // Billetterie
    AppRoutes.billetterie, AppRoutes.myTickets, AppRoutes.scanner,
    // Jobs
    AppRoutes.jobHome, AppRoutes.jobList, AppRoutes.jobDetail,
    AppRoutes.myApplications, AppRoutes.cvMaker,
    AppRoutes.employerOffers, AppRoutes.employerOfferEdit,
    AppRoutes.employerOfferCandidatures,
    // ⚠️ volontairement PAS de AppRoutes.cgu (rediraction directe)
  };

  bool _hasRoute(String? name) => name != null && _availableRoutes.contains(name);

  // ===== FAQ alignée aux routes =====
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
    // ====== Nouveaux services ======
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
      'Jobs → Mon CV (créer/importer) → ouvrir une offre → “Postuler”. Suivi dans “Mes candidatures”.',
      routeName: AppRoutes.jobHome,
      secondaryRouteName: AppRoutes.myApplications,
      secondaryCta: 'Mes candidatures',
    ),
    FAQItem.cat(
      'Emplois',
      'Publier une offre (employeur)',
      'Créez votre espace employeur et gérez vos offres/candidatures.',
      routeName: AppRoutes.employerOffers,
      cta: 'Espace employeur',
    ),
    FAQItem.cat(
      'Billetterie',
      'Acheter des billets',
      'Choisissez un événement, payez, puis retrouvez le QR code dans “Mes billets”.',
      routeName: AppRoutes.billetterie,
      secondaryRouteName: AppRoutes.myTickets,
      secondaryCta: 'Mes billets',
    ),
    // ====== Généraux ======
    FAQItem.cat(
      'Carte',
      'Utiliser la carte interactive',
      'Activez les couches (restaurants, hôtels, logements, prestataires…), zoomez puis touchez un marqueur.',
      routeName: AppRoutes.carte,
      cta: 'Ouvrir la carte',
    ),
    FAQItem.cat(
      'Messages',
      'Retrouver mes conversations',
      'Toutes vos conversations sont dans l’onglet Messages.',
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
    // ====== Placeholders ======
    FAQItem.cat('Entreprises', 'Annuaire des entreprises',
        'Recherche par nom/secteur/ville.',
        routeName: '__missing/entreprises', cta: 'Indisponible'),
    FAQItem.cat('Paiements', 'Problème de paiement',
        'Vérifiez la connexion/solde. Si débit sans billet, écrivez à $kSupportEmail avec le reçu.',
        routeName: '__missing/paiements', cta: 'Indisponible'),
    FAQItem.cat('Sécurité', 'Signaler un contenu abusif',
        'Depuis la fiche → “Signaler”. Vous pouvez aussi envoyer captures et lien à $kAdminEmail.',
        routeName: '__missing/securite', cta: 'Indisponible'),
    FAQItem.cat('Support', 'Contacter le support',
        'Appuyez sur “Contact” ci-dessous pour Appel / WhatsApp / E-mail.'),
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
      final byCat = _selectedCategory == 'Tous' ? true : f.category == _selectedCategory;
      final byText = q.isEmpty ? true : (f.questionL.contains(q) || f.answerL.contains(q));
      return byCat && byText;
    }).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cSoftBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            backgroundColor: Colors.white,
            elevation: 0.6,
            iconTheme: const IconThemeData(color: Colors.black87),
            title: const Text('Aide & FAQ',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
            flexibleSpace: FlexibleSpaceBar(background: _buildHeader()),
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
              ..._filtered.map((f) => _FAQTile(
                    item: f,
                    accent: cPrimary,
                    enabledPrimary: _hasRoute(f.routeName),
                    enabledSecondary: _hasRoute(f.secondaryRouteName),
                    onOpenPrimary: () => _pushIfAvailable(f.routeName),
                    onOpenSecondary: () => _pushIfAvailable(f.secondaryRouteName),
                  )),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cPrimary, const Color(0xFF94A3B8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 84, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Besoin d’aide ?\nToutes les rubriques, alignées sur l’app.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('❓', style: TextStyle(fontSize: 42)),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              selectedColor: cPrimary.withOpacity(.12),
              labelStyle: TextStyle(
                color: selected ? cPrimary : Colors.black87,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              shape: StadiumBorder(
                side: BorderSide(color: selected ? cPrimary : Colors.grey.shade300),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Section Contact (CGU ici)
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
              // Ouvre la feuille contact (Appel / WhatsApp / E-mail)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.contact_phone),
                title: const Text('Contact'),
                subtitle: const Text('Support'),
                trailing: const Icon(Icons.expand_more),
                onTap: _showContactSheet,
              ),
              const Divider(height: 16),
              // Email administration (lien direct)
              _ContactRow(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Administration',
                value: kAdminEmail,
                onTap: _openAdminEmail,
              ),
              const SizedBox(height: 6),
              // CGU (ouvre page interne sans route nommée)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: const Text('CGU'),
                subtitle: const Text('Consulter'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openCgu, // <-- redirection directe
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Actions & Navigation =====
  void _pushIfAvailable(String? routeName) {
    if (!_hasRoute(routeName)) return;
    Navigator.of(context).pushNamed(routeName!);
  }

  // Bottom sheet Contact (Appel / WhatsApp / E-mail)
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
                title: Text('Contacter le support',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('Appeler'),
                subtitle: const Text(kDisplayPhone),
                onTap: () {
                  Navigator.pop(context);
                  _launchTel(_telE164);
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('WhatsApp'),
                subtitle: const Text(kDisplayPhone),
                onTap: () {
                  Navigator.pop(context);
                  _openWhatsApp();
                },
              ),
              ListTile(
                leading: const Icon(Icons.email_outlined),
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

  Future<void> _launchTel(String telE164) async {
    final uri = Uri(scheme: 'tel', path: telE164);
    await launchUrl(uri);
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
      'subject': 'Support - Ma Guinée',
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
      'subject': 'Administration - Ma Guinée',
      'body': 'Bonjour,%0D%0A%0D%0A',
    };
    final uri = Uri(
      scheme: 'mailto',
      path: kAdminEmail,
      query: params.entries.map((e) => '${e.key}=${e.value}').join('&'),
    );
    await launchUrl(uri);
  }

  /// Ouvre la page CGU en **interne** SANS route nommée
  Future<void> _openCgu() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CGUPage()),
    );
  }
}

// ===== Widgets =====
class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final VoidCallback onTap;
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
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
          foregroundColor: enabled ? null : Colors.grey,
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
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            leading: Container(
              width: 8,
              height: 32,
              decoration: BoxDecoration(
                color: accent.withOpacity(.9),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            title: Text(item.question, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(item.category, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(item.answer, style: const TextStyle(height: 1.35)),
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
                        label: Text(item.cta ?? (enabledPrimary ? 'Aller à la rubrique' : 'Indisponible')),
                      ),
                    if (hasSecondary)
                      OutlinedButton(
                        onPressed: enabledSecondary ? onOpenSecondary : null,
                        style: _btnStyle(enabledSecondary),
                        child: Text(item.secondaryCta ?? (enabledSecondary ? 'Ouvrir' : 'Indisponible')),
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

/// =======================
///   PAGE INTERNE : CGU
/// =======================
class CGUPage extends StatelessWidget {
  const CGUPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Conditions Générales d’Utilisation")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: const SelectableText(
              '🧾 CONDITIONS GÉNÉRALES D’UTILISATION (CGU)\n\n'
              '1. Présentation de l’application\n\n'
              'L’application Soneya, éditée par Mohamed Camara, domicilié à Dubreka (Kaléma), République de Guinée, a pour objectif de proposer un ensemble de services numériques destinés à faciliter la vie quotidienne des utilisateurs en Guinée.\n\n'
              'Ces services comprennent notamment :\n\n'
              'la publication et la consultation d’offres d’emploi et de candidatures,\n\n'
              'la mise en relation pour des logements (vente, location, terrains),\n\n'
              'la recherche et la réservation de restaurants, hôtels, prestataires de services,\n\n'
              'la découverte du tourisme et de la culture guinéenne,\n\n'
              'la consultation d’événements, billetterie et annonces locales,\n\n'
              'un système de messagerie, de notifications et de cartes interactives,\n\n'
              'ainsi que tout autre service que l’éditeur pourra ajouter dans les versions futures.\n\n'
              'L’utilisation de l’application Soneya implique l’acceptation pleine et entière des présentes Conditions Générales d’Utilisation.\n\n'
              '2. Objet\n\n'
              'Les présentes CGU ont pour objet de définir les conditions d’accès, de consultation et d’utilisation des services proposés sur Soneya, que ce soit via mobile, tablette ou web.\n\n'
              '3. Accès à l’application\n\n'
              'L’application Soneya est accessible gratuitement à tout utilisateur disposant d’un accès Internet et d’un appareil compatible.\n'
              'Certains services pourront évoluer et devenir payants ou affichant de la publicité dans de futures versions, sans que cela ne remette en cause la validité des présentes CGU.\n\n'
              '4. Inscription et compte utilisateur\n\n'
              'L’accès à certaines fonctionnalités (publication, candidature, messagerie, etc.) nécessite la création d’un compte utilisateur.\n'
              'L’utilisateur s’engage à fournir des informations exactes, complètes et à jour lors de son inscription.\n'
              'Il est seul responsable de la confidentialité de ses identifiants (adresse e-mail, mot de passe) et de l’activité réalisée sous son compte.\n\n'
              '5. Services proposés\n\n'
              'Soneya offre un ensemble de services intégrés :\n\n'
              'Emploi : dépôt et consultation d’offres, candidatures, enregistrement de CV, échanges entre employeurs et candidats.\n\n'
              'Logement : publication et recherche de logements, terrains ou biens immobiliers à travers la Guinée.\n\n'
              'Tourisme & Culture : mise en valeur des sites, monuments, événements culturels et activités locales.\n\n'
              'Restaurants & Hôtels : guide interactif pour découvrir les meilleurs établissements.\n\n'
              'Prestataires & Annonces : vitrine numérique pour artisans, commerçants et indépendants.\n\n'
              'Messagerie et Notifications : communication entre utilisateurs dans le respect des règles de bonne conduite.\n\n'
              'Carte interactive : géolocalisation des services et offres à proximité.\n\n'
              'L’éditeur se réserve le droit d’ajouter, de modifier ou de supprimer tout service sans préavis.\n\n'
              '6. Obligations de l’utilisateur\n\n'
              'L’utilisateur s’engage à :\n\n'
              'utiliser Soneya de manière légale, respectueuse et responsable ;\n\n'
              'ne pas publier de contenu offensant, diffamatoire, discriminatoire, illégal ou contraire à la morale ;\n\n'
              'ne pas usurper l’identité d’autrui ;\n\n'
              'ne pas diffuser de fausses informations ou d’annonces trompeuses ;\n\n'
              'ne pas tenter d’accéder frauduleusement à des données ou à des serveurs.\n\n'
              'En cas de non-respect de ces règles, Mohamed Camara se réserve le droit de suspendre ou supprimer le compte fautif sans préavis.\n\n'
              '7. Responsabilité\n\n'
              'Soneya met tout en œuvre pour garantir la fiabilité et la sécurité de ses services, mais ne saurait être tenue responsable :\n\n'
              'des interruptions temporaires ou définitives du service ;\n\n'
              'des pertes de données ou d’informations publiées par les utilisateurs ;\n\n'
              'des contenus, annonces ou offres publiées par des tiers ;\n\n'
              'ni des dommages directs ou indirects résultant de l’usage de l’application.\n\n'
              'Les utilisateurs restent responsables de leurs interactions et transactions réalisées via la plateforme.\n\n'
              '8. Données personnelles et confidentialité\n\n'
              'Soneya collecte et traite certaines données personnelles nécessaires au bon fonctionnement de ses services :\n\n'
              'informations d’inscription (nom, e-mail, téléphone, photo de profil, CV, etc.) ;\n\n'
              'données de localisation pour certaines fonctionnalités (ex. : “autour de moi”) ;\n\n'
              'contenus publiés (annonces, messages, images, etc.).\n\n'
              'Ces données sont hébergées de manière sécurisée (notamment via Supabase, basé dans l’Union Européenne) et ne sont jamais revendues à des tiers sans consentement.\n\n'
              'L’utilisateur peut à tout moment demander la suppression de ses données via la page de contact de l’application.\n\n'
              '9. Publicité et partenariats\n\n'
              'Des publicités ou contenus sponsorisés pourront être intégrés dans les prochaines versions de l’application.\n'
              'Soneya s’engage à les présenter de manière claire, sans nuire à l’expérience utilisateur.\n\n'
              '10. Propriété intellectuelle\n\n'
              'Tous les éléments de l’application (logo, design, textes, code, images, base de données, etc.) sont la propriété exclusive de Mohamed Camara.\n'
              'Toute reproduction, distribution ou utilisation non autorisée est strictement interdite.\n\n'
              'Les contenus publiés par les utilisateurs restent leur propriété, mais ceux-ci accordent à Soneya une licence gratuite et non exclusive pour les afficher sur la plateforme.\n\n'
              '11. Sécurité et intégrité du réseau\n\n'
              'Soneya met en place des mesures techniques et organisationnelles pour protéger les données et prévenir les intrusions.\n'
              'Toute tentative de piratage, d’ingénierie inverse ou de perturbation du service entraînera des poursuites conformément à la loi guinéenne.\n\n'
              '12. Modération et signalement\n\n'
              'Les utilisateurs peuvent signaler tout contenu inapproprié via le bouton “Signaler” ou la page de contact.\n'
              'L’équipe de Soneya se réserve le droit de supprimer tout contenu non conforme ou de bloquer un utilisateur.\n\n'
              '13. Évolution des CGU\n\n'
              'Les présentes CGU peuvent être modifiées à tout moment afin de s’adapter à l’évolution des services, de la législation ou de la politique interne.\n'
              'La version la plus récente est disponible dans l’application et sur le site officiel de Soneya.\n\n'
              '14. Droit applicable et juridiction compétente\n\n'
              'Les présentes CGU sont régies par le droit guinéen.\n'
              'En cas de litige, les tribunaux compétents seront ceux de la République de Guinée, sauf disposition contraire.\n\n'
              '15. Contact\n\n'
              'Pour toute question, réclamation ou demande relative à l’application ou aux données personnelles :\n\n'
              'Mohamed Camara\n'
              '📍 Dubreka (Kaléma), République de Guinée\n'
              '📧 soneya.signaler@gmail.com\n',
              textAlign: TextAlign.left,
            ),
          ),
        ),
      ),
    );
  }
}
