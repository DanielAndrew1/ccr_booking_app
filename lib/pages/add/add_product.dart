// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'package:path/path.dart' as p;
import 'package:site_lapse/core/imports.dart';

class AddProduct extends StatefulWidget {
  final bool isRoot; // Logic to determine if this is a main tab in Navbar
  final String? productId;
  const AddProduct({super.key, this.isRoot = false, this.productId});

  @override
  State<AddProduct> createState() => _AddProductState();
}

class _AddProductState extends State<AddProduct> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  bool _isUnlimited = false;
  bool _tracksSerialNumbers = false;
  final List<TextEditingController> _serialControllers = [];
  final List<String?> _serialIds = [];
  final List<bool> _serialMaintenance = [];
  String? _existingImageUrl;
  bool _loading = false;

  bool get _isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() => _loading = true);
    try {
      final supabase = Supabase.instance.client;
      final product = await supabase
          .from('products')
          .select()
          .eq('id', widget.productId!)
          .single();
      final serials = await supabase
          .from('product_serials')
          .select('id, serial_number, is_maintenance')
          .eq('product_id', widget.productId!)
          .eq('is_retired', false)
          .order('created_at');
      if (!mounted) return;
      _nameController.text = product['name']?.toString() ?? '';
      _quantityController.text = '${product['quantity'] ?? 0}';
      _isUnlimited = product['is_unlimited'] == true;
      _tracksSerialNumbers = product['tracks_serial_numbers'] == true;
      _existingImageUrl = product['image_url']?.toString();
      for (final row in List<Map<String, dynamic>>.from(serials)) {
        _serialControllers.add(
          TextEditingController(text: row['serial_number']?.toString() ?? ''),
        );
        _serialIds.add(row['id']?.toString());
        _serialMaintenance.add(row['is_maintenance'] == true);
      }
      _syncSerialFields();
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      CustomSnackBar.show(context, 'Could not load this product.');
    }
  }

  File? _imageFile;

  void _syncSerialFields() {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final target = _tracksSerialNumbers && !_isUnlimited ? quantity : 0;
    while (_serialControllers.length < target) {
      _serialControllers.add(TextEditingController());
      _serialIds.add(null);
      _serialMaintenance.add(false);
    }
    while (_serialControllers.length > target) {
      _serialControllers.removeLast().dispose();
      _serialIds.removeLast();
      _serialMaintenance.removeLast();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    for (final controller in _serialControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );

    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
  }

  Future<void> _removeSoldSerial(int index) async {
    final serial = _serialControllers[index].text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove sold item?'),
        content: Text(
          'Serial ${serial.isEmpty ? index + 1 : serial} will be removed from available inventory and kept in project history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final serialId = _serialIds[index];
    final nextQuantity = ((int.tryParse(_quantityController.text) ?? 1) - 1)
        .clamp(0, 999999);
    try {
      if (serialId != null) {
        final assignments = await Supabase.instance.client
            .from('booking_serial_assignments')
            .select('bookings(status)')
            .eq('product_serial_id', serialId);
        final inCurrentProject = (assignments as List).any((raw) {
          final booking = (raw as Map)['bookings'] as Map?;
          final status = booking?['status']?.toString();
          return status != null &&
              status != 'completed' &&
              status != 'cancelled';
        });
        if (inCurrentProject) {
          if (mounted) {
            CustomSnackBar.show(
              context,
              'This serial is assigned to a current project and cannot be removed yet.',
            );
          }
          return;
        }
        await Supabase.instance.client
            .from('product_serials')
            .update({'is_retired': true})
            .eq('id', serialId);
        await Supabase.instance.client
            .from('products')
            .update({'quantity': nextQuantity})
            .eq('id', widget.productId!);
      }
      if (!mounted) return;
      setState(() {
        _serialControllers.removeAt(index).dispose();
        _serialIds.removeAt(index);
        _serialMaintenance.removeAt(index);
        _quantityController.text = '$nextQuantity';
      });
      CustomSnackBar.show(
        context,
        'Sold item removed from available inventory.',
        color: AppColors.green,
      );
    } catch (_) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          'Could not remove this serial. Run the latest Supabase SQL first.',
        );
      }
    }
  }

  Future<void> _saveProduct() async {
    final name = _nameController.text.trim();
    final quantityText = _quantityController.text.trim();

    if (name.isEmpty ||
        (!_isUnlimited && quantityText.isEmpty) ||
        _imageFile == null && _existingImageUrl == null) {
      CustomSnackBar.show(
        context,
        'Please fill all fields and select an image',
        color: AppColors.red,
      );
      return;
    }
    final serials = _serialControllers.map((c) => c.text.trim()).toList();
    if (_tracksSerialNumbers &&
        (serials.any((serial) => serial.isEmpty) ||
            serials.toSet().length != serials.length)) {
      CustomSnackBar.show(
        context,
        'Enter a unique serial number for every item.',
        color: AppColors.red,
      );
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      var imageUrl = _existingImageUrl;
      if (_imageFile != null) {
        final fileName =
            "${DateTime.now().millisecondsSinceEpoch}${p.extension(_imageFile!.path)}";
        await supabase.storage
            .from('product-images')
            .upload(
              fileName,
              _imageFile!,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );
        imageUrl = supabase.storage
            .from('product-images')
            .getPublicUrl(fileName);
      }

      final values = <String, dynamic>{
        'name': name,
        if (!_isEditing) 'price': 0,
        'quantity': _isUnlimited ? 0 : int.parse(quantityText),
        'is_unlimited': _isUnlimited,
        'tracks_serial_numbers': _tracksSerialNumbers,
        'image_url': imageUrl,
      };
      late String productId;
      if (_isEditing) {
        productId = widget.productId!;
        await supabase.from('products').update(values).eq('id', productId);
      } else {
        final product = await supabase
            .from('products')
            .insert(values)
            .select('id')
            .single();
        productId = product['id'].toString();
      }
      for (var i = 0; i < serials.length; i++) {
        final values = {
          'product_id': productId,
          'serial_number': serials[i],
          'is_maintenance': _serialMaintenance[i],
        };
        if (_serialIds[i] == null) {
          await supabase.from('product_serials').insert(values);
        } else {
          await supabase
              .from('product_serials')
              .update(values)
              .eq('id', _serialIds[i]!);
        }
      }

      if (mounted) {
        CustomSnackBar.show(
          context,
          _isEditing
              ? 'Product updated successfully!'
              : 'Product saved successfully!',
          color: AppColors.green,
        );
        if (_isEditing) {
          Navigator.pop(context, true);
          return;
        }
        _nameController.clear();
        _quantityController.clear();
        setState(() {
          _imageFile = null;
          _isUnlimited = false;
          _tracksSerialNumbers = false;
          for (final controller in _serialControllers) {
            controller.dispose();
          }
          _serialControllers.clear();
          _serialIds.clear();
          _serialMaintenance.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          'Error: ${e.toString()}',
          color: AppColors.red,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
        extendBodyBehindAppBar: true,
        appBar: CustomAppBar(
          text: _isEditing ? 'Edit Product' : 'Add Product',
          // Show PFP/Initials ONLY if this page is a root tab in Navbar
          showPfp: widget.isRoot,
        ),
        body: _loading
            ? const Center(child: CustomLoader())
            : Stack(
                children: [
                  const CustomBgSvg(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        const SizedBox(height: 20), // Space for AppBar height
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                              image: _imageFile != null
                                  ? DecorationImage(
                                      image: FileImage(_imageFile!),
                                      fit: BoxFit.cover,
                                    )
                                  : (_existingImageUrl != null
                                        ? DecorationImage(
                                            image: NetworkImage(
                                              _existingImageUrl!,
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null),
                            ),
                            child:
                                _imageFile == null && _existingImageUrl == null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_a_photo,
                                        size: 40,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black38,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Tap to select product image",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black38,
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildThemedTextField(
                          controller: _nameController,
                          label: 'Product Name',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        if (!_isUnlimited) ...[
                          _buildThemedTextField(
                            controller: _quantityController,
                            label: 'Quantity',
                            isDark: isDark,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(_syncSerialFields),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (!_tracksSerialNumbers)
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Unlimited availability'),
                            subtitle: const Text(
                              'Use for cloud subscriptions or services',
                            ),
                            value: _isUnlimited,
                            activeColor: AppColors.primary,
                            onChanged: (value) => setState(() {
                              _isUnlimited = value;
                              if (value) _tracksSerialNumbers = false;
                              _syncSerialFields();
                            }),
                          ),
                        if (!_isUnlimited)
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Track camera serials'),
                            subtitle: const Text(
                              'Assign serials when creating projects',
                            ),
                            value: _tracksSerialNumbers,
                            activeColor: AppColors.primary,
                            onChanged: (value) => setState(() {
                              _tracksSerialNumbers = value;
                              if (value) _isUnlimited = false;
                              _syncSerialFields();
                            }),
                          ),
                        if (_tracksSerialNumbers &&
                            _serialControllers.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...List.generate(_serialControllers.length, (index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: _buildThemedTextField(
                                          controller: _serialControllers[index],
                                          label: 'Serial ${index + 1}',
                                          isDark: isDark,
                                        ),
                                      ),
                                      if (_isEditing) ...[
                                        const SizedBox(width: 16),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Active',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Switch.adaptive(
                                              value: !_serialMaintenance[index],
                                              activeColor: AppColors.primary,
                                              onChanged: (value) => setState(
                                                () =>
                                                    _serialMaintenance[index] =
                                                        !value,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (_isEditing)
                                    TextButton.icon(
                                      onPressed: () => _removeSoldSerial(index),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.red,
                                        padding: EdgeInsets.zero,
                                      ),
                                      icon: SvgPicture.asset(
                                        AppIcons.trash,
                                        width: 20,
                                        colorFilter: const ColorFilter.mode(
                                          AppColors.red,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                      label: const Text('Delete item'),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                        const SizedBox(height: 32),
                        CustomButton(
                          text: _isEditing ? 'Update Product' : 'Save Product',
                          color: WidgetStateProperty.all(AppColors.primary),
                          onPressed: _saveProduct,
                          height: 50,
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildThemedTextField({
    required TextEditingController controller,
    required String label,
    required bool isDark,
    String? suffix,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      cursorColor: AppColors.primary,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        suffixStyle: const TextStyle(
          color: AppColors.primary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : Colors.black12,
          ),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        floatingLabelStyle: const TextStyle(color: AppColors.primary),
      ),
    );
  }
}
