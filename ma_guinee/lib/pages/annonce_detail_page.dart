import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ma_guinee/models/annonce_model.dart';
import 'package:ma_guinee/pages/messages_annonce_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AnnonceDetailPage extends StatefulWidget {
  final AnnonceModel annonce;
  const AnnonceDetailPage({Key? key, required this.annonce}) : super(key: key);

  @override
  State<AnnonceDetailPage> createState() => _AnnonceDetailPageState();
}

class _AnnonceDetailPageState extends State<AnnonceDetailPage> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;
  Map<String, dynamic>? vendeur;
  late Future<List<AnnonceModel>> _futureSimilaires;
  late Future<List<AnnonceModel>> _futureSellerAnnonces;
  final Color bleuMaGuinee = const Color(0xFF1E3FCF);

  @override
  void initState() {
    super.initState();
    _chargerInfosVendeur();
    _futureSimilaires = _fetchAnnoncesSimilaires();
    _futureSellerAnnonces = _fetchSellerAnnonces();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _chargerInfosVendeur() async {
    final data = await Supabase.instance.client
        .from('utilisateurs')
        .select()
        .eq('id', widget.annonce.userId)
        .maybeSingle();
    if (mounted && data is Map<String, dynamic>) {
      setState(() => vendeur = data);
    }
  }

  Future<List<AnnonceModel>> _fetchAnnoncesSimilaires() async {
    final raw = await Supabase.instance.client
        .from('annonces')
        .select()
        // .eq('categorie', widget.annonce.categorie)  <-- retiré
        .eq('ville', widget.annonce.ville)
        .neq('id', widget.annonce.id)
        .limit(5);
    final list = raw is List ? raw : <dynamic>[];
    return list
        .map((e) => AnnonceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AnnonceModel>> _fetchSellerAnnonces() async {
    final raw = await Supabase.instance.client
        .from('annonces')
        .select()
        .eq('user_id', widget.annonce.userId);
    final list = raw is List ? raw : <dynamic>[];
    return list
        .map((e) => AnnonceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _afficherImagePleine(int index) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PhotoViewGallery.builder(
              itemCount: widget.annonce.images.length,
              pageController: PageController(initialPage: index),
              onPageChanged: (i) => setState(() => _currentImageIndex = i),
              builder: (_, i) => PhotoViewGalleryPageOptions(
                imageProvider: NetworkImage(widget.annonce.images[i]),
                heroAttributes: PhotoViewHeroAttributes(tag: i),
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCarousel() {
    final isDesktop = MediaQuery.of(context).size.width > 600;
    return SizedBox(
      height: 250,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.annonce.images.length,
            onPageChanged: (i) => setState(() => _currentImageIndex = i),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _afficherImagePleine(i),
              child: Image.network(
                widget.annonce.images[i],
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
          // Retour
          Positioned(
            top: 40, left: 12,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          // Partage
          Positioned(
            top: 40, right: 60,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () => Share.share(
                  'Regarde cette annonce : ${widget.annonce.titre}',
                ),
              ),
            ),
          ),
          // Favori
          Positioned(
            top: 40, right: 12,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: Icon(
                  widget.annonce.estFavori
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: Colors.white,
                ),
                onPressed: () => setState(
                    () => widget.annonce.estFavori = !widget.annonce.estFavori),
              ),
            ),
          ),
          // Flèche desktop ←
          if (isDesktop && _currentImageIndex > 0)
            Positioned(
              left: 8, top: 0, bottom: 0,
              child: Center(
                child: IconButton(
                  iconSize: 32,
                  color: Colors.white70,
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                ),
              ),
            ),
          // Flèche desktop →
          if (isDesktop && _currentImageIndex < widget.annonce.images.length - 1)
            Positioned(
              right: 8, top: 0, bottom: 0,
              child: Center(
                child: IconButton(
                  iconSize: 32,
                  color: Colors.white70,
                  icon: const Icon(Icons.arrow_forward_ios),
                  onPressed: () => _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                ),
              ),
            ),
          // Compteur 1/6
          Positioned(
            bottom: 12, right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentImageIndex + 1}/${widget.annonce.images.length}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoutonsContact() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _boutonContact(
          icon: Icons.message,
          label: 'Contacter',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MessagesAnnoncePage(
                annonceId: widget.annonce.id,
                annonceTitre: widget.annonce.titre,
                receiverId: widget.annonce.userId,
                senderId: Supabase.instance.client.auth.currentUser!.id,
              ),
            ),
          ),
        ),
        _boutonContact(
          icon: Icons.call,
          label: 'Appeler',
          onPressed: () => launchUrl(Uri.parse("tel:${widget.annonce.telephone}")),
        ),
        _boutonContact(
          icon: FontAwesomeIcons.whatsapp,
          label: 'WhatsApp',
          onPressed: () =>
              launchUrl(Uri.parse("https://wa.me/${widget.annonce.telephone}")),
        ),
      ],
    );
  }

  Widget _boutonContact({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) =>
      ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: bleuMaGuinee,
          foregroundColor: Colors.white,
        ),
        onPressed: onPressed,
      );

  Widget _buildVendeurComplet() {
    return FutureBuilder<List<AnnonceModel>>(
      future: _futureSellerAnnonces,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final autres = snap.data!
            .where((a) => a.id != widget.annonce.id)
            .toList();
        final u = vendeur!;
        final insc = DateTime.tryParse(u['date_inscription'] ?? '');
        final membreDepuis = insc != null
            ? 'Membre depuis ${insc.month}/${insc.year}'
            : '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vendu par',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(u['photo_url'] ?? ''),
              ),
              title: Text("${u['prenom']} ${u['nom']}",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("$membreDepuis • ${autres.length} annonces"),
            ),
            if (autres.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Les autres annonces de ce vendeur',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: autres.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final a = autres[i];
                    return GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => AnnonceDetailPage(annonce: a)),
                      ),
                      child: Container(
                        width: 140,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (a.images.isNotEmpty)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8)),
                                child: Image.network(
                                  a.images.first,
                                  height: 80,
                                  width: 140,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                a.titre,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '${a.prix.toInt()} ${a.devise}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAnnoncesSimilaires() {
    return FutureBuilder<List<AnnonceModel>>(
      future: _futureSimilaires,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Erreur de chargement : ${snap.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        final list = snap.data ?? <AnnonceModel>[];
        if (list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              "Pas d'annonce similaire pour ce produit dans votre ville.",
              textAlign: TextAlign.center,
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // <<< CHANGEMENT ICI
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                "D’autres annonces qui pourraient vous intéresser",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final a = list[i];
                  return GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AnnonceDetailPage(annonce: a)),
                    ),
                    child: Container(
                      width: 160,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (a.images.isNotEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8)),
                              child: Image.network(
                                a.images.first,
                                height: 100,
                                width: 160,
                                fit: BoxFit.cover,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              a.titre,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              "${a.prix.toInt()} ${a.devise}",
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: ListView(
        children: [
          _buildImageCarousel(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.annonce.titre,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  '${widget.annonce.prix.toInt()} ${widget.annonce.devise} • ${widget.annonce.ville}',
                  style:
                      const TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                Text(widget.annonce.description),
                const SizedBox(height: 16),
                _buildBoutonsContact(),
                const SizedBox(height: 24),
                _buildVendeurComplet(),
                const SizedBox(height: 24),
                _buildAnnoncesSimilaires(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
