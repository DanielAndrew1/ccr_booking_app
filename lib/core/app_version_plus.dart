import 'package:package_info_plus/package_info_plus.dart';

abstract class AppVersionPlus {
  static Future<String> appVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    // String appName = packageInfo.appName;
    // String packageName = packageInfo.packageName;
    String version = packageInfo.version;
    // String buildNumber = packageInfo.buildNumber;

    return version;
  }
}
