import 'package:ccr_booking/core/theme.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

extension ThemeContextX on BuildContext {
  bool get isDarkMode => watch<ThemeProvider>().isDarkMode;

  bool get isDarkModeRead => read<ThemeProvider>().isDarkMode;

  bool get isLightMode => !isDarkMode;
}
