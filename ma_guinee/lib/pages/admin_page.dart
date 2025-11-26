import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ================== Palette Guinée ==================
const kGNFRed = Color(0xFFCE1126);
const kGNFYellow = Color(0xFFFCD116);
const kGNFGreen = Color(0xFF009460);
const kInk = Color(0xFF0B1220);
const kBg = Color(0xFFF7F8FA);

// ================== Modèles ==================
class Demarche {
  final String code, titre, resume;
  final IconData icone;
  final List<String> documents, etapes;
  final String? cout, delai, lieux, remarques;
  final List<Map<String, String>> liens;
  final String? mediaType, mediaUrl, mediaCaption;
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

// ================== Données (photos Conakry) ==================
// Remplace ces URLs par tes propres images (ex: Supabase public URLs)
final List<String> kConakryPhotos = [
  "https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/admin-demarches/Valide1.png",
  "https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/admin-demarches/Valide4.png",
  "https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/admin-demarches/Valide3.png",
  "https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/admin-demarches/Valide2.png",
  "https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/admin-demarches/Valide.png",
  "https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/admin-demarches/Valide5.png",
  "https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/admin-demarches/Valide9.png",
];

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
      "Se présenter au centre d’enrôlement.",
      "Enrôlement biométrique (photo, empreintes, signature).",
      "Retrait de la carte à la date indiquée.",
    ],
    cout: "1ère demande parfois gratuite (à vérifier au guichet).",
    delai: "≈ 3 jours ouvrables (variable).",
    lieux: "Commissariats / centres d’enrôlement (MSPC).",
    liens: [
      {"label": "Service Public GN", "url": "https://service-public.gov.gn"},
    ],
    mediaType: 'video',
    mediaUrl: null,
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
      "Préparer les pièces et payer les frais.",
      "Déposer le dossier au MSPC.",
      "Enrôlement biométrique le jour du dépôt.",
      "Retirer le passeport une fois prêt.",
    ],
    cout: "Selon barème en vigueur.",
    delai: "Variable selon période et affluence.",
    lieux: "MSPC – Conakry et directions intérieures.",
    liens: [
      {"label": "Service Public GN", "url": "https://service-public.gov.gn"},
    ],
  ),
  Demarche(
    code: 'naissance',
    titre: "Acte de naissance (sécurisé)",
    resume: "Montant indicatif, circuit et point de dépôt.",
    icone: Icons.cake,
    documents: [
      "Ancien extrait (si existant)",
      "Pièce d’identité du demandeur/parent",
      "Reçu de paiement (si requis)",
    ],
    etapes: [
      "Effectuer le paiement demandé.",
      "Présenter le reçu et les pièces au guichet.",
      "Retirer l’acte sécurisé à la date indiquée.",
    ],
    cout: "Montant fixé localement.",
    delai: "Variable selon la commune/centre.",
    lieux: "Mairie / centre d’état civil ou commissariat.",
    liens: [
      {"label": "Service Public GN", "url": "https://service-public.gov.gn"},
    ],
  ),
  Demarche(
    code: 'casier',
    titre: "Casier judiciaire (bulletin sécurisé)",
    resume: "Pièces, tribunal compétent et délai.",
    icone: Icons.gavel,
    documents: [
      "Demande au Greffe du tribunal du lieu de naissance",
      "Extrait d’acte de naissance",
      "Certificat de résidence",
      "Copie CNI ou Passeport",
      "2 photos d’identité",
    ],
    etapes: [
      "Déposer la demande et les pièces au Greffe.",
      "Retirer le bulletin à la date indiquée.",
    ],
    cout: "Selon barème du tribunal.",
    delai: "Quelques jours (variable).",
    lieux: "Greffe du tribunal du lieu de naissance.",
    liens: [
      {"label": "Service Public GN", "url": "https://service-public.gov.gn"},
    ],
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
    cout: "Selon catégorie et barème.",
    delai: "Après réussite à l’examen (variable).",
    lieux: "Ministère des Transports / Directions / centres agréés.",
    liens: [
      {"label": "Service Public GN", "url": "https://service-public.gov.gn"},
    ],
  ),
];

