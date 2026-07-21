import 'package:sitepulse_engineer/core/utils/ist_time.dart';

class AppFormatters {
  static String formatTime(DateTime? dt) {
    if (dt == null) return "-";
    return IstTime.formatTime(dt);
  }

  static String formatTimeWithSeconds(DateTime? dt) {
    if (dt == null) return "-";
    final ist = IstTime.toIst(dt);
    final h = ist.hour > 12 ? ist.hour - 12 : (ist.hour == 0 ? 12 : ist.hour);
    final ampm = ist.hour >= 12 ? "PM" : "AM";
    return "${h.toString().padLeft(2, '0')}:${ist.minute.toString().padLeft(2, '0')}:${ist.second.toString().padLeft(2, '0')} $ampm";
  }

  static String formatDate(DateTime? dt) {
    if (dt == null) return "-";
    return IstTime.formatDate(dt);
  }

  static String formatDateString(String s) {
    final t = s.trim();
    if (t.isEmpty) return "-";
    
    final parsed = DateTime.tryParse(t);
    if (parsed != null) {
      return IstTime.formatDate(parsed);
    }
    
    if (t.length >= 10) return t.substring(0, 10);
    return t;
  }

  static String formatHours(double v) {
    if (v <= 0) return "0";
    final s = v.toStringAsFixed(2);
    return s.replaceAll(RegExp(r"\.?0+$"), "");
  }
}
