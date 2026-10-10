/// One entry in the "Dev updates" list: what changed in the app and when.
/// Loaded from assets/data/dev_updates.json, newest first, so adding an
/// entry is a matter of editing that file.
class DevUpdate {
  final DateTime date;
  final String title;
  final List<String> changes;

  const DevUpdate({
    required this.date,
    required this.title,
    required this.changes,
  });

  factory DevUpdate.fromJson(Map<String, dynamic> json) {
    return DevUpdate(
      date: DateTime.parse(json['date'] as String),
      title: json['title'] as String,
      changes: (json['changes'] as List).cast<String>(),
    );
  }
}
