// ignore_for_file: deprecated_member_use, use_build_context_synchronously, unnecessary_underscores

import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/core/theme.dart';
import 'package:ccr_booking/widgets/custom_appbar.dart';
import 'package:ccr_booking/widgets/custom_search.dart';
import 'package:ccr_booking/widgets/custom_bg_svg.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddBooking extends StatefulWidget {
  const AddBooking({super.key});

  @override
  State<AddBooking> createState() => _AddBookingState();
}

class _AddBookingState extends State<AddBooking> {
  final SupabaseClient supabase = Supabase.instance.client;

  Map<String, dynamic>? selectedClient;
  DateTime? pickupDate;
  DateTime? returnDate;
  List<Map<String, dynamic>?> selectedProducts = [null];

  Future<void> _saveBooking() async {
    bool isProductsEmpty = !selectedProducts.any((p) => p != null);

    if (selectedClient == null ||
        pickupDate == null ||
        returnDate == null ||
        isProductsEmpty) {
      _showSnackBar("Please fill in all details", AppColors.primary);
      return;
    }

    if (returnDate!.isBefore(pickupDate!)) {
      _showSnackBar("Return date must be after pickup date", Colors.red);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final validSelection = selectedProducts
          .where((p) => p != null)
          .cast<Map<String, dynamic>>()
          .toList();
      final List<String> productIds = validSelection
          .map((p) => p['id'].toString())
          .toList();
      final List<String> productNames = validSelection
          .map((p) => p['name'].toString())
          .toList();

      await supabase.from('bookings').insert({
        'client_id': selectedClient!['id'].toString(),
        'client_name': selectedClient!['name'],
        'product_ids': productIds,
        'product_names': productNames,
        'pickup_datetime': pickupDate!.toIso8601String(),
        'return_datetime': returnDate!.toIso8601String(),
        'status': 'upcoming',
      });

      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar("Booking Saved Successfully!", Colors.green);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar("Error: ${e.toString()}", Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickDate({required bool isPickup}) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isPickup
          ? (pickupDate ?? DateTime.now())
          : (returnDate ?? pickupDate ?? DateTime.now()),
      firstDate: isPickup
          ? DateTime.now().subtract(const Duration(days: 30))
          : (pickupDate ?? DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: isDark
              ? const ColorScheme.dark(
                  primary: AppColors.primary,
                  surface: Color(0xFF1E1E1E),
                )
              : const ColorScheme.light(primary: AppColors.primary),
          dialogBackgroundColor: isDark
              ? const Color(0xFF1E1E1E)
              : Colors.white,
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => isPickup ? pickupDate = picked : returnDate = picked);
    }
  }

  void _showProductSearch(int index) async {
    final response = await supabase.from('products').select();
    List<Map<String, dynamic>> allProducts = List<Map<String, dynamic>>.from(
      response,
    );
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(20),
        child: StatefulBuilder(
          builder: (context, setModalState) => Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Select Product",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                decoration: InputDecoration(
                  hintText: "Search...",
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white10
                      : Colors.black12.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                onChanged: (val) => setModalState(() {
                  allProducts = List<Map<String, dynamic>>.from(response)
                      .where(
                        (p) => p['name'].toString().toLowerCase().contains(
                          val.toLowerCase(),
                        ),
                      )
                      .toList();
                }),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: ListView.separated(
                  itemCount: allProducts.length,
                  separatorBuilder: (_, __) => Divider(
                    color: isDark ? Colors.white12 : Colors.grey[300],
                  ),
                  itemBuilder: (context, i) {
                    final product = allProducts[i];
                    final imageUrl = product['image_url'] ?? product['image'];

                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageUrl != null
                            ? Image.network(
                                imageUrl,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildPlaceholderIcon(isDark),
                              )
                            : _buildPlaceholderIcon(isDark),
                      ),
                      title: Text(
                        product['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      subtitle: product['price'] != null
                          ? Text(
                              "${product['price']} EGP/Day",
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                      onTap: () {
                        setState(() => selectedProducts[index] = product);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon(bool isDark) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        color: isDark ? Colors.white70 : Colors.black54,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;

    return Container(
      color: isDark ? AppColors.darkbg : AppColors.lightcolor,
      child: Stack(
        children: [
          const CustomBgSvg(),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: const CustomAppBar(text: "Add a Booking", showPfp: false),
            body: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomSearch(
                    onClientSelected: (client) =>
                        setState(() => selectedClient = client),
                  ),
                  const SizedBox(height: 25),
                  Text(
                    "Products",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: selectedProducts.length,
                    itemBuilder: (context, index) {
                      bool isLast = index == selectedProducts.length - 1;
                      final product = selectedProducts[index];
                      final imageUrl =
                          product?['image_url'] ?? product?['image'];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _showProductSearch(index),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 15,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF2A2A2A)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: imageUrl != null
                                            ? Image.network(
                                                imageUrl,
                                                width: 40,
                                                height: 40,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => _buildPlaceholderIcon(
                                                      isDark,
                                                    ),
                                              )
                                            : _buildPlaceholderIcon(isDark),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product?['name'] ??
                                                  "Select Product",
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (product?['price'] != null)
                                              Text(
                                                "${product!['price']} EGP/Day",
                                                style: const TextStyle(
                                                  color: AppColors.primary,
                                                  fontSize: 14,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (isLast)
                              GestureDetector(
                                onTap: selectedProducts[index] != null
                                    ? () => setState(
                                        () => selectedProducts.add(null),
                                      )
                                    : null,
                                child: Container(
                                  width: 45,
                                  height: 45,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: selectedProducts[index] != null
                                        ? AppColors.primary
                                        : AppColors.primary.withOpacity(0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            else
                              GestureDetector(
                                onTap: () => setState(
                                  () => selectedProducts.removeAt(index),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  Text(
                    "Pickup Details",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PickerTile(
                    icon: Icons.calendar_today,
                    label: pickupDate == null
                        ? "Select Pickup Date"
                        : DateFormat('MMM dd, yyyy').format(pickupDate!),
                    onTap: () => _pickDate(isPickup: true),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Return Details",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PickerTile(
                    icon: Icons.event_available,
                    label: returnDate == null
                        ? "Select Return Date"
                        : DateFormat('MMM dd, yyyy').format(returnDate!),
                    onTap: () => _pickDate(isPickup: false),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveBooking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Confirm Booking",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF2A2A2A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}
