class AppConfig {
  static String _dateFormat = "dd-MM-yyyy";

  static void setDateFormat(String format) {
    switch (format) {
      case "DD-MM-YYYY":
        _dateFormat = "dd-MM-yyyy";
        break;
      case "YYYY-MM-DD":
        _dateFormat = "yyyy-MM-dd";
        break;
      case "DD MMM YYYY":
        _dateFormat = "dd MMM yyyy";
        break;
      default:
        _dateFormat = "dd-MM-yyyy";
    }
  }

  static String get dateFormat => _dateFormat;
}
