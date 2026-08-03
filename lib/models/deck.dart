/// A named collection of [Flashcard]s (e.g. "Campaign", "Quran").
class Deck {
  final int? id;
  final String name;
  final String? description;

  const Deck({this.id, required this.name, this.description});

  factory Deck.fromMap(Map<String, Object?> map) {
    return Deck(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
    };
  }
}
