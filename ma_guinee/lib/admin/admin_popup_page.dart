import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminPopupPage extends StatelessWidget {
  final String title;
  final String body;
  final String? url;

  const AdminPopupPage({
    super.key,
    required this.title,
    required this.body,
    this.url,
  });

  Future<void> _openUrl(BuildContext context) async {
    if (url == null || url!.trim().isEmpty) return;

    final uri = Uri.tryParse(url!.trim());
    if (uri == null) {
      _showSnack(context, 'Lien invalide.');
      return;
    }

    if (!await canLaunchUrl(uri)) {
      _showSnack(context, "Impossible d’ouvrir le lien.");
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      // fond semi-transparent
      backgroundColor: Colors.black.withOpacity(0.40),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 420,
              minWidth: 280,
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1.0),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: Material(
                elevation: 12,
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // HEADER dégradé
                    Container(
                      padding: const EdgeInsets.fromLTRB(
                          20, 18, 4 /* pour le close */, 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            cs.primary,
                            cs.primary.withOpacity(0.85),
                          ],
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_active_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Notification admin',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Fermer',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // CORPS
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Text(
                        body,
                        textAlign: TextAlign.left,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withOpacity(0.95),
                          height: 1.4,
                        ),
                      ),
                    ),

                    if (url != null && url!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: ElevatedButton.icon(
                          onPressed: () => _openUrl(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('Ouvrir le lien'),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      child: Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Fermer'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
