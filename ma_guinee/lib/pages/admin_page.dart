import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// ============================
/// THEME (couleurs de l’app)
/// ============================
const kBlue  = Color(0xFF113CFC);
const kGreen = Color(0xFF009460);
const kRed   = Color(0xFFCE1126);

/// ============================
/// Modèle de données Démarche
/// ============================
class Demarche {
  final String code;                 // ex: 'cni'
  final String titre;                // ex: CNI biométrique
  final String resume;               // court texte liste
  final IconData icone;
  final List<String> documents;      // pièces à fournir
  final List<String> etapes;         // étapes
  final String? cout;                // coût indicatif
  final String? delai;               // délai indicatif
  final String? lieux;               // où s’adresser
  final String? remarques;           // notes
  final List<Map<String, String>> liens; // [{label,url}] — officiels uniquement

  /// --- Zone “Explainer” (vidéo/animation) ---
  /// mediaType: 'video' | 'lottie' | 'image' | null
  final String? mediaType;
  final String? mediaUrl;
  final String? mediaCaption;

  const Demarche({
    required this.code,
    required this.titre,
    required this.resume,
    required this.icone,
    required this.documents,
    required this.etapes,
    this.cout,
    this.delai,
    this.lieux,
    this.remarques,
    this.liens = const [],
    this.mediaType,
    this.mediaUrl,
    this.mediaCaption,
  });
}

