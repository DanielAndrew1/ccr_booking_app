import 'package:site_lapse/core/imports.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class ProjectSiteSetupPage extends StatefulWidget {
  const ProjectSiteSetupPage({
    super.key,
    required this.bookingId,
    required this.clientName,
    required this.products,
  });

  final String bookingId;
  final String clientName;
  final List<Map<String, dynamic>> products;

  @override
  State<ProjectSiteSetupPage> createState() => _ProjectSiteSetupPageState();
}

class _ProjectSiteSetupPageState extends State<ProjectSiteSetupPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  bool _saving = false;
  bool _gettingLocation = false;
  double? _latitude;
  double? _longitude;
  double? _accuracy;
  DateTime? _capturedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final location = await _supabase
          .from('project_locations')
          .select()
          .eq('booking_id', widget.bookingId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _latitude = (location?['latitude'] as num?)?.toDouble();
        _longitude = (location?['longitude'] as num?)?.toDouble();
        _accuracy = (location?['accuracy_meters'] as num?)?.toDouble();
        _capturedAt = DateTime.tryParse(
          location?['captured_at']?.toString() ?? '',
        );
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveLocation() async {
    if (_latitude == null || _longitude == null) {
      CustomSnackBar.show(context, 'Use your current location first.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _supabase.from('project_locations').upsert({
        'booking_id': widget.bookingId,
        'address': 'GPS location',
        'latitude': _latitude,
        'longitude': _longitude,
        'accuracy_meters': _accuracy,
        'captured_at': _capturedAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'booking_id');
      if (mounted) {
        CustomSnackBar.show(
          context,
          'Site setup saved.',
          color: AppColors.green,
        );
      }
    } catch (_) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          'Could not save the site setup. Run the latest Supabase SQL first.',
          color: AppColors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _gettingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          CustomSnackBar.show(
            context,
            'Turn on Location Services, then try again.',
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          CustomSnackBar.show(context, 'Location permission was not granted.');
        }
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          CustomSnackBar.show(
            context,
            'Allow location access from your device settings.',
          );
        }
        await Geolocator.openAppSettings();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _accuracy = position.accuracy;
        _capturedAt = position.timestamp;
      });
      await _saveLocation();
    } on TimeoutException {
      if (mounted) {
        CustomSnackBar.show(
          context,
          'Location took too long. Move somewhere with a clearer GPS signal.',
        );
      }
    } catch (_) {
      if (mounted) {
        CustomSnackBar.show(context, 'Could not get your current location.');
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _openInMaps() async {
    if (_latitude == null || _longitude == null) return;
    final coordinates = '$_latitude,$_longitude';
    final uri = Platform.isIOS
        ? Uri.parse('https://maps.apple.com/?daddr=$coordinates&dirflg=d')
        : Uri.parse('geo:$_latitude,$_longitude?q=$coordinates');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      CustomSnackBar.show(context, 'Could not open your maps app.');
    }
  }

  Future<void> _removeLocation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove location?'),
        content: const Text(
          'This will remove the saved site location from this project.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await _supabase
          .from('project_locations')
          .delete()
          .eq('booking_id', widget.bookingId);
      if (!mounted) return;
      setState(() {
        _latitude = null;
        _longitude = null;
        _accuracy = null;
        _capturedAt = null;
      });
      CustomSnackBar.show(context, 'Location removed.', color: AppColors.green);
    } catch (_) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          'Could not remove the location. Please try again.',
          color: AppColors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: CustomAppBar(text: 'Select Site Location', showPfp: false),
      body: _loading
          ? const Center(child: CustomLoader())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _latitude == null
                            ? (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder)
                            : AppColors.primary.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _latitude == null
                                ? Icons.location_searching_rounded
                                : Icons.location_on_rounded,
                            color: AppColors.primary,
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _latitude == null
                              ? 'No location saved'
                              : 'Location saved',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _latitude == null
                              ? 'Use your device GPS to save the exact installation point.'
                              : '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        if (_latitude != null) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (_accuracy != null)
                                _locationChip(
                                  'Accuracy ±${_accuracy!.round()} m',
                                  isDark,
                                ),
                              if (_capturedAt != null)
                                _locationChip(
                                  MaterialLocalizations.of(
                                    context,
                                  ).formatTimeOfDay(
                                    TimeOfDay.fromDateTime(
                                      _capturedAt!.toLocal(),
                                    ),
                                  ),
                                  isDark,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _gettingLocation || _saving
                          ? null
                          : _useCurrentLocation,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      icon: _gettingLocation || _saving
                          ? const CustomLoader(
                              size: 20,
                              strokeWidth: 2,
                              color: Colors.white,
                            )
                          : const Icon(Icons.my_location_rounded, size: 21),
                      label: Text(
                        _gettingLocation
                            ? 'Getting location...'
                            : _saving
                            ? 'Saving location...'
                            : _latitude == null
                            ? 'Use Current Location'
                            : 'Update Current Location',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (_latitude != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _openInMaps,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.3,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        icon: const Icon(Icons.map_rounded, size: 21),
                        label: const Text(
                          'Open in Maps',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _saving || _gettingLocation
                            ? null
                            : _removeLocation,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.red,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.red.withValues(
                            alpha: 0.45,
                          ),
                          disabledForegroundColor: Colors.white70,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        icon: SvgPicture.asset(
                          AppIcons.trash,
                          width: 21,
                          height: 21,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                        label: const Text(
                          'Remove Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Your location is only saved for this project.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _locationChip(String text, bool isDark) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
