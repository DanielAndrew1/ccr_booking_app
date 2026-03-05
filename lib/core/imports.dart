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
export 'package:ccr_booking/core/app_images.dart';
export 'package:ccr_booking/core/app_theme.dart';
export 'package:ccr_booking/core/app_version_plus.dart';
export 'package:ccr_booking/core/root.dart';
export 'package:ccr_booking/core/theme.dart';
export 'package:ccr_booking/core/user_provider.dart';
export 'package:ccr_booking/localization/app_localizations.dart';
export 'package:ccr_booking/localization/locale_provider.dart';
export 'package:ccr_booking/main.dart';

// Providers
export 'package:ccr_booking/providers/booking_provider.dart';
export 'package:ccr_booking/providers/navbar_provider.dart';

// Models
export 'package:ccr_booking/models/user_model.dart';

// Services
export 'package:ccr_booking/services/auth_service.dart';
export 'package:ccr_booking/services/supbase_service.dart';
export 'package:ccr_booking/services/notification_service.dart';

// Pages - Authentication
export 'package:ccr_booking/pages/auth/login_page.dart';
export 'package:ccr_booking/pages/auth/register_page.dart';

// Pages - Home/Main
export 'package:ccr_booking/pages/bookings/bookings_page.dart';
export 'package:ccr_booking/pages/bookings/edit_booking.dart';
export 'package:ccr_booking/pages/calendar/calendar_page.dart';
export 'package:ccr_booking/pages/home/home_page.dart';
export 'package:ccr_booking/pages/inventory/inventory_page.dart';
export 'package:ccr_booking/pages/inventory/product_page.dart';
export 'package:ccr_booking/pages/messages/messages_page.dart';
export 'package:ccr_booking/pages/profile/profile_page.dart';
export 'package:ccr_booking/pages/system/no_internet_page.dart';
export 'package:ccr_booking/pages/users/clients_page.dart';
export 'package:ccr_booking/pages/users/employees_page.dart';

// Pages - Profile
export 'package:ccr_booking/pages/profile/about_page.dart';
export 'package:ccr_booking/pages/profile/edit_info_page.dart';
export 'package:ccr_booking/pages/profile/settings_page.dart';

// Pages - Add/Create
export 'package:ccr_booking/pages/add/add_booking.dart';
export 'package:ccr_booking/pages/add/add_client.dart';
export 'package:ccr_booking/pages/add/add_product.dart';

// Widgets - Navigation
export 'package:ccr_booking/widgets/navigation/custom_appbar.dart';
export 'package:ccr_booking/widgets/navigation/custom_navbar.dart';

// Widgets - Feedback
export 'package:ccr_booking/widgets/feedback/custom_alert_dialogue.dart';
export 'package:ccr_booking/widgets/feedback/custom_loader.dart';
export 'package:ccr_booking/widgets/feedback/custom_snackbar.dart';

// Widgets - Display
export 'package:ccr_booking/widgets/display/custom_bg_svg.dart';
export 'package:ccr_booking/widgets/display/custom_pfp.dart';

// Widgets - Inputs
export 'package:ccr_booking/widgets/inputs/custom_button.dart';
export 'package:ccr_booking/widgets/inputs/custom_search.dart';
export 'package:ccr_booking/widgets/inputs/custom_textfield.dart';

// Widgets - Tiles
export 'package:ccr_booking/widgets/tiles/custom_booking_tile.dart';
export 'package:ccr_booking/widgets/tiles/custom_product_tile.dart';
export 'package:ccr_booking/widgets/tiles/custom_tile.dart';
