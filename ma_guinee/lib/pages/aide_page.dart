// lib/pages/aide_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// ⬇️ Ajuste le chemin si AppRoutes est ailleurs
import '../routes.dart' show AppRoutes;

class AidePage extends StatefulWidget {
  const AidePage({super.key});
  @override
  State<AidePage> createState() => _AidePageState();
}

class _AidePageState extends State<AidePage> {
  // —————————————————— Config (MAJ demandées) ——————————————————
  static const String kSupportEmail   = 'soneya.signaler@gmail.com';
  static const String kAdminEmail     = 'soneya.signaler@gmail.com';

  // Affichage tel (exactement comme demandé) & formats normalisés
  static const String kDisplayPhone   = '00224620452964';
  static const String _waNumber       = '224620452964';   // pour wa.me (sans + ni 00)
  static const String _telE164        = '+224620452964';  // pour tel:

  static const String kCguUrl         = 'https://example.com/cgu';

  final Color cPrimary = const Color(0xFF1663F9);
  final Color cAccent  = const Color(0xFF00B67A);
  final Color cSoftBg  = const Color(0xFFF6F7FB);

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _selectedCategory = 'Tous';

  // ✅ Routes réellement présentes (issues de ton AppRoutes)
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
    AppRoutes.inscriptionResto, AppRoutes.inscriptionHotel, AppRoutes.inscriptionClinique,
    AppRoutes.annonceDetail, AppRoutes.restoDetail, AppRoutes.hotelDetail,
    AppRoutes.editPrestataire, AppRoutes.editHotel, AppRoutes.editResto,
    AppRoutes.editAnnonce, AppRoutes.editClinique,
    // Billetterie
    AppRoutes.billetterie, AppRoutes.myTickets, AppRoutes.scanner,
    // Jobs
    AppRoutes.jobHome, AppRoutes.jobList, AppRoutes.jobDetail,
    AppRoutes.myApplications, AppRoutes.cvMaker,
    AppRoutes.employerOffers, AppRoutes.employerOfferEdit, AppRoutes.employerOfferCandidatures,
    // Nouvel admin
    AppRoutes.adminCenter, AppRoutes.adminManage,
  };

  bool _hasRoute(String? name) => name != null && _availableRoutes.contains(name);

  // —————————————————— FAQ alignée aux routes ——————————————————
  late final List<FAQItem> _allFaqs = [
    // ====== Rubriques de ta capture ======
    FAQItem.cat(
      'Annonces',
      'Publier une annonce',
      'Onglet Annonces → « Publier » (photos, prix GNF, ville, etc.).',
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
      'Parcourez les pros par ville/métier. Pour créer votre fiche : « Devenir prestataire ».',
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
      'Liste ou carte, ouvrez la fiche (menu, avis), contactez le restaurant.',
      routeName: AppRoutes.resto,
      secondaryRouteName: AppRoutes.inscriptionResto,
      secondaryCta: 'Inscrire un resto',
    ),
    FAQItem.cat(
      'Lieux de culte',
      'Localiser un lieu de culte',
      'Sur la carte, filtre « Lieux de culte », touchez un marqueur pour les détails.',
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
      'Ajoutez photos, prix GNF, localisation précise et contact vérifié.',
      routeName: AppRoutes.logementEdit,
      cta: 'Publier un logement',
    ),
    FAQItem.cat(
      'Emplois',
      'Créer mon CV & postuler',
      'Jobs → Mon CV (créer/importer) → ouvrir une offre → « Postuler ». Suivi dans « Mes candidatures ».',
      routeName: AppRoutes.jobHome,
      secondaryRouteName: AppRoutes.myApplications,
      secondaryCta: 'Mes candidatures',
    ),
    FAQItem.cat(
      'Emplois',
      'Publier une offre (employeur)',
      'Créez votre espace employeur et gérez vos offres/candidatures.',
      routeName: AppRoutes.employerOffers, // Gate → DevenirEmployeur si besoin
      cta: 'Espace employeur',
    ),
    FAQItem.cat(
      'Billetterie',
      'Acheter des billets',
      'Choisissez un événement, payez, puis retrouvez le QR code dans « Mes billets ».',
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

    // 👉 Pas de routes dédiées → boutons gris
    FAQItem.cat('Entreprises', 'Annuaire des entreprises',
        'Recherche par nom/secteur/ville.', routeName: '__missing/entreprises', cta: 'Indisponible'),
    FAQItem.cat('Paiements', 'Problème de paiement',
        'Vérifiez la connexion/solde. Si débit sans billet, écrivez à $kSupportEmail avec le reçu.',
        routeName: '__missing/paiements', cta: 'Indisponible'),
    FAQItem.cat('Sécurité', 'Signaler un contenu abusif',
        'Depuis la fiche → « Signaler ». Vous pouvez aussi envoyer captures et lien à $kAdminEmail.',
        routeName: '__missing/securite', cta: 'Indisponible'),
    FAQItem.cat('Support', 'Contacter le support',
        'Appuyez sur “Contacter” ci-dessus pour Appel / WhatsApp / E-mail.'),
  ];

  final List<String> _categories = const [
    'Tous',
    'Annonces', 'Prestataires', 'Services Admin', 'Restaurants', 'Lieux de culte',
    'Divertissement', 'Tourisme', 'Santé', 'Hôtels', 'Entreprises',
    'Logement', 'Emplois', 'Billetterie',
    'Carte', 'Messages', 'Profil', 'Paiements', 'Sécurité', 'Support',
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

  // —————————————————— UI ——————————————————
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
                  const SizedBox(height: 12),
                  _buildQuickActions(), // Contacter / Email / CGU
                  const SizedBox(height: 8),
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
          colors: [cPrimary, const Color(0xFF2A87F9)],
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
                color: Colors.white, fontSize: 20, height: 1.3, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('💬', style: TextStyle(fontSize: 42)),
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
        decoration: InputDecoration(
          hintText: 'Rechercher dans la FAQ…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); },
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

  // ✅ Sous-titre sans parenthèses (image fournie)
  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            title: 'Contacter',
            subtitle: 'Support', // ⬅️ plus de texte entre parenthèses
            icon: Icons.support_agent,
            color: cAccent,
            onTap: _showContactSheet,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionCard(
            title: 'E-mail',
            subtitle: 'Support',
            icon: Icons.email_outlined,
            color: cPrimary,
            onTap: _openSupportEmail,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionCard(
            title: 'CGU',
            subtitle: 'Consulter',
            icon: Icons.description_outlined,
            color: const Color(0xFF4B5563),
            onTap: _openCgu,
          ),
        ),
      ],
    );
  }

  // Section contact (titre “Contact” qui ouvre la feuille)
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
                  const Text('Support & Administration',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.contact_phone),
                title: const Text('Contact'),
                subtitle: const Text('Support'),
                trailing: const Icon(Icons.expand_more),
                onTap: _showContactSheet,
              ),
              const SizedBox(height: 6),
              _ContactRow(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Administration',
                value: kAdminEmail,
                onTap: _openAdminEmail,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // —————————————————— Actions & Nav ——————————————————
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
                width: 48, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8),
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
                onTap: () { Navigator.pop(context); _launchTel(_telE164); },
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('WhatsApp'),
                subtitle: const Text(kDisplayPhone),
                onTap: () { Navigator.pop(context); _openWhatsApp(); },
              ),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Envoyer un e-mail'),
                subtitle: const Text(kSupportEmail),
                onTap: () { Navigator.pop(context); _openSupportEmail(); },
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
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await _openSupportEmail();
    }
  }

  Future<void> _openSupportEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: kSupportEmail,
      query: Uri.encodeFull('subject=Support - Ma Guinée&body=Bonjour,%0D%0A%0D%0A'),
    );
    await launchUrl(uri);
  }

  Future<void> _openAdminEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: kAdminEmail,
      query: Uri.encodeFull('subject=Administration - Ma Guinée&body=Bonjour,%0D%0A%0D%0A'),
    );
    await launchUrl(uri);
  }

  Future<void> _openCgu() async {
    await launchUrl(Uri.parse(kCguUrl), mode: LaunchMode.externalApplication);
  }
}