/// =====================================
/// Données intégrées (liens GUINÉE only)
/// =====================================
final List<Demarche> kDemarches = [
  Demarche(
    code: 'cni',
    titre: "Carte Nationale d'Identité biométrique",
    resume: "Pièces, lieux d’enrôlement et délai indicatif.",
    icone: Icons.badge,
    documents: [
      "Extrait d’acte de naissance",
      "Certificat de résidence",
      "2 photos d’identité (fond clair)",
      "Ancienne CNI (si renouvellement)",
      "Reçu de paiement si non éligible à la gratuité",
    ],
    etapes: [
      "Constituer le dossier (voir pièces).",
      "Se présenter au centre d’enrôlement (Commissariat/centre dédié).",
      "Enrôlement biométrique (photo, empreintes, signature).",
      "Retrait de la carte à la date indiquée.",
    ],
    cout: "1ère demande souvent annoncée gratuite (vérifier sur place).",
    delai: "En pratique souvent ≈ 3 jours ouvrables (variable).",
    lieux:
        "Commissariats/centres d’enrôlement (Ministère de la Sécurité et de la Protection Civile).",
    remarques:
        "Les disponibilités des kits peuvent varier. Se renseigner localement avant déplacement.",
    liens: [
      {
        "label": "Portail Service Public Guinée",
        "url": "https://service-public.gov.gn",
      },
    ],
    // Explainer placeholder
    mediaType: null, // 'video' | 'lottie' plus tard
    mediaUrl: null,  // ex: 'https://.../cni_explainer.mp4'
    mediaCaption: "Comprendre l’enrôlement CNI pas à pas",
  ),

  Demarche(
    code: 'passeport',
    titre: "Passeport biométrique",
    resume: "Documents requis, dépôt et retrait.",
    icone: Icons.travel_explore,
    documents: [
      "Extrait de naissance",
      "2 photos d’identité récentes",
      "Certificat de résidence",
      "Formulaire de demande",
      "Reçu de paiement des frais",
      "Ancien passeport (renouvellement)",
    ],
    etapes: [
      "Préparer les pièces et payer les frais (Trésor/banque indiquée).",
      "Déposer le dossier au MSPC (en Guinée).",
      "Enrôlement biométrique le jour du dépôt.",
      "Retirer le passeport une fois prêt.",
    ],
    cout: "Selon barème en vigueur (à confirmer au guichet).",
    delai: "Variable selon période et affluence.",
    lieux:
        "Ministère de la Sécurité et de la Protection Civile – Conakry et directions intérieures.",
    liens: [
      {
        "label": "Portail Service Public Guinée",
        "url": "https://service-public.gov.gn",
      },
    ],
    mediaType: null,
    mediaUrl: null,
    mediaCaption: "Tutoriel dépôt de dossier passeport",
  ),

  Demarche(
    code: 'naissance',
    titre: "Acte de naissance (sécurisé)",
    resume: "Montant indicatif, circuit et point de dépôt.",
    icone: Icons.cake,
    documents: [
      "Ancien extrait d’acte de naissance (si existant)",
      "Pièce d’identité du demandeur/parent",
      "Reçu de paiement (si requis)",
    ],
    etapes: [
      "Effectuer le paiement demandé par la mairie/centre habilité.",
      "Présenter le reçu et les pièces au guichet.",
      "Retirer l’acte sécurisé à la date indiquée.",
    ],
    cout: "Montant fixé localement (se renseigner au guichet).",
    delai: "Variable selon la commune/centre.",
    lieux: "Mairie/centre d’état civil ou commissariat indiqué.",
    liens: [
      {
        "label": "Portail Service Public Guinée",
        "url": "https://service-public.gov.gn",
      },
    ],
    mediaType: null,
    mediaUrl: null,
    mediaCaption: "Explication des mentions de l’acte",
  ),

  Demarche(
    code: 'casier',
    titre: "Casier judiciaire (bulletin sécurisé)",
    resume: "Pièces, tribunal compétent et délai.",
    icone: Icons.gavel,
    documents: [
      "Demande adressée au Greffe du tribunal du lieu de naissance",
      "Extrait d’acte de naissance",
      "Certificat de résidence",
      "Copie CNI ou Passeport",
      "2 photos d’identité (souvent demandées)",
    ],
    etapes: [
      "Déposer la demande et les pièces au Greffe du tribunal compétent.",
      "Retirer le bulletin à la date indiquée.",
    ],
    cout: "Selon barème du tribunal.",
    delai: "Quelques jours en moyenne (variable).",
    lieux: "Greffe du tribunal du lieu de naissance (ex. Cour d’Appel de Conakry – Kaloum).",
    liens: [
      {
        "label": "Ministère de la Justice (via Service Public GN)",
        "url": "https://service-public.gov.gn",
      },
    ],
    mediaType: null,
    mediaUrl: null,
    mediaCaption: "À quoi sert le casier judiciaire ?",
  ),

  Demarche(
    code: 'permis',
    titre: "Permis de conduire biométrique",
    resume: "Conditions, examen et délivrance.",
    icone: Icons.directions_car,
    documents: [
      "Pièce d’identité (CNI ou Passeport)",
      "Certificat d’aptitude médicale (selon catégorie)",
      "Photos d’identité",
      "Reçus de paiement (examen/délivrance)",
    ],
    etapes: [
      "Inscription à l’examen (catégorie visée).",
      "Réussite à l’examen théorique et pratique.",
      "Dépôt du dossier + enrôlement biométrique.",
      "Retrait du permis.",
    ],
    cout: "Selon catégorie et barème en vigueur.",
    delai: "Après réussite à l’examen (variable).",
    lieux: "Ministère des Transports / Directions préfectorales / centres agréés.",
    liens: [
      {
        "label": "Ministère des Transports (via Service Public GN)",
        "url": "https://service-public.gov.gn",
      },
    ],
    mediaType: null,
    mediaUrl: null,
    mediaCaption: "Règles de conduite et catégories",
  ),
];

