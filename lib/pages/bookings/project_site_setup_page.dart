import 'package:site_lapse/core/imports.dart';

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
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _notesController = TextEditingController();
  final _serialController = TextEditingController();
  final _supabase = Supabase.instance.client;
  late final List<Map<String, dynamic>> _cameraProducts;
  String? _selectedProductId;
  List<Map<String, dynamic>> _installations = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cameraProducts = widget.products
        .where((product) => product['tracks_serial_numbers'] == true)
        .toList();
    _selectedProductId = _cameraProducts.isNotEmpty
        ? _cameraProducts.first['id'].toString()
        : null;
    _load();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    _serialController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final location = await _supabase
          .from('project_locations')
          .select()
          .eq('booking_id', widget.bookingId)
          .maybeSingle();
      final rows = await _supabase
          .from('camera_installations')
          .select('id, product_id, serial_number, notes')
          .eq('booking_id', widget.bookingId)
          .order('installed_at');
      if (!mounted) return;
      setState(() {
        _addressController.text = location?['address']?.toString() ?? '';
        _cityController.text = location?['city']?.toString() ?? '';
        _notesController.text = location?['notes']?.toString() ?? '';
        _installations = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addCamera() async {
    final serialNumber = _serialController.text.trim();
    if (_selectedProductId == null || serialNumber.isEmpty) {
      CustomSnackBar.show(
        context,
        'Choose a camera and enter its serial number.',
      );
      return;
    }
    try {
      await _supabase.from('camera_installations').insert({
        'booking_id': widget.bookingId,
        'product_id': _selectedProductId,
        'serial_number': serialNumber,
      });
      _serialController.clear();
      await _load();
    } catch (error) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          error.toString().contains('unique')
              ? 'This camera serial number is already assigned.'
              : 'Could not add this camera. Please try again.',
          color: AppColors.red,
        );
      }
    }
  }

  Future<void> _saveLocation() async {
    if (_addressController.text.trim().isEmpty) {
      CustomSnackBar.show(context, 'Enter the installation address first.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _supabase.from('project_locations').upsert({
        'booking_id': widget.bookingId,
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
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

  String _productName(String? productId) {
    for (final product in _cameraProducts) {
      if (product['id'].toString() == productId) {
        return product['name'].toString();
      }
    }
    return 'Camera';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: CustomAppBar(text: 'Site Setup', showPfp: false),
      body: _loading
          ? const Center(child: CustomLoader())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  widget.clientName,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _field(
                  _addressController,
                  'Installation address',
                  Icons.location_on_outlined,
                ),
                const SizedBox(height: 12),
                _field(
                  _cityController,
                  'City (optional)',
                  Icons.location_city_outlined,
                ),
                const SizedBox(height: 12),
                _field(
                  _notesController,
                  'Location notes (optional)',
                  Icons.notes_outlined,
                  maxLines: 3,
                ),
                const SizedBox(height: 14),
                CustomButton(
                  text: _saving ? 'Saving...' : 'Save Location',
                  color: WidgetStateProperty.all(AppColors.primary),
                  onPressed: _saving ? null : _saveLocation,
                ),
                const SizedBox(height: 32),
                Text(
                  'Installed cameras',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (_cameraProducts.isEmpty)
                  const Text(
                    'Mark camera products as “Track camera serials” in Inventory to assign them here.',
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedProductId,
                    decoration: const InputDecoration(
                      labelText: 'Camera product',
                    ),
                    items: _cameraProducts
                        .map(
                          (product) => DropdownMenuItem(
                            value: product['id'].toString(),
                            child: Text(product['name'].toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedProductId = value),
                  ),
                  const SizedBox(height: 12),
                  _field(
                    _serialController,
                    'Camera serial number',
                    Icons.qr_code_2_outlined,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _addCamera,
                    icon: const Icon(Icons.add),
                    label: const Text('Assign Camera'),
                  ),
                ],
                const SizedBox(height: 12),
                ..._installations.map(
                  (installation) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.videocam_outlined),
                      title: Text(installation['serial_number'].toString()),
                      subtitle: Text(
                        _productName(installation['product_id']?.toString()),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await _supabase
                              .from('camera_installations')
                              .delete()
                              .eq('id', installation['id']);
                          await _load();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) => TextField(
    controller: controller,
    maxLines: maxLines,
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
  );
}