// —————————————————— Widgets ——————————————————
class _ActionCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({
    required this.title, required this.subtitle, required this.icon,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final VoidCallback onTap;
  const _ContactRow({required this.icon, required this.label, required this.value, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true, contentPadding: EdgeInsets.zero,
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
    final hasSecondary = item.secondaryRouteName != null && item.secondaryRouteName!.isNotEmpty;

    ButtonStyle _btnStyle(bool enabled) => OutlinedButton.styleFrom(
      foregroundColor: enabled ? null : Colors.grey,
      side: BorderSide(color: enabled ? Theme.of(context).colorScheme.primary : Colors.grey.shade300),
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
              width: 8, height: 32,
              decoration: BoxDecoration(color: accent.withOpacity(.9), borderRadius: BorderRadius.circular(6)),
            ),
            title: Text(item.question, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(item.category, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            children: [
              Align(alignment: Alignment.centerLeft, child: Text(item.answer, style: const TextStyle(height: 1.35))),
              if (hasPrimary || hasSecondary) const SizedBox(height: 10),
              if (hasPrimary || hasSecondary)
                Wrap(
                  spacing: 8, runSpacing: 8,
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
  String get answerL   => answer.toLowerCase();

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
    String c, String q, String a, {
    String? routeName, String? cta, String? secondaryRouteName, String? secondaryCta,
  }) => FAQItem(
        category: c, question: q, answer: a,
        routeName: routeName, cta: cta,
        secondaryRouteName: secondaryRouteName, secondaryCta: secondaryCta,
      );
}
