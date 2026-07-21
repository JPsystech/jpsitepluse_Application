import 'package:intl/intl.dart';
import 'package:sitepulse_engineer/core/config/app_config.dart';

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
    final formatter = DateFormat(AppConfig.dateFormat);
    return formatter.format(v);
  }

  static String formatTime(DateTime dt) {
    final v = toIst(dt);
    final h = v.hour.toString().padLeft(2, "0");
    final m = v.minute.toString().padLeft(2, "0");
    return "$h:$m";
  }

  static String formatDateTime(DateTime dt) {
    final v = toIst(dt);
    final formatter = DateFormat("${AppConfig.dateFormat} HH:mm");
    return formatter.format(v);
  }
}
