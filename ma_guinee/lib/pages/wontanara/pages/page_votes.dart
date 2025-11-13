// lib/pages/wontanara/pages/page_votes.dart

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api_wontanara.dart';
import '../models.dart';
import '../constantes.dart';
import '../theme_wontanara.dart';
import 'page_chat.dart'; // 👈 chat de quartier / éphémère

class PageVotes extends StatefulWidget {
  const PageVotes({super.key});

  @override
  State<PageVotes> createState() => _PageVotesState();
}

class _PageVotesState extends State<PageVotes> {
  List<VoteItem> _votes = [];

  bool _loading = true;
  String? _error;
  bool _creating = false;

  // rôle courant (pour savoir si on peut créer un vote)
  bool _canCreateVote = false;

  // --- contrôleurs pour création de vote (via bottom sheet) ---
  final TextEditingController _titre = TextEditingController();
  final TextEditingController _desc = TextEditingController();
  final TextEditingController _opt1 = TextEditingController(text: 'Oui');
  final TextEditingController _opt2 = TextEditingController(text: 'Non');

  @override
  void initState() {
    super.initState();
    _syncRoleFromMeta();
    _load();
  }

  @override
  void dispose() {
    _titre.dispose();
    _desc.dispose();
    _opt1.dispose();
    _opt2.dispose();
    super.dispose();
  }

  void _syncRoleFromMeta() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final meta = user.userMetadata ?? {};
    final roleMeta = (meta['role'] as String?)?.trim() ?? 'Citoyen';
    final lower = roleMeta.toLowerCase();

