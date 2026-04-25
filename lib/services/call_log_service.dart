import 'dart:io';
import 'package:call_log/call_log.dart';

/// Reads the device call log (Android only).
/// On iOS this always returns an empty map.
class CallLogService {
  CallLogService._();

  /// Returns a map from normalised phone number → most-recent call timestamp.
  /// Only looks at the last [daysBack] days to keep it fast.
  static Future<Map<String, DateTime>> fetchLastCallPerNumber({
    int daysBack = 180,
  }) async {
    if (!Platform.isAndroid) return {};

    try {
      final since = DateTime.now()
          .subtract(Duration(days: daysBack))
          .millisecondsSinceEpoch;

      final entries = await CallLog.query(
        dateFrom: since,
        dateTo: DateTime.now().millisecondsSinceEpoch,
      );

      final map = <String, DateTime>{};
      for (final e in entries) {
        final raw = e.number;
        if (raw == null || raw.isEmpty) continue;
        final normalised = _normalise(raw);
        final ts = e.timestamp;
        if (ts == null) continue;
        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        final existing = map[normalised];
        if (existing == null || dt.isAfter(existing)) {
          map[normalised] = dt;
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  /// Find the most recent call for any of the given phone numbers.
  static DateTime? lastCallFor(
      List<String> phones, Map<String, DateTime> callMap) {
    DateTime? best;
    for (final p in phones) {
      final dt = callMap[_normalise(p)];
      if (dt != null && (best == null || dt.isAfter(best))) {
        best = dt;
      }
    }
    return best;
  }

  /// Hebrew label for how long ago a call was.
  static String hebrewLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'עכשיו';
    if (diff.inMinutes < 60) return 'לפני ${diff.inMinutes} דק\'';
    if (diff.inHours < 24) return 'לפני ${diff.inHours} שע\'';
    if (diff.inDays == 1) return 'אתמול';
    if (diff.inDays < 7) return 'לפני ${diff.inDays} ימים';
    if (diff.inDays < 30) return 'לפני ${(diff.inDays / 7).round()} שבועות';
    if (diff.inDays < 365) return 'לפני ${(diff.inDays / 30).round()} חודשים';
    return 'לפני יותר משנה';
  }

  // Strip spaces, dashes and leading country code for fuzzy matching.
  static String _normalise(String phone) {
    var n = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    // Convert +972XX → 0XX (Israel)
    if (n.startsWith('+972')) n = '0${n.substring(4)}';
    return n;
  }
}
