/// A user-made list of cards, like a playlist: any mix of roots, words and
/// patterns, gathered to browse or practise together. Lives only on this
/// device; it isn't part of what sync uploads.
class CardCollection {
  final int id;
  final String name;

  /// How many cards are in it.
  final int cardCount;

  const CardCollection({
    required this.id,
    required this.name,
    this.cardCount = 0,
  });

  factory CardCollection.fromMap(Map<String, Object?> map) {
    return CardCollection(
      id: map['id'] as int,
      name: map['name'] as String,
      cardCount: map['card_count'] as int? ?? 0,
    );
  }
}
