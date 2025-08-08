import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../services/avis_service.dart'; // Assure-toi que le chemin est correct

class DivertissementDetailPage extends StatefulWidget {
  final Map<String, dynamic> lieu;

  const DivertissementDetailPage({super.key, required this.lieu});

  @override
  State<DivertissementDetailPage> createState() => _DivertissementDetailPageState();
}

class _DivertissementDetailPageState extends State<DivertissementDetailPage> {
  int _note = 0;
  double _noteMoyenne = 0;
  final TextEditingController _avisController = TextEditingController();
  int _currentImage = 0;
  List<Map<String, dynamic>> _avisList = [];

  // Galerie
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadAvis();
  }

  @override
  void dispose() {
    _avisController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAvis() async {
    final avis = await AvisService().recupererAvis(
      contexte: 'divertissement',
      cibleId: widget.lieu['id'],
    );
    final notes = avis.map((e) => (e['note'] as num?)?.toInt() ?? 0).toList();

    setState(() {
      _avisList = avis;
      _noteMoyenne = notes.isNotEmpty ? notes.reduce((a, b) => a + b) / notes.length : 0;
    });
  }

  void _callPhone(BuildContext context) async {
    final raw = (widget.lieu['contact'] ?? widget.lieu['telephone'] ?? '').toString();
    final phone = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.isNotEmpty && await canLaunchUrl(Uri.parse('tel:$phone'))) {
      await launchUrl(Uri.parse('tel:$phone'));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Numéro non disponible ou invalide")),
      );
    }
  }

  void _openMap(BuildContext context) {
    final lat = widget.lieu['latitude'];
    final lon = widget.lieu['longitude'];
    if (lat != null && lon != null) {
      launchUrl(Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lon"));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Coordonnées GPS non disponibles")),
      );
    }
  }

  Future<void> _envoyerAvis() async {
    final avis = _avisController.text.trim();
    if (_note == 0 || avis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Merci de noter et écrire un avis.")),
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez vous connecter pour laisser un avis.")),
      );
      return;
    }

    await AvisService().ajouterOuModifierAvis(
      contexte: 'divertissement',
      cibleId: widget.lieu['id'],
      utilisateurId: user.id,
      note: _note,
      commentaire: avis,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Merci pour votre avis !")),
    );

    setState(() {
      _note = 0;
      _avisController.clear();
    });

    _loadAvis();
  }

  List<String> _images(Map<String, dynamic> lieu) {
    if (lieu['images'] is List && (lieu['images'] as List).isNotEmpty) {
      return (lieu['images'] as List).map((e) => e.toString()).toList();
    }
    final p = lieu['photo_url']?.toString() ?? '';
    return p.isNotEmpty ? [p] : [];
  }

  // --------- PLEIN ÉCRAN (PhotoViewGallery) ----------
  void _openFullScreenGallery(List<String> images, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (_) {
        final controller = PageController(initialPage: initialIndex);
        int current = initialIndex;
        return StatefulBuilder(builder: (context, setS) {
          return Stack(
            children: [
              PhotoViewGallery.builder(
                scrollPhysics: const BouncingScrollPhysics(),
                itemCount: images.length,
                pageController: controller,
                builder: (context, index) {
                  return PhotoViewGalleryPageOptions(
                    imageProvider: NetworkImage(images[index]),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 3,
                    heroAttributes: PhotoViewHeroAttributes(tag: 'divert_$index'),
                  );
                },
                onPageChanged: (i) => setS(() => current = i),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
              ),
              // Compteur 1/N
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${current + 1}/${images.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
              // Fermer
              Positioned(
                top: 24,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          );
        });
      },
    );
  }
  // ---------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final lieu = widget.lieu;
    final horaires = (lieu['horaires'] ?? "Non renseigné").toString();
    final images = _images(lieu);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          (lieu['nom'] ?? '').toString(),
          style: const TextStyle(color: Color(0xFF113CFC), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF113CFC)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- Images (carrousel + miniatures + plein écran)
            if (images.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: images.length,
                        onPageChanged: (i) => setState(() => _currentImage = i),
                        itemBuilder: (context, index) => GestureDetector(
                          onTap: () => _openFullScreenGallery(images, index),
                          child: Hero(
                            tag: 'divert_$index',
                            child: Image.network(
                              images[index],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade300,
                                child: const Center(child: Icon(Icons.image_not_supported)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (images.length > 1)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '${_currentImage + 1}/${images.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (images.length > 1)
                SizedBox(
                  height: 68,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final isActive = index == _currentImage;
                      return GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                          );
                          setState(() => _currentImage = index);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isActive ? const Color(0xFF113CFC) : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: Image.network(
                            images[index],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ] else
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  height: 200,
                  color: Colors.grey.shade300,
                  child: const Center(child: Icon(Icons.image_not_supported, size: 60)),
                ),
              ),

            const SizedBox(height: 20),

            // ---------- Infos générales
            Text(
              (lieu['nom'] ?? '').toString(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            if ((lieu['ambiance'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                (lieu['ambiance']).toString(),
                style: const TextStyle(fontSize: 15, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 18),

            Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFFCE1126), size: 21),
                const SizedBox(width: 7),
                Text((lieu['ville'] ?? '').toString(),
                    style: const TextStyle(fontSize: 15, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 18),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.access_time, color: Color(0xFF113CFC)),
                const SizedBox(width: 8),
                Expanded(child: Text(horaires, style: const TextStyle(fontSize: 15))),
              ],
            ),
            const SizedBox(height: 20),

            if (_noteMoyenne > 0)
              Text("⭐ Note moyenne : ${_noteMoyenne.toStringAsFixed(1)} / 5",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

            if (_avisList.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text("Avis des visiteurs :", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._avisList.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text("⭐ ${a['note']} - ${a['commentaire']}", style: const TextStyle(fontSize: 14)),
                  )),
              const SizedBox(height: 18),
            ],

            const Divider(height: 30),

            // ---------- Avis
            const Text("Notez ce lieu :", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(index < _note ? Icons.star : Icons.star_border, color: Colors.amber),
                  onPressed: () => setState(() => _note = index + 1),
                  splashRadius: 21,
                );
              }),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _avisController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Écrivez votre avis ici...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                fillColor: Colors.grey[100],
                filled: true,
              ),
            ),

            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _envoyerAvis,
              icon: const Icon(Icons.send),
              label: const Text("Envoyer l'avis"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 1.5,
              ),
            ),

            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _callPhone(context),
                    icon: const Icon(Icons.phone),
                    label: const Text("Appeler"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCE1126),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openMap(context),
                    icon: const Icon(Icons.map),
                    label: const Text("Voir sur la carte"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF009460),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
