// lib/wontanara/pages/page_publication_form.dart
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

const _teal = Color(0xFF0E5A51);
const _tealDark = Color(0xFF0B4740);

enum PublicationType { infoLocale, alerte }

class PagePublicationForm extends StatefulWidget {
  const PagePublicationForm({super.key});

  @override
  State<PagePublicationForm> createState() => _PagePublicationFormState();
}

class _PagePublicationFormState extends State<PagePublicationForm> {
  PublicationType _type = PublicationType.infoLocale;

  final _imagePicker = ImagePicker();
  final List<XFile> _photos = [];

  final _titreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _zoneCtrl = TextEditingController();

  @override
  void dispose() {
    _titreCtrl.dispose();
    _descCtrl.dispose();
    _zoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    // on ne permet de sélectionner que le nombre restant jusqu’à 5
    final remaining = 5 - _photos.length;
    if (remaining <= 0) return;

    final files = await _imagePicker.pickMultiImage(
      imageQuality: 80,
    );
    if (files.isEmpty) return;

    setState(() {
      // on limite à 5 au total
      final toAdd = files.take(remaining);
      _photos.addAll(toAdd);
    });
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          'Publier',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      backgroundColor: const Color(0xFFF5F5F7),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------ Carte principale ------
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(color: Colors.black12, width: 0.4),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header avec avatar
                  Row(
                    children: const [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _teal,
                        child: Text(
                          'MC',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Publier une actualité dans mon quartier',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  const _SectionTitle('Type de publication'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _TypeChip(
                          label: 'Infos locales',
                          selected: _type == PublicationType.infoLocale,
                          icon: Icons.info_rounded,
                          onTap: () => setState(
                              () => _type = PublicationType.infoLocale),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TypeChip(
                          label: 'Alerte',
                          selected: _type == PublicationType.alerte,
                          icon: Icons.warning_amber_rounded,
                          onTap: () =>
                              setState(() => _type = PublicationType.alerte),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const _SectionTitle('Contenu'),
                  const SizedBox(height: 8),
                  _Field(
                    label: 'Titre',
                    controller: _titreCtrl,
                  ),
                  const SizedBox(height: 10),
                  _Field(
                    label: 'Description',
                    controller: _descCtrl,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 16),
                  const _SectionTitle('Zone'),
                  const SizedBox(height: 8),
                  _Field(
                    label: 'Région / Préfecture / Quartier',
                    controller: _zoneCtrl,
                  ),
                  const SizedBox(height: 16),

                  const _SectionTitle('Photos (max. 5)'),
                  const SizedBox(height: 8),
                  _buildPhotoPickerRow(),
                ],
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () {
                  // TODO: envoyer la vraie requête Supabase
                  // Tu auras ici : _type, _titreCtrl.text, _descCtrl.text,
                  // _zoneCtrl.text, et la liste _photos (paths).
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Publier dans mon quartier',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------- Bande de sélection photos -----------
  Widget _buildPhotoPickerRow() {
    final children = <Widget>[];

    // photos déjà sélectionnées
    for (int i = 0; i < _photos.length; i++) {
      final file = _photos[i];

      Widget img;
      if (kIsWeb) {
        img = Image.network(
          file.path,
          fit: BoxFit.cover,
        );
      } else {
        img = Image.file(
          File(file.path),
          fit: BoxFit.cover,
        );
      }

      children.add(
        GestureDetector(
          onLongPress: () => _removePhoto(i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: img,
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // bouton "ajouter" si < 5
    if (_photos.length < 5) {
      children.add(
        _PhotoSlot(
          isAddButton: true,
          onTap: _pickPhotos,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: children
            .map(
              (w) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: w,
              ),
            )
            .toList(),
      ),
    );
  }
}

// ====== petits widgets réutilisables ======

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: _tealDark,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final int maxLines;
  final TextEditingController controller;

  const _Field({
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: _teal, width: 1.2),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _teal.withOpacity(.08) : Colors.grey[100],
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? _teal : Colors.grey[300]!,
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? _tealDark : Colors.black87,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? _tealDark : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  final bool hasImage;
  final bool isAddButton;
  final bool small;
  final VoidCallback? onTap;

  const _PhotoSlot({
    this.hasImage = false,
    this.isAddButton = false,
    this.small = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = small ? 56.0 : 72.0;

    Widget child;
    if (isAddButton) {
      child = const Icon(Icons.add_a_photo_rounded, color: _teal);
    } else if (hasImage) {
      child = const Icon(Icons.image_rounded, color: _tealDark);
    } else {
      child = const SizedBox.shrink();
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(child: child),
      ),
    );
  }
}
