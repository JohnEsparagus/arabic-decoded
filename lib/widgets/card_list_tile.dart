import 'package:flutter/material.dart';

import '../models/flashcard.dart';
import '../screens/word_detail_screen.dart';
import '../theme/app_theme.dart';
import 'card_actions_sheet.dart';

/// One card as a row in a list: its Arabic, its meaning, a star if it's a
/// favorite. Tapping opens the card; holding brings up its actions.
class CardListTile extends StatelessWidget {
  const CardListTile({super.key, required this.card, this.trailing});

  final Flashcard card;

  /// Shown at the end of the row in place of the usual chevron.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => WordDetailScreen(card: card))),
        onLongPress: () => showCardActions(context, card),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.arabicWord,
                      textDirection: TextDirection.rtl,
                      style: arabicTextStyle(
                        context,
                        fontSize: 22,
                        color: colors.ink,
                      ),
                    ),
                    Text(
                      card.englishTranslation,
                      style: TextStyle(color: colors.inkMuted),
                    ),
                  ],
                ),
              ),
              if (card.isFavorite)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.star, color: colors.gold, size: 18),
                ),
              trailing ?? Icon(Icons.chevron_right, color: colors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
