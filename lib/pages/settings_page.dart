// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/imports.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  String _languageCode = 'en';
  bool _homeStatsDialog = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final notifyStatus = await NotificationService.isEnabled();
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('app_language') ?? 'en';
    final homeStatsDialog = prefs.getBool('home_stats_dialog') ?? true;
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = notifyStatus;
      _languageCode = savedLang;
      _homeStatsDialog = homeStatsDialog;
    });
  }

  Future<void> _handleNotificationToggle(bool value) async {
    final result = await NotificationService().toggleNotifications(value);
    if (!mounted) {
      final loc = AppLocalizations.of(context);
      CustomSnackBar.show(
        context,
        loc.tr("Notifications Enabled Successfully"),
        color: AppColors.green,
      );
    }
    setState(() => _notificationsEnabled = result);
    if (value && !result) {
      final loc = AppLocalizations.of(context);
      CustomSnackBar.show(
        context,
        loc.tr("Notifications blocked in System Settings"),
      );
    }
  }

  Future<void> _setLanguage(String? value) async {
    if (value == null || value == _languageCode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', value);
    if (!mounted) return;
    setState(() => _languageCode = value);
    final loc = AppLocalizations.of(context);
    CustomSnackBar.show(
      context,
      loc.tr("Language updated"),
      color: AppColors.green,
    );
  }

  Future<void> _setHomeStatsDialog(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('home_stats_dialog', value);
    if (!mounted) return;
    setState(() => _homeStatsDialog = value);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final loc = AppLocalizations.of(context);
    final isDark = themeProvider.isDarkMode;

    return Container(
      color: isDark ? AppColors.darkbg : AppColors.lightcolor,
      child: Stack(
        children: [
          const CustomBgSvg(),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: CustomAppBar(text: loc.tr("Settings"), showPfp: false),
            body: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                children: [
                  CustomTile(
                    title: loc.tr("Dark Mode"),
                    imagePath: AppIcons.moon,
                    overlayColor: false,
                    trailing: CupertinoSwitch(
                      value: isDark,
                      activeTrackColor: AppColors.primary,
                      onChanged: (value) => themeProvider.toggleTheme(value),
                    ),
                  ),
                  CustomTile(
                    title: loc.tr("Notifications"),
                    imagePath: AppIcons.notification,
                    overlayColor: false,
                    trailing: CupertinoSwitch(
                      value: _notificationsEnabled,
                      activeTrackColor: AppColors.primary,
                      onChanged: _handleNotificationToggle,
                    ),
                  ),
                  CustomTile(
                    title: loc.tr("Home Cards Open Dialog"),
                    imagePath: AppIcons.info,
                    overlayColor: false,
                    trailing: CupertinoSwitch(
                      value: _homeStatsDialog,
                      activeTrackColor: AppColors.primary,
                      onChanged: _setHomeStatsDialog,
                    ),
                  ),
                  CustomTile(
                    title: loc.tr("App Language"),
                    imagePath: AppIcons.globe,
                    overlayColor: false,
                    trailing: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _languageCode,
                        dropdownColor: isDark
                            ? const Color(0xFF1E1E1E)
                            : Colors.white,
                        iconEnabledColor: isDark
                            ? Colors.white70
                            : Colors.black54,
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text("   English")),
                          DropdownMenuItem(value: 'ar', child: Text("   Arabic")),
                          DropdownMenuItem(value: 'es', child: Text("   Spanish")),
                          DropdownMenuItem(value: 'fr', child: Text("   French")),
                          DropdownMenuItem(value: 'de', child: Text("   German")),
                          DropdownMenuItem(value: 'ru', child: Text("   Russian")),
                          DropdownMenuItem(value: 'zh', child: Text("   Chinese")),
                          DropdownMenuItem(value: 'ja', child: Text("   Japanese")),
                          DropdownMenuItem(value: 'ko', child: Text("   Korean")),
                          DropdownMenuItem(value: 'pt', child: Text("   Portuguese")),
                          DropdownMenuItem(value: 'it', child: Text("   Italian")),
                          DropdownMenuItem(value: 'nl', child: Text("   Dutch")),
                        ],
                        onChanged: (value) async {
                          await _setLanguage(value);
                          final code = value ?? 'en';
                          await localeProvider.setLocale(Locale(code));
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
