class IstTime {
  static const Duration _offset = Duration(hours: 5, minutes: 30);

  static DateTime now() {
    return DateTime.now().toUtc().add(_offset);
  }

  static DateTime toIst(DateTime dt) {
    return dt.toUtc().add(_offset);
  }

  static String formatDate(DateTime dt) {
    final v = toIst(dt);
    final y = v.year.toString().padLeft(4, "0");
    final m = v.month.toString().padLeft(2, "0");
    final d = v.day.toString().padLeft(2, "0");
    return "$y-$m-$d";
  }

  static String formatTime(DateTime dt) {
    final v = toIst(dt);
    final h = v.hour.toString().padLeft(2, "0");
    final m = v.minute.toString().padLeft(2, "0");
    return "$h:$m";
  }

  static String formatDateTime(DateTime dt) {
    final v = toIst(dt);
    final y = v.year.toString().padLeft(4, "0");
    final mon = v.month.toString().padLeft(2, "0");
    final d = v.day.toString().padLeft(2, "0");
    final h = v.hour.toString().padLeft(2, "0");
    final m = v.minute.toString().padLeft(2, "0");
    return "$y-$mon-$d $h:$m";
  }
}