// ================== Page Liste ==================
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final TextEditingController _search = TextEditingController();
  List<Demarche> _filtered = List.of(kDemarches);

  /// Retire les accents/ligatures FR les plus courants pour une recherche tolérante.
  String _normalize(String s) {
    final lower = s.trim().toLowerCase();
    const map = {
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'á': 'a',
      'ã': 'a',
      'ç': 'c',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'ì': 'i',
      'í': 'i',
      'ô': 'o',
      'ö': 'o',
      'ò': 'o',
      'ó': 'o',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ú': 'u',
      'œ': 'oe',
    };
    final b = StringBuffer();
    for (final r in lower.runes) {
      final ch = String.fromCharCode(r);
      b.write(map[ch] ?? ch);
    }
    return b.toString();
  }

  void _applyFilter(String q) {
    final query = _normalize(q);
    setState(() {
      _filtered = kDemarches.where((d) {
        final hay = [
          d.titre,
          d.resume,
          d.documents.join(' '),
          d.etapes.join(' ')
        ].map(_normalize).join(' ');
        return hay.contains(query);
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
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.8,
        title: const Text(
          'Services administratifs',
          style: TextStyle(color: kInk, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: kInk),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kGNFGreen, kGNFYellow, kGNFRed],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SearchField(controller: _search, onChanged: _applyFilter),
          ),
          const SizedBox(height: 12),
          const _ConakryBanner(),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _filtered.length,
              itemBuilder: (_, i) => _DemarcheTileGuinea(d: _filtered[i]),
            ),
          ),
        ],
      ),
    );
  }
}

