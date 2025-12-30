import 'dart:typed_data';
import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/widgets/custom_appbar.dart';
import 'package:ccr_booking/widgets/custom_button.dart';
import 'package:ccr_booking/widgets/custom_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductPage extends StatefulWidget {
  final String productId;

  const ProductPage({super.key, required this.productId});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  String? name;
  String? description;
  String? imageUrl;
  int? price;
  int? quantity;
  bool isLoading = true;
  bool isAdmin = false;
  String? error;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await Future.wait([_fetchProduct(), _checkAdmin()]);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();
      if (!mounted) return;
      setState(() {
        isAdmin = data['role']?.toString().toLowerCase() == 'admin' || data['role']?.toString().toLowerCase() == 'owner';
      });
    } catch (e) {
      debugPrint("Admin Check Error: $e");
    }
  }

  Future<void> _fetchProduct() async {
    try {
      final data = await Supabase.instance.client
          .from('products')
          .select()
          .eq('id', widget.productId)
          .single();

      if (!mounted) return;

      setState(() {
        name = data['name'];
        description = data['description'];
        imageUrl = data['image_url'];
        price = (data['price'] as num?)?.toInt();
        quantity = (data['quantity'] as num?)?.toInt() ?? 0;

        _nameController.text = name ?? '';
        _descriptionController.text = description ?? '';
        _priceController.text = price?.toString() ?? '';
        _quantityController.text = quantity?.toString() ?? '';
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _editProduct() async {
    Uint8List? newImageBytes;
    final picker = ImagePicker();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Edit Product',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Image Picker UI
                      GestureDetector(
                        onTap: () async {
                          final XFile? pickedFile = await picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (pickedFile != null) {
                            final bytes = await pickedFile.readAsBytes();
                            if (context.mounted) {
                              setDialogState(() => newImageBytes = bytes);
                            }
                          }
                        },
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                            image: newImageBytes != null
                                ? DecorationImage(
                                    image: MemoryImage(newImageBytes!),
                                    fit: BoxFit.cover,
                                  )
                                : (imageUrl != null && imageUrl!.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(imageUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null),
                          ),
                          child:
                              newImageBytes == null &&
                                  (imageUrl == null || imageUrl!.isEmpty)
                              ? const Icon(
                                  Icons.add_a_photo,
                                  size: 40,
                                  color: Colors.grey,
                                )
                              : Align(
                                  alignment: Alignment.bottomRight,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    margin: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      _buildTextField(
                        _nameController,
                        TextCapitalization.words,
                        'Product Name',
                        Icons.edit,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 15),
                      _buildTextField(
                        _descriptionController,
                        TextCapitalization.sentences,
                        'Description',
                        Icons.description,
                        maxLines: 3,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              _priceController,
                              TextCapitalization.none,
                              'Price',
                              Icons.attach_money,
                              isNum: true,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTextField(
                              _quantityController,
                              TextCapitalization.none,
                              'Total Quantity',
                              Icons.numbers,
                              isNum: true,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: isDark ? Colors.white24 : Colors.grey,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.pop(context),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (context.mounted)
                                        setDialogState(() => isSaving = true);
                                      try {
                                        String? finalImageUrl = imageUrl;

                                        if (newImageBytes != null) {
                                          final fileName =
                                              'product_${DateTime.now().millisecondsSinceEpoch}.jpg';

                                          await Supabase.instance.client.storage
                                              .from('product-images')
                                              .uploadBinary(
                                                fileName,
                                                newImageBytes!,
                                              );

                                          finalImageUrl = Supabase
                                              .instance
                                              .client
                                              .storage
                                              .from('product-images')
                                              .getPublicUrl(fileName);
                                        }

                                        await Supabase.instance.client
                                            .from('products')
                                            .update({
                                              'name': _nameController.text
                                                  .trim(),
                                              'description':
                                                  _descriptionController.text
                                                      .trim(),
                                              'price':
                                                  int.tryParse(
                                                    _priceController.text,
                                                  ) ??
                                                  0,
                                              'quantity':
                                                  int.tryParse(
                                                    _quantityController.text,
                                                  ) ??
                                                  0,
                                              'image_url': finalImageUrl,
                                            })
                                            .eq('id', widget.productId);

                                        await _fetchProduct();

                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Product updated!'),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          setDialogState(
                                            () => isSaving = false,
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              child: isSaving
                                  ? const CustomLoader(size: 24)
                                  : const Text(
                                      'Update',
                                      style: TextStyle(color: Colors.white),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    TextCapitalization textCap,
    String label,
    IconData icon, {
    int maxLines = 1,
    bool isNum = false,
    required bool isDark,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: textCap,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      inputFormatters: isNum ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: isDark,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          'Confirm Delete',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Text(
          'Are you sure you want to delete this product?',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Supabase.instance.client
                  .from('products')
                  .delete()
                  .eq('id', widget.productId);
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: CustomAppBar(text: name ?? 'Product', showPfp: false),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isLoading
            ? const Center(child: CustomLoader())
            : error != null
            ? Center(
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 250,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: (imageUrl != null && imageUrl!.isNotEmpty)
                            ? Image.network(
                                imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) =>
                                    const Icon(Icons.broken_image, size: 50),
                              )
                            : const Icon(
                                Icons.image,
                                size: 50,
                                color: AppColors.primary,
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name ?? '',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        Text(
                          '${price ?? 0} EGP/Day',
                          style: const TextStyle(
                            fontSize: 20,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (isAdmin)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Total Quantity: $quantity',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.grey[700],
                          ),
                        ),
                      ),
                    const SizedBox(height: 15),
                    Text(
                      description ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 40),
                    if (isAdmin) ...[
                      CustomButton(
                        text: 'Edit Product',
                        icon: Icons.edit,
                        color: WidgetStateProperty.all(AppColors.primary),
                        onPressed: _editProduct,
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: 'Delete Product',
                        icon: Icons.delete,
                        color: WidgetStateProperty.all(Colors.red),
                        onPressed: _confirmDelete,
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
