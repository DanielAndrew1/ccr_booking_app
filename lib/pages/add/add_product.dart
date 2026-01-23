// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/core/theme.dart';
import 'package:ccr_booking/widgets/custom_appbar.dart';
import 'package:ccr_booking/widgets/custom_button.dart';
import 'package:ccr_booking/widgets/custom_loader.dart';
import 'package:ccr_booking/widgets/custom_bg_svg.dart'; // Import your reusable widget
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class AddProduct extends StatefulWidget {
  const AddProduct({super.key});

  @override
  State<AddProduct> createState() => _AddProductState();
}

class _AddProductState extends State<AddProduct> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  File? _imageFile;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and select an image'),
        ),
      );
      return;
    }

    final price = double.tryParse(priceText);
    final quantity = int.tryParse(quantityText);

    if (price == null || quantity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid price and quantity'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      final fileExtension = p.extension(_imageFile!.path);
      final fileName = "${DateTime.now().millisecondsSinceEpoch}$fileExtension";
      final imagePath = fileName;

      await supabase.storage
          .from('product-images')
          .upload(
            imagePath,
            _imageFile!,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final String imageUrl = supabase.storage
          .from('product-images')
          .getPublicUrl(imagePath);

      await supabase.from('products').insert({
        'name': name,
        'price': price,
        'description': description,
        'quantity': quantity,
        'image_url': imageUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product saved successfully!')),
        );
      }

      _nameController.clear();
      _priceController.clear();
      _descriptionController.clear();
      _quantityController.clear();
      setState(() {
        _imageFile = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving product: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      extendBodyBehindAppBar: true, // Required for CustomBgSvg alignment
      appBar: const CustomAppBar(text: "Add a Product", showPfp: false),
      body: Stack(
        children: [
          const CustomBgSvg(), // Decoration layer

          _isLoading
              ? const Center(child: CustomLoader())
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Image Picker UI
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white24
                                  : Colors.grey.shade400,
                            ),
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
                                          : Colors.grey,
                                    ),
                                    Text(
                                      "Add Product Image",
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey,
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
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 12),
                      _buildThemedTextField(
                        controller: _priceController,
                        label: 'Price',
                        suffix: 'EGP / Day',
                        isDark: isDark,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _buildThemedTextField(
                        controller: _quantityController,
                        label: 'Quantity',
                        isDark: isDark,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _buildThemedTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        isDark: isDark,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                      ),
                      const SizedBox(height: 32),
                      CustomButton(
                        text: "Save Product",
                        color: WidgetStateProperty.all(AppColors.primary),
                        onPressed: _saveProduct,
                      ),
                    ],
                  ),
                ),
        ],
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
        suffixStyle: const TextStyle(color: Colors.grey),
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
