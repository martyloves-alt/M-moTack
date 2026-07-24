import 'package:flutter/material.dart';

import '../engine.dart';
import '../models.dart';
import '../storage.dart';
import '../theme.dart';

class AccueilScreen extends StatelessWidget {
  final AppState appState;
  const AccueilScreen({super.key, required this.appState});

  Tag _tagFor(Flashcard c) {
    for (final t in appState.tags) {
      if (t.id == c.tagId) return t;
    }
    return appState.tags.first;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final due = dueCards(appState.cards, now);
    final upcoming = upcomingCards(appState.cards, now);

    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.push_pin, color: AppColors.corail, size: 20),
            const SizedBox(width: 8),
            Text(
              'MémoTack',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: AppColors.paper, fontSize: 20),
            ),
          ],
        ),
      ),
      body: appState.cards.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _sectionHeader(context, "Aujourd'hui", badge: due.length),
                const SizedBox(height: 8),
                if (due.isEmpty)
                  _emptyLine("Rien à réviser pour l'instant.")
                else
                  ...due.map(
                    (c) => _CardTile(card: c, tag: _tagFor(c), appState: appState),
                  ),
                const SizedBox(height: 20),
                _sectionHeader(context, 'À venir'),
                const SizedBox(height: 8),
                if (upcoming.isEmpty)
                  _emptyLine('Rien de prévu pour le moment.')
                else
                  ...upcoming.map(
                    (c) => _CardTile(card: c, tag: _tagFor(c), appState: appState),
                  ),
              ],
            ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, {int? badge}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(color: AppColors.paper, fontSize: 18),
        ),
        if (badge != null && badge > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.corail,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$badge DÛS', style: stampStyle(color: AppColors.paper)),
          ),
      ],
    );
  }

  Widget _emptyLine(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: TextStyle(color: AppColors.paperMuted)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.push_pin_outlined, color: AppColors.paperMuted, size: 40),
            const SizedBox(height: 12),
            Text(
              "Aucun mot pour l'instant. Ajoute-en un depuis l'onglet Ajouter.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.paperMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final Flashcard card;
  final Tag tag;
  final AppState appState;

  const _CardTile({required this.card, required this.tag, required this.appState});

  @override
  Widget build(BuildContext context) {
    final isDue = !card.nextReviewAt.isAfter(DateTime.now());
    final dueLabel = isDue ? 'Dû' : _formatFuture(card.nextReviewAt);

    return GestureDetector(
      onTap: () => _openReview(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6, right: 10),
              decoration: BoxDecoration(
                color: AppColors.forTagColor(tagColorToString(tag.color)),
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.front,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: AppColors.soot, fontSize: 15, height: 1.2),
                  ),
                  if (card.back.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      card.back,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.soot.withValues(alpha: 0.6), fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.soot.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(tag.name, style: TextStyle(color: AppColors.soot, fontSize: 9)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('NIV.${card.level}', style: stampStyle(size: 9, color: AppColors.soot.withValues(alpha: 0.5))),
                Text(dueLabel, style: stampStyle(size: 9, color: AppColors.soot.withValues(alpha: 0.5))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatFuture(DateTime date) {
    final diff = date.difference(DateTime.now());
    if (diff.inDays >= 1) return 'Dans ${diff.inDays} j';
    if (diff.inHours >= 1) return 'Dans ${diff.inHours} h';
    return 'Bientôt';
  }

  void _openReview(BuildContext context) {
    bool showBack = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tag.name, style: TextStyle(color: AppColors.soot.withValues(alpha: 0.6), fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(
                    card.front,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.soot),
                  ),
                  const SizedBox(height: 16),
                  if (card.back.isNotEmpty)
                    GestureDetector(
                      onTap: () => setSheetState(() => showBack = !showBack),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.soot.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          showBack ? card.back : 'Toucher pour voir la définition',
                          style: TextStyle(color: AppColors.soot.withValues(alpha: 0.8)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            appState.updateCard(
                              reviewCard(card: card, remembered: false, now: DateTime.now()),
                            );
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('À revoir'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: AppColors.inkBlue),
                          onPressed: () {
                            appState.updateCard(
                              reviewCard(card: card, remembered: true, now: DateTime.now()),
                            );
                            Navigator.pop(sheetContext);
                          },
                          child: const Text("Je m'en souviens"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
