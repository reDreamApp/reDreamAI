import 'package:intl/intl.dart';

import 'package:redream_app/l10n/generated/app_localizations.dart';

String formatShortDate(DateTime date) =>
    DateFormat('dd/MM/yyyy').format(date.toLocal());

String formatTime(DateTime date) => DateFormat.Hm().format(date.toLocal());

/// "Today", "Yesterday", "3 days ago" or a short date.
String formatRelativeDay(DateTime date, AppLocalizations l10n) {
  final local = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return l10n.dateToday;
  if (diff == 1) return l10n.dateYesterday;
  if (diff < 7) return l10n.dateDaysAgo(diff);
  return DateFormat.yMMMd(l10n.localeName).format(local);
}

bool isSameLocalDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}
