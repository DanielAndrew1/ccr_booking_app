// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'package:path/path.dart' as p;
import 'package:site_lapse/core/imports.dart';

class AddProduct extends StatefulWidget {
  final bool isRoot; // Logic to determine if this is a main tab in Navbar
  const AddProduct({super.key, this.isRoot = false});

  @override
  State<AddProduct> createState() => _AddProductState();
}

class _AddProductState extends State<AddProduct> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  bool _isUnlimited = false;
  bool _tracksSerialNumbers = false;

  File? _imageFile;

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

  Future<void> _saveProduct() async {
    final name = _nameController.text.trim();
    final quantityText = _quantityController.text.trim();

    if (name.isEmpty ||
        (!_isUnlimited && quantityText.isEmpty) ||
        _imageFile == null) {
      CustomSnackBar.show(
        context,
        'Please fill all fields and select an image',
        color: AppColors.red,
      );
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      // 1. Upload Image
      final fileName =
          "${DateTime.now().millisecondsSinceEpoch}${p.extension(_imageFile!.path)}";
      await supabase.storage
          .from('product-images')
          .upload(
            fileName,
            _imageFile!,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      // 2. Get Public URL
      final String imageUrl = supabase.storage
          .from('product-images')
          .getPublicUrl(fileName);

      // 3. Save to Database
      await supabase.from('products').insert({
        'name': name,
        'price': 0,
        'quantity': _isUnlimited ? 0 : int.parse(quantityText),
        'is_unlimited': _isUnlimited,
        'tracks_serial_numbers': _tracksSerialNumbers,
        'image_url': imageUrl,
      });

      if (mounted) {
        CustomSnackBar.show(
          context,
          'Product saved successfully!',
          color: AppColors.green,
        );
        // Clear fields
        _nameController.clear();
        _quantityController.clear();
        setState(() {
          _imageFile = null;
          _isUnlimited = false;
          _tracksSerialNumbers = false;
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
          text: "Add Product",
          // Show PFP/Initials ONLY if this page is a root tab in Navbar
          showPfp: widget.isRoot,
        ),
        body: Stack(
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
                            : null,
                      ),
                      child: _imageFile == null
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
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Unlimited availability'),
                    subtitle: const Text(
                      'Use for cloud subscriptions or services',
                    ),
                    value: _isUnlimited,
                    activeColor: AppColors.primary,
                    onChanged: (value) => setState(() => _isUnlimited = value),
                  ),
                  if (!_isUnlimited) ...[
                    const SizedBox(height: 8),
                    _buildThemedTextField(
                      controller: _quantityController,
                      label: 'Quantity',
                      isDark: isDark,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Track camera serials'),
                    subtitle: const Text(
                      'Assign each installed camera to a client',
                    ),
                    value: _tracksSerialNumbers,
                    activeColor: AppColors.primary,
                    onChanged: (value) =>
                        setState(() => _tracksSerialNumbers = value),
                  ),
                  const SizedBox(height: 32),
                  CustomButton(
                    text: "Save Product",
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
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
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
