// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'package:path/path.dart' as p;
import '../../core/imports.dart';

class AddProduct extends StatefulWidget {
  final bool isRoot; // Logic to determine if this is a main tab in Navbar
  const AddProduct({super.key, this.isRoot = false});

  @override
  State<AddProduct> createState() => _AddProductState();
}

class _AddProductState extends State<AddProduct> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  File? _imageFile;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 120,
    );

    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
  }

  Future<void> _saveProduct() async {
    final name = _nameController.text.trim();
    final priceText = _priceController.text.trim();
    final description = _descriptionController.text.trim();
    final quantityText = _quantityController.text.trim();

    if (name.isEmpty ||
        priceText.isEmpty ||
        description.isEmpty ||
        quantityText.isEmpty ||
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
        'price': double.parse(priceText),
        'description': description,
        'quantity': int.parse(quantityText),
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
        _priceController.clear();
        _descriptionController.clear();
        _quantityController.clear();
        setState(() => _imageFile = null);
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

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
                  _buildThemedTextField(
                    controller: _priceController,
                    label: 'Price',
                    isDark: isDark,
                    suffix: 'EGP/Day',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _buildThemedTextField(
                    controller: _quantityController,
                    label: 'Quantity',
                    isDark: isDark,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _buildThemedTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    isDark: isDark,
                    maxLines: 4,
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