/// ============================
/// Page Liste + Recherche
/// ============================
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final TextEditingController _search = TextEditingController();
  List<Demarche> _filtered = List.of(kDemarches);

  void _applyFilter(String q) {
    final query = q.toLowerCase().trim();
    setState(() {
      _filtered = kDemarches.where((d) {
        return d.titre.toLowerCase().contains(query) ||
            d.resume.toLowerCase().contains(query) ||
            d.documents.join(' ').toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Services administratifs',
          style: TextStyle(color: kBlue, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1.2,
        iconTheme: const IconThemeData(color: kBlue),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              onChanged: _applyFilter,
              decoration: InputDecoration(
                hintText: 'Rechercher un service…',
                prefixIcon: const Icon(Icons.search, color: kBlue),
                filled: true,
                fillColor: const Color(0xFFF8F6F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filtered.length,
              itemBuilder: (context, i) {
                final d = _filtered[i];
                return Card(
                  color: Colors.indigo.shade50.withOpacity(0.12),
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: kRed,
                      child: Icon(d.icone, color: Colors.white),
                    ),
                    title: Text(
                      d.titre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    subtitle: Text(d.resume, style: const TextStyle(fontSize: 13)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: kRed),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DemarcheDetailPage(demarche: d)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================
/// Détail d’une démarche
/// ============================
class DemarcheDetailPage extends StatelessWidget {
  final Demarche demarche;
  const DemarcheDetailPage({super.key, required this.demarche});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          demarche.titre,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: kBlue, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: kBlue),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: "Résumé",
            child: Text(demarche.resume, style: const TextStyle(fontSize: 15)),
          ),

          // --------- SECTION EXPLAINER (vidéo/animation) ---------
          _ExplainerSection(demarche: demarche),

          _SectionCard(
            title: "Documents requis",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: demarche.documents.map((e) => _Bullet(text: e)).toList(),
            ),
          ),
          if (demarche.etapes.isNotEmpty)
            _SectionCard(
              title: "Étapes",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: demarche.etapes
                    .asMap()
                    .entries
                    .map((e) => _StepItem(index: e.key + 1, text: e.value))
                    .toList(),
              ),
            ),
          if (demarche.cout != null)
            _InfoTile(icon: Icons.payments, label: "Coût", value: demarche.cout!),
          if (demarche.delai != null)
            _InfoTile(icon: Icons.schedule, label: "Délai", value: demarche.delai!),
          if (demarche.lieux != null)
            _InfoTile(icon: Icons.location_on, label: "Où s’adresser ?", value: demarche.lieux!),
          if (demarche.remarques != null)
            _SectionCard(
              title: "Remarques",
              child: Text(demarche.remarques!, style: const TextStyle(fontSize: 15)),
            ),
          if (demarche.liens.isNotEmpty)
            _SectionCard(
              title: "Liens officiels",
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: demarche.liens.map((l) {
                  return ActionChip(
                    label: Text(l['label']!, style: const TextStyle(color: Colors.white)),
                    backgroundColor: kBlue,
                    onPressed: () async {
                      final uri = Uri.parse(l['url']!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// ============================
/// Widgets UI réutilisables
/// ============================
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.indigo.shade50.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: kBlue, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: kGreen),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final int index;
  final String text;
  const _StepItem({required this.index, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: kBlue, width: 1),
            ),
            child: Text('$index',
                style: const TextStyle(color: kBlue, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.indigo.shade50.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: kGreen, child: Icon(icon, color: Colors.white)),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: kBlue)),
        subtitle: Text(value, style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}

/// ============================
/// SECTION EXPLAINER (vidéo)
/// ============================
/// - Aujourd’hui : placeholder propre avec bouton “Regarder”
/// - Plus tard :
///   * intégrer `video_player`/`chewie` ou `lottie` selon mediaType
///   * ou ouvrir un lien externe (YouTube/Drive) via `mediaUrl`
class _ExplainerSection extends StatelessWidget {
  final Demarche demarche;
  const _ExplainerSection({required this.demarche});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: "Explication en vidéo",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // Placeholder visuel — remplace par un player plus tard
                Positioned.fill(
                  child: Center(
                    child: Icon(
                      demarche.mediaType == 'lottie'
                          ? Icons.animation
                          : Icons.play_circle_fill_rounded,
                      size: 64,
                      color: Colors.black.withOpacity(0.35),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      demarche.mediaCaption ?? "Tutoriel à venir",
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.ondemand_video),
              label: Text(
                demarche.mediaUrl == null ? "Bientôt disponible" : "Regarder",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: demarche.mediaUrl == null
                  ? null
                  : () async {
                      final url = Uri.parse(demarche.mediaUrl!);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Astuce : on pourra intégrer un lecteur natif (video_player/chewie) ou une animation Lottie ici.",
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