// ================== Page Détail ==================
class DemarcheDetailPage extends StatelessWidget {
  final Demarche demarche;
  const DemarcheDetailPage({super.key, required this.demarche});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.8,
        title: Text(
          demarche.titre,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: kInk, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: kInk),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient:
                  LinearGradient(colors: [kGNFGreen, kGNFYellow, kGNFRed]),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: "Résumé",
            child: Text(demarche.resume, style: _ts(15, FontWeight.w500)),
          ),
          _ExplainerSection(demarche: demarche),
          _SectionCard(
            title: "Documents requis",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  demarche.documents.map((e) => _Bullet(text: e)).toList(),
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
            _InfoTile(
                icon: Icons.payments, label: "Coût", value: demarche.cout!),
          if (demarche.delai != null)
            _InfoTile(
                icon: Icons.schedule, label: "Délai", value: demarche.delai!),
          if (demarche.lieux != null)
            _InfoTile(
                icon: Icons.location_on,
                label: "Où s’adresser ?",
                value: demarche.lieux!),
          if (demarche.remarques != null)
            _SectionCard(
              title: "Remarques",
              child: Text(demarche.remarques!, style: _ts(15, FontWeight.w500)),
            ),
          if (demarche.liens.isNotEmpty)
            _SectionCard(
              title: "Liens officiels",
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: demarche.liens.map((l) {
                  return ActionChip(
                    label: Text(l['label']!,
                        style: const TextStyle(color: Colors.white)),
                    backgroundColor: kGNFGreen,
                    onPressed: () async {
                      final uri = Uri.parse(l['url']!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
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

// ================== Widgets ==================
TextStyle _ts(double size, FontWeight w, {Color c = kInk}) =>
    TextStyle(fontSize: size, fontWeight: w, color: c);

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.controller, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Rechercher un service…',
        prefixIcon: const Icon(Icons.search, color: kInk),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withOpacity(.06)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withOpacity(.06)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: kGNFGreen, width: 1.2),
        ),
      ),
    );
  }
}

// -------- Bannière défilante Conakry --------
class _ConakryBanner extends StatefulWidget {
  const _ConakryBanner();
  @override
  State<_ConakryBanner> createState() => _ConakryBannerState();
}

class _ConakryBannerState extends State<_ConakryBanner> {
  final _ctrl = PageController(viewportFraction: 0.92);
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || kConakryPhotos.isEmpty) return;
      _index = (_index + 1) % kConakryPhotos.length;
      _ctrl.animateToPage(
        _index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kConakryPhotos.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 160,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _ctrl,
              itemCount: kConakryPhotos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final url = kConakryPhotos[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: Colors.black12),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.black12,
                            alignment: Alignment.center,
                            child: const Icon(Icons.image_not_supported,
                                color: Colors.black45),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(.25),
                                Colors.black.withOpacity(.05)
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            height: 4,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [kGNFGreen, kGNFYellow, kGNFRed],
                              ),
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 12,
                          bottom: 12,
                          child: Text(
                            "Conakry",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              shadows: [
                                Shadow(blurRadius: 8, color: Colors.black54)
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(kConakryPhotos.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: active ? 18 : 6,
                decoration: BoxDecoration(
                  color: active ? kGNFRed : Colors.black26,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// --------- Tile Guinea style ---------
class _DemarcheTileGuinea extends StatelessWidget {
  final Demarche d;
  const _DemarcheTileGuinea({required this.d});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x11000000), blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DemarcheDetailPage(demarche: d)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              left: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 8,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [kGNFGreen, kGNFYellow, kGNFRed],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
              leading: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [kGNFRed, Color(0xFFAA0E1E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x22CE1126),
                        blurRadius: 10,
                        offset: Offset(0, 6))
                  ],
                ),
                child: Icon(d.icone, color: Colors.white),
              ),
              title: Text(
                d.titre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: kInk),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  d.resume,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: kInk.withOpacity(.7)),
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kGNFRed.withOpacity(.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.arrow_forward_ios,
                    size: 16, color: kGNFRed),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------- Cartes & détails ---------
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: kGNFGreen)),
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
            child: Icon(Icons.circle, size: 6, color: kGNFGreen),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500, color: kInk)),
          ),
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
              color: kGNFYellow.withOpacity(0.15),
              borderRadius: BorderRadius.circular(11),
              border: const Border.fromBorderSide(
                  BorderSide(color: kGNFYellow, width: 1)),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: kGNFYellow),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500, color: kInk)),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoTile(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor: kGNFGreen, child: Icon(icon, color: Colors.white)),
        title: Text(label,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: kGNFGreen)),
        subtitle: Text(value,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w500, color: kInk)),
      ),
    );
  }
}

class _ExplainerSection extends StatelessWidget {
  final Demarche demarche;
  const _ExplainerSection({required this.demarche});
  @override
  Widget build(BuildContext context) {
    if (demarche.mediaType == null && demarche.mediaUrl == null) {
      return const SizedBox.shrink();
    }
    return _SectionCard(
      title: "Explication en vidéo",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
                color: kInk.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16)),
            child: Center(
              child: Icon(
                demarche.mediaType == 'lottie'
                    ? Icons.animation
                    : Icons.play_circle_fill_rounded,
                size: 64,
                color: kInk.withOpacity(0.35),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.ondemand_video),
              label: Text(demarche.mediaUrl == null
                  ? "Bientôt disponible"
                  : "Regarder"),
              style: ElevatedButton.styleFrom(
                backgroundColor: kGNFRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: demarche.mediaUrl == null
                  ? null
                  : () async {
                      final url = Uri.parse(demarche.mediaUrl!);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url,
                            mode: LaunchMode.externalApplication);
                      }
                    },
            ),
          ),
          if (demarche.mediaCaption != null) ...[
            const SizedBox(height: 6),
            Text(
              demarche.mediaCaption!,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kInk.withOpacity(.7)),
            ),
          ],
        ],
      ),
    );
  }
}
