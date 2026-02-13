// Core Packages
export 'dart:async';
export 'dart:io';
export 'package:flutter/material.dart';
export 'package:flutter/services.dart';
export 'package:flutter/scheduler.dart';
export 'package:flutter_svg/flutter_svg.dart';
export 'package:ccr_booking/core/app_images.dart';
export 'package:ccr_booking/core/app_version_plus.dart';
export 'package:flutter_localizations/flutter_localizations.dart';

// Third-Party Packages
export 'package:firebase_core/firebase_core.dart';
export 'package:firebase_messaging/firebase_messaging.dart';
export 'package:provider/provider.dart';
export 'package:sqflite_common_ffi/sqflite_ffi.dart';
export 'package:supabase_flutter/supabase_flutter.dart';
export 'package:connectivity_plus/connectivity_plus.dart';
export 'package:image_picker/image_picker.dart';
export 'package:flutter_svg/svg.dart';

// Core Application Logic
export 'package:ccr_booking/main.dart';
export 'package:ccr_booking/core/root.dart';
export 'package:ccr_booking/core/theme.dart';
export 'package:ccr_booking/core/app_theme.dart';
export 'package:ccr_booking/core/user_provider.dart';
export 'package:ccr_booking/localization/app_localizations.dart';
export 'package:ccr_booking/localization/locale_provider.dart';

// Providers
export 'package:ccr_booking/providers/booking_provider.dart';
export '../providers/navbar_provider.dart';

// Models
export 'package:ccr_booking/models/user_model.dart';

// Services
export 'package:ccr_booking/services/supbase_service.dart';
export 'package:ccr_booking/services/notification_service.dart';
export '../services/auth_service.dart';

// Pages - Authentication
export 'package:ccr_booking/pages/login_page.dart';
export 'package:ccr_booking/pages/register_page.dart';

// Pages - Main Navigation
export 'package:ccr_booking/pages/home_page.dart';
export 'package:ccr_booking/pages/calendar_page.dart';
export 'package:ccr_booking/pages/inventory_page.dart';
export 'package:ccr_booking/pages/profile_page.dart';
export 'package:ccr_booking/pages/bookings_page.dart';
export 'package:ccr_booking/pages/about_page.dart';

// Pages - Management & Details
export 'package:ccr_booking/pages/clients_page.dart';
export 'package:ccr_booking/pages/employees_page.dart';
export 'package:ccr_booking/pages/product_page.dart';
export 'package:ccr_booking/pages/edit_booking.dart';
export '../pages/edit_info_page.dart';
export 'package:ccr_booking/pages/settings_page.dart';

// Pages - Creation/Addition
export 'package:ccr_booking/pages/add/add_booking.dart';
export 'package:ccr_booking/pages/add/add_client.dart';
export 'package:ccr_booking/pages/add/add_product.dart';

// Widgets - General UI
export 'package:ccr_booking/widgets/custom_appbar.dart';
export 'package:ccr_booking/widgets/custom_navbar.dart';
export 'package:ccr_booking/widgets/custom_bg_svg.dart';
export 'package:ccr_booking/widgets/custom_button.dart';
export 'package:ccr_booking/widgets/custom_textfield.dart';
export 'package:ccr_booking/widgets/custom_loader.dart';
export 'package:ccr_booking/widgets/custom_internet_notification.dart';
export 'package:ccr_booking/widgets/custom_alert_dialogue.dart';

// Widgets - Specialized Components
export '../widgets/custom_pfp.dart';
export '../widgets/custom_tile.dart';
export 'package:ccr_booking/widgets/custom_product_tile.dart';
export 'package:ccr_booking/widgets/custom_search.dart';
export 'package:ccr_booking/widgets/custom_snackbar.dart';
