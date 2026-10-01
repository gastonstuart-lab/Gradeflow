import 'package:gradeflow/config/instructos_branding.dart';

class GradeFlowProductConfig {
  static const String appName = InstructOSBranding.productName;
  static const String marketingTagline = InstructOSBranding.productTagline;
  static const String defaultSchoolName = InstructOSBranding.defaultSchoolName;
  static const String defaultAttendancePortalUrl =
      'https://fsis.hn.thu.edu.tw/csn1t/permain.asp';

  static const String dashboardWeatherLocationName = 'Taichung City';
  static const double dashboardWeatherLatitude = 24.1469;
  static const double dashboardWeatherLongitude = 120.6839;
  static const String dashboardWeatherTimeZone = 'Asia/Taipei';

  static const String dashboardLocalNewsQuery = 'Taichung school';
  static const String dashboardLocalNewsLanguage = 'en-US';
  static const String dashboardLocalNewsGeo = 'TW';
  static const String dashboardLocalNewsEdition = 'TW:en';

  static String resolvedSchoolName(String? schoolName) {
    final trimmed = schoolName?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return defaultSchoolName;
    }
    return trimmed;
  }
}
