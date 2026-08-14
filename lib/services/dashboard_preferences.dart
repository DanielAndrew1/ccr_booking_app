import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPreferences {
  static const sectionsKey = 'dashboard_sections';
  static const actionsKey = 'dashboard_quick_actions';

  static const defaultSections = <String>[
    'stats',
    'installations',
    'removals',
    'quick_actions',
  ];

  static const defaultActions = <String>[
    'add_project',
    'add_client',
    'add_product',
    'view_projects',
    'inventory',
  ];

  static final ValueNotifier<int> changed = ValueNotifier<int>(0);

  static Future<List<String>> sections() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(sectionsKey) ?? List.of(defaultSections);
  }

  static Future<List<String>> actions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(actionsKey) ?? List.of(defaultActions);
  }

  static Future<void> save({
    required List<String> sections,
    required List<String> actions,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(sectionsKey, sections.toList());
    await prefs.setStringList(actionsKey, actions.toList());
    changed.value++;
  }
}
