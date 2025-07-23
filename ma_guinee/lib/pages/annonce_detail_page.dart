import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/annonce_model.dart';
import '../providers/favoris_provider.dart';
import 'messages_annonce_page.dart';

class AnnonceDetailPage extends StatefulWidget {
  final AnnonceModel annonce;
  const AnnonceDetailPage({super.key, required this.annonce});

  @override
  State<AnnonceDetailPage> createState() => _AnnonceDetailPageState();
}

class _AnnonceDetailPageState extends State<AnnonceDetailPage> {
  int _currentImage = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final annonce = widget.annonce;
    final favorisProvider = context.watch<FavorisProvider>();
    final hasTel = annonce.telephone.isNotEmpty;
    final isFavori = favorisProvider.estFavori(annonce.id);
    final images = annonce.images;

    Future<void> _toggleFavori() async {
      await favorisProvider.toggleFavori(annonce.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            favorisProvider.estFavori(annonce.id)
                ? "Ajouté aux favoris !"
                : "Retiré des favoris.",
          ),
          duration: const Duration(milliseconds: 1000),
        ),
      );
    }

    Future<void> _call(String numero) async {
      final uri = Uri.parse('tel:$numero');
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }

    Future<void> _whatsapp(String numero) async {
      final cleanNumber = numero.replaceAll(RegExp(r'[^0-9+]'), '');
      final uri = Uri.parse('https://wa.me/$cleanNumber');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    void _shareAnnonce() {
      final a = annonce;
      final message = '''
📢 ${a.titre}

${a.description}

📍 Ville : ${a.ville}
📂 Catégorie : ${a.categorie}
📞 Téléphone : ${a.telephone}

Partagé depuis l'app Ma Guinée 🇬🇳
''';
      Share.share(message);
    }

    void _ouvrirMessagerie() {
      final a = annonce;
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Veuillez vous connecter pour échanger.")),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MessagesAnnoncePage(
            annonceId: a.id,
            receiverId: a.userId,
            senderId: currentUser.id,
            annonceTitre: a.titre,
          ),
        ),
      );
    }

    final double carouselHeight = MediaQuery.of(context).size.width * 0.65;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF113CFC)),
        title: const Text(
          "Détail de l'annonce",
          style: TextStyle(
            color: Color(0xFF113CFC),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Bannière
          Container(
            width: double.infinity,
            height: 94,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
              gradient: LinearGradient(
                colors: [Color(0xFFCE1126), Color(0xFFFCD116)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Stack(
              children: [
                const Positioned(
                  top: 17,
                  left: 18,
                  child: Text(
                    "Ma Guinée",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Positioned(
                  top: 48,
                  left: 18,
                  child: Text(
                    "Toutes les annonces, partout.",
                    style: TextStyle(fontSize: 15, color: Colors.white),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 7,
                  child: Image.asset(
                    'assets/guinee_map.png',
                    height: 68,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),

          // Carousel
          Padding(
            padding: const EdgeInsets.only(left: 18, right: 18, top: 16, bottom: 4),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: images.isNotEmpty
                      ? SizedBox(
                          height: carouselHeight,
                          width: double.infinity,
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: images.length,
                            onPageChanged: (index) =>
                                setState(() => _currentImage = index),
                            itemBuilder: (_, index) => Image.network(
                              images[index],
                              fit: BoxFit.contain,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.image_not_supported, size: 60),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          height: 210,
                          width: double.infinity,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported, size: 60),
                        ),
                ),

                if (images.length > 1)
                  Positioned(
                    bottom: 13,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        images.length,
                        (index) => GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeInOut,
                            );
                            setState(() => _currentImage = index);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentImage == index ? 19 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentImage == index
                                  ? const Color(0xFF113CFC)
                                  : Colors.white.withOpacity(0.77),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: const Color(0xFF113CFC), width: 1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                Positioned(
                  bottom: 14,
                  right: 14,
                  child: GestureDetector(
                    onTap: _toggleFavori,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3)],
                      ),
                      child: Icon(
                        isFavori ? Icons.favorite : Icons.favorite_border,
                        color: isFavori ? Colors.red : Colors.grey.shade600,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Infos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  annonce.titre,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  annonce.description,
                  style: const TextStyle(fontSize: 15.5, color: Colors.black87),
                ),
                const SizedBox(height: 20),

                if (annonce.prix > 0)
                  Row(
                    children: [
                      const Icon(Icons.attach_money, color: Color(0xFF113CFC)),
                      const SizedBox(width: 8),
                      Text(
                        "Prix : ${annonce.prix.toStringAsFixed(0)} ${annonce.devise.isNotEmpty ? annonce.devise : "GNF"}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF113CFC),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                if (annonce.prix > 0) const SizedBox(height: 10),

                Row(
                  children: [
                    const Icon(Icons.category, color: Color(0xFFFCD116)),
                    const SizedBox(width: 8),
                    Text("Catégorie : ${annonce.categorie}"),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF009460)),
                    const SizedBox(width: 8),
                    Text("Ville : ${annonce.ville}"),
                  ],
                ),
                const SizedBox(height: 22),

                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.phone, color: Color(0xFF009460)),
                      tooltip: "Appeler",
                      onPressed: hasTel ? () => _call(annonce.telephone) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.message, color: Color(0xFF25D366)),
                      tooltip: "WhatsApp",
                      onPressed: hasTel ? () => _whatsapp(annonce.telephone) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline, size: 20),
                        label: const Text("Échanger"),
                        onPressed: _ouvrirMessagerie,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF113CFC),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                Center(
                  child: ElevatedButton.icon(
                    onPressed: _shareAnnonce,
                    icon: const Icon(Icons.share),
                    label: const Text("Partager l’annonce"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCE1126),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