    // 👉 Seuls les rôles autres que "citoyen" peuvent créer
    _canCreateVote = !(lower == 'citoyen' || lower == 'citizen');
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiVotes.lister(ZONE_ID_DEMO);
      if (!mounted) return;
      setState(() {
        _votes = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Impossible de charger les votes.";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur chargement votes : $e")),
      );
    }
  }

  Future<void> _creerVote({required bool isSondage}) async {
    if (_creating) return;

    final titre = _titre.text.trim();
    final desc = _desc.text.trim();
    final opt1 = _opt1.text.trim();
    final opt2 = _opt2.text.trim();

    if (titre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Le titre est obligatoire.")),
      );
      return;
    }
    if (!isSondage && (opt1.isEmpty || opt2.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Les deux options doivent être renseignées."),
        ),
      );
      return;
    }

    setState(() => _creating = true);

    try {
      // Pour l’instant, le backend ne distingue pas vote/sondage.
      // On peut éventuellement préfixer la description.
      final descFinal = isSondage ? '[SONDAGE] $desc' : desc;

      final id = await ApiVotes.creerVote(ZONE_ID_DEMO, titre, descFinal);

      if (!isSondage) {
        await ApiVotes.ajouterOption(id, opt1.isEmpty ? 'Oui' : opt1, 1);
        await ApiVotes.ajouterOption(id, opt2.isEmpty ? 'Non' : opt2, 2);
      }

      if (!mounted) return;

      _titre.clear();
      _desc.clear();
      _opt1.text = 'Oui';
      _opt2.text = 'Non';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSondage ? "Sondage créé ✅" : "Vote créé ✅"),
        ),
      );

      await _load();
      if (mounted) Navigator.of(context).pop(); // fermer le bottom sheet
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur création : $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _ouvrirVote(VoteItem v) async {
    try {
      final opts = await ApiVotes.options(v.id);
      if (!mounted) return;

      final hasOptions = opts.isNotEmpty;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.titre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(v.description ?? '—'),
                    const SizedBox(height: 12),
                    if (hasOptions) ...[
                      const Divider(),
                      const Text(
                        'Choisissez une réponse :',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      ...opts.map(
                        (o) => ListTile(
                          title: Text(o.libelle),
                          trailing: const Icon(Icons.how_to_vote),
                          onTap: () async {
                            try {
                              await ApiVotes.voter(v.id, o.id);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Vote enregistré ✅")),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Erreur lors du vote : $e",
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          "Ce sujet est un sondage libre (pas encore d’options structurées).",
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur chargement options : $e")),
      );
    }
  }

  void _ouvrirPlanifier() {
    // Bottom sheet : création d’un VOTE ou d’un SONDAGE
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        bool isSondage = false;

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nouveau vote / sondage',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Vote'),
                            selected: !isSondage,
                            onSelected: (_) =>
                                setLocal(() => isSondage = false),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Sondage'),
                            selected: isSondage,
                            onSelected: (_) => setLocal(() => isSondage = true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _titre,
                        decoration: const InputDecoration(
                          labelText: 'Titre',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _desc,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Description / contexte',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: const [
                          Expanded(
                            child: _SmallFieldPlaceholder(
                              label: 'Date (JJ/MM)',
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _SmallFieldPlaceholder(
                              label: 'Heure (ex: 18h00)',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!isSondage) ...[
                        const Text(
                          'Options du vote',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _opt1,
                                decoration: const InputDecoration(
                                  labelText: 'Option 1',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _opt2,
                                decoration: const InputDecoration(
                                  labelText: 'Option 2',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _creating
                              ? null
                              : () => _creerVote(isSondage: isSondage),
                          icon: _creating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  isSondage
                                      ? Icons.poll_outlined
                                      : Icons.how_to_vote,
                                ),
                          label: Text(
                            _creating
                                ? 'Création...'
                                : (isSondage
                                    ? 'Créer le sondage'
                                    : 'Créer le vote'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Seuls les responsables (modérateurs, admins...) peuvent créer des votes ou sondages officiels. '
                        'Le backend vérifiera votre rôle.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 🔗 Ouvre le **chat de quartier** réel (branché sur Supabase + realtime)
  void _ouvrirSalon() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PageChat(
          title: 'Salon du quartier',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: ThemeWontanara.texte,
        title: const Text(
          'Votes & gouvernance',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      // 👉 FAB = accès direct au salon du quartier (flottant)
      floatingActionButton: FloatingActionButton(
        onPressed: _ouvrirSalon,
        backgroundColor: ThemeWontanara.vertPetrole,
        foregroundColor: Colors.white,
        child: const Icon(Ionicons.chatbubble_ellipses_outline),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // -------- Bloc gouvernance : création d’un vote / sondage --------
            _GouvernanceActionsCard(
              canCreate: _canCreateVote,
              onCreate: _canCreateVote ? _ouvrirPlanifier : null,
            ),

            const SizedBox(height: 20),

            // -------- Votes ouverts --------
            const _SectionTitle('Votes & sondages ouverts'),
            const SizedBox(height: 8),
            if (_loading)
              const _SkeletonVotes()
            else if (_error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              )
            else if (_votes.isEmpty)
              const Text(
                "Aucun vote / sondage pour l’instant.",
                style: TextStyle(color: Colors.grey),
              )
            else
              ..._votes.map(
                (v) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _VoteCard(
                    vote: v,
                    onTap: () => _ouvrirVote(v),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // -------- Info salon de quartier --------
            const _SectionTitle('Salon du quartier'),
            const SizedBox(height: 8),
            const Text(
              "Utilisez le bouton de discussion flottant pour échanger en direct avec les voisins sur les sujets en cours.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
 *  Section title
 * ==========================================================*/

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: ThemeWontanara.vertPetrole,
      ),
    );
  }
}

/* ============================================================
 *  Carte "Actions de gouvernance"
 * ==========================================================*/

class _GouvernanceActionsCard extends StatelessWidget {
  final bool canCreate;
  final VoidCallback? onCreate;

  const _GouvernanceActionsCard({
    required this.canCreate,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = Colors.white;
    final Color btnBg =
        canCreate ? ThemeWontanara.vertPetrole : Colors.grey.shade300;
    final Color btnFg = Colors.white;

    return Container(
      decoration: _cardBox,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ThemeWontanara.menthe,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Ionicons.git_branch_outline,
              color: ThemeWontanara.vertPetrole,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Actions de gouvernance',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  canCreate
                      ? 'Créez un nouveau vote ou sondage pour le quartier.'
                      : 'Seuls les responsables du quartier peuvent créer des votes / sondages.',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: canCreate ? onCreate : null,
            style: FilledButton.styleFrom(
              backgroundColor: btnBg,
              foregroundColor: btnFg,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Ionicons.add_circle_outline, size: 18),
            label: const Text(
              'Créer',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
 *  Cartes & widgets UI
 * ==========================================================*/

class _VoteCard extends StatelessWidget {
  final VoteItem vote;
  final VoidCallback onTap;

  const _VoteCard({required this.vote, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: _cardBox,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ThemeWontanara.menthe,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.place_rounded,
                color: ThemeWontanara.vertPetrole,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vote.titre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mode : ${vote.mode} • Statut : ${vote.statut}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _SmallFieldPlaceholder extends StatelessWidget {
  final String label;
  const _SmallFieldPlaceholder({required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/* ============================================================
 *  Squelettes
 * ==========================================================*/

class _SkeletonVotes extends StatelessWidget {
  const _SkeletonVotes();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(4, (i) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
        );
      }),
    );
  }
}

final _cardBox = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(18),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ],
);
