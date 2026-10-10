/// The few date formats the app shows, written out by hand: they're all
/// short English forms, which doesn't justify pulling in a date library.
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Oct"
String shortMonth(DateTime date) => _months[date.month - 1];

/// "11 Oct"
String dayAndMonth(DateTime date) => '${date.day} ${shortMonth(date)}';

/// "11 Oct 2026"
String fullDate(DateTime date) => '${dayAndMonth(date)} ${date.year}';

/// "Oct 2026"
String monthAndYear(DateTime date) => '${shortMonth(date)} ${date.year}';
