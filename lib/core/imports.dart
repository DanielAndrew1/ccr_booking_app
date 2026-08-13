// Core Packages
export 'dart:async';
export 'dart:io';
export 'package:flutter/material.dart';
export 'package:flutter_localizations/flutter_localizations.dart';
export 'package:flutter/scheduler.dart';
export 'package:flutter/services.dart';
export 'package:flutter_svg/flutter_svg.dart';

// Third-Party Packages
export 'package:firebase_core/firebase_core.dart';
export 'package:firebase_messaging/firebase_messaging.dart';
export 'package:connectivity_plus/connectivity_plus.dart';
export 'package:flutter_svg/svg.dart';
export 'package:image_picker/image_picker.dart';
export 'package:provider/provider.dart';
export 'package:supabase_flutter/supabase_flutter.dart';

// Core
export 'package:site_lapse/core/app_images.dart';
export 'package:site_lapse/core/app_theme.dart';
export 'package:site_lapse/core/app_version_plus.dart';
export 'package:site_lapse/core/root.dart';
export 'package:site_lapse/core/theme.dart';
export 'package:site_lapse/core/theme_context.dart';
export 'package:site_lapse/core/user_provider.dart';
export 'package:site_lapse/localization/app_localizations.dart';
export 'package:site_lapse/localization/locale_provider.dart';
export 'package:site_lapse/main.dart';

// Providers
export 'package:site_lapse/providers/booking_provider.dart';
export 'package:site_lapse/providers/navbar_provider.dart';

// Models
export 'package:site_lapse/models/message_model.dart';
export 'package:site_lapse/models/user_model.dart';

// Services
export 'package:site_lapse/services/auth_service.dart';
export 'package:site_lapse/services/supbase_service.dart';
export 'package:site_lapse/services/notification_service.dart';
export 'package:site_lapse/services/booking_operations_service.dart';
export 'package:site_lapse/services/project_commercial_service.dart';
export 'package:site_lapse/services/project_quote_service.dart';
export 'package:site_lapse/services/project_finance_service.dart';

// Pages - Authentication
export 'package:site_lapse/pages/auth/login_page.dart';
export 'package:site_lapse/pages/auth/register_page.dart';

// Pages - Splash
export 'package:site_lapse/pages/splash/splash_screen.dart';

// Pages - Home/Main
export 'package:site_lapse/pages/bookings/bookings_page.dart';
export 'package:site_lapse/pages/bookings/edit_booking.dart';
export 'package:site_lapse/pages/bookings/project_site_setup_page.dart';
export 'package:site_lapse/pages/calendar/calendar_page.dart';
export 'package:site_lapse/pages/home/home_page.dart';
export 'package:site_lapse/pages/inventory/inventory_page.dart';
export 'package:site_lapse/pages/inventory/product_page.dart';
export 'package:site_lapse/pages/messages/messages_page.dart';
export 'package:site_lapse/pages/profile/profile_page.dart';
export 'package:site_lapse/pages/system/no_internet_page.dart';
export 'package:site_lapse/pages/users/clients_page.dart';
export 'package:site_lapse/pages/users/employees_page.dart';

// Pages - Messages
export 'package:site_lapse/pages/messages/message_thread_page.dart';

// Pages - Profile
export 'package:site_lapse/pages/profile/about_page.dart';
export 'package:site_lapse/pages/profile/edit_info_page.dart';
export 'package:site_lapse/pages/profile/settings_page.dart';

// Pages - Icon handler
export 'package:site_lapse/widgets/icon_handler/icon_handler.dart';

// Pages - Add/Create
export 'package:site_lapse/pages/add/add_booking.dart';
export 'package:site_lapse/pages/add/add_client.dart';
export 'package:site_lapse/pages/add/add_product.dart';

// Widgets - Navigation
export 'package:site_lapse/widgets/navigation/custom_appbar.dart';
export 'package:site_lapse/widgets/navigation/custom_navbar.dart';

// Widgets - Feedback
export 'package:site_lapse/widgets/feedback/custom_alert_dialogue.dart';
export 'package:site_lapse/widgets/feedback/custom_loader.dart';
export 'package:site_lapse/widgets/feedback/custom_snackbar.dart';

// Widgets - Display
export 'package:site_lapse/widgets/display/custom_bg_svg.dart';
export 'package:site_lapse/widgets/display/custom_pfp.dart';
export 'package:site_lapse/widgets/display/project_client_card.dart';

// Widgets - Inputs
export 'package:site_lapse/widgets/inputs/custom_button.dart';
export 'package:site_lapse/widgets/inputs/custom_search.dart';
export 'package:site_lapse/widgets/inputs/custom_textfield.dart';
export 'package:site_lapse/widgets/inputs/project_commercial_fields.dart';

// Widgets - Tiles
export 'package:site_lapse/widgets/tiles/custom_booking_tile.dart';
export 'package:site_lapse/widgets/tiles/custom_product_tile.dart';
export 'package:site_lapse/widgets/tiles/custom_tile.dart';
