import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/widgets/custom_appbar.dart';
import 'package:ccr_booking/widgets/custom_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddBooking extends StatefulWidget {
  const AddBooking({super.key});

  @override
  State<AddBooking> createState() => _AddBookingState();
}

class _AddBookingState extends State<AddBooking> {
  final SupabaseClient supabase = Supabase.instance.client;

  // Form State
  Map<String, dynamic>? selectedClient;
  DateTime? pickupDate;
  TimeOfDay? pickupTime;
  DateTime? returnDate;
  TimeOfDay? returnTime;
  List<Map<String, dynamic>?> selectedProducts = [null];

  // --- SAVE TO SUPABASE WITH AVAILABILITY CHECK ---
  Future<void> _saveBooking() async {
    // 1. Basic Validation
    bool isProductsEmpty = !selectedProducts.any((p) => p != null);

    if (selectedClient == null ||
        pickupDate == null ||
        pickupTime == null ||
        returnDate == null ||
        returnTime == null ||
        isProductsEmpty) {
      _showSnackBar(
        "Please fill in all details and select products",
        AppColors.primary,
      );
      return;
    }

    // 2. Prepare Timestamps
    final DateTime fullPickup = DateTime(
      pickupDate!.year,
      pickupDate!.month,
      pickupDate!.day,
      pickupTime!.hour,
      pickupTime!.minute,
    );

    final DateTime fullReturn = DateTime(
      returnDate!.year,
      returnDate!.month,
      returnDate!.day,
      returnTime!.hour,
      returnTime!.minute,
    );

    // 3. Validation: Return must be after Pickup
    if (fullReturn.isBefore(fullPickup)) {
      _showSnackBar("Return date must be after pickup date", Colors.red);
      return;
    }

    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Filter valid selections
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

      // --- STEP 1: AVAILABILITY CHECK ---
      final existingBookings = await supabase
          .from('bookings')
          .select('product_ids, client_name')
          .filter('pickup_datetime', 'lt', fullReturn.toIso8601String())
          .filter('return_datetime', 'gt', fullPickup.toIso8601String())
          .overlaps('product_ids', productIds);

      if ((existingBookings as List).isNotEmpty) {
        if (!mounted) return;
        Navigator.pop(context); // Close loader

        List<String> conflicts = [];
        for (var booking in existingBookings) {
          final clientName = booking['client_name'] ?? "Another Client";
          List<String> bookedProductIds = List<String>.from(
            booking['product_ids'],
          );

          for (var myProduct in validSelection) {
            if (bookedProductIds.contains(myProduct['id'].toString())) {
              conflicts.add("${myProduct['name']} - $clientName");
            }
          }
        }

        _showConflictAlert(conflicts.toSet().toList());
        return;
      }

      // --- STEP 2: PROCEED WITH BOOKING ---
      // We use the new columns: client_id (UUID string), client_name, product_ids (Array), product_names (Array)
      await supabase.from('bookings').insert({
        'client_id': selectedClient!['id'],
        'client_name': selectedClient!['name'],
        'product_ids': productIds,
        'product_names': productNames,
        'pickup_datetime': fullPickup.toIso8601String(),
        'return_datetime': fullReturn.toIso8601String(),
        'status': 'upcoming',
      });

      if (!mounted) return;
      Navigator.pop(context); // Close loader
      _showSnackBar("Booking Saved Successfully!", Colors.green);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar("Error: ${e.toString()}", Colors.red);
    }
  }

  // --- HELPERS ---
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showConflictAlert(List<String> conflicts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Availability Conflict"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "The following items are already booked for this time range:",
            ),
            const SizedBox(height: 15),
            ...conflicts.map(
              (c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  "• $c",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Back"),
          ),
        ],
      ),
    );
  }

  // --- DATE & TIME PICKERS ---
  Future<void> _pickDateTime({
    required bool isPickup,
    required bool isDate,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDate) {
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
          ),
          child: child!,
        ),
      );
      if (picked != null)
        setState(() => isPickup ? pickupDate = picked : returnDate = picked);
    } else {
      TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppColors.primary,
                    surface: Color(0xFF1E1E1E),
                  )
                : const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        ),
      );
      if (picked != null)
        setState(() => isPickup ? pickupTime = picked : returnTime = picked);
    }
  }

  // --- PRODUCT SEARCH MODAL ---
  void _showProductSearch(int index) async {
    final response = await supabase.from('products').select();
    List<Map<String, dynamic>> allProducts = List<Map<String, dynamic>>.from(
      response,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Select Product",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              TextField(
                decoration: InputDecoration(
                  hintText: "Search...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setModalState(
                  () => allProducts = List<Map<String, dynamic>>.from(response)
                      .where(
                        (p) => p['name'].toString().toLowerCase().contains(
                          val.toLowerCase(),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: ListView.separated(
                  itemCount: allProducts.length,
                  separatorBuilder: (_, __) => Divider(
                    color: isDark ? Colors.white10 : Colors.grey[200],
                  ),
                  itemBuilder: (context, i) => ListTile(
                    title: Text(
                      allProducts[i]['name'],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      setState(() => selectedProducts[index] = allProducts[i]);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: CustomAppBar(text: "Add a Booking", showPfp: false),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomSearch(
              onClientSelected: (client) =>
                  setState(() => selectedClient = client),
            ),
            const SizedBox(height: 25),
            const Text(
              "Products",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: selectedProducts.length,
              itemBuilder: (context, index) {
                bool isLast = index == selectedProducts.length - 1;
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
                              border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 20,
                                  color: selectedProducts[index] == null
                                      ? Colors.grey
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    selectedProducts[index]?['name'] ??
                                        "Select Product",
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
                          onTap: () =>
                              setState(() => selectedProducts.add(null)),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () =>
                              setState(() => selectedProducts.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
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
            const SizedBox(height: 20),
            const Text(
              "Pickup Details",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    icon: Icons.calendar_today,
                    label: pickupDate == null
                        ? "Date"
                        : DateFormat('MMM dd, yyyy').format(pickupDate!),
                    onTap: () => _pickDateTime(isPickup: true, isDate: true),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _PickerTile(
                    icon: Icons.access_time,
                    label: pickupTime == null
                        ? "Time"
                        : pickupTime!.format(context),
                    onTap: () => _pickDateTime(isPickup: true, isDate: false),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              "Return Details",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    icon: Icons.event_available,
                    label: returnDate == null
                        ? "Date"
                        : DateFormat('MMM dd, yyyy').format(returnDate!),
                    onTap: () => _pickDateTime(isPickup: false, isDate: true),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _PickerTile(
                    icon: Icons.history,
                    label: returnTime == null
                        ? "Time"
                        : returnTime!.format(context),
                    onTap: () => _pickDateTime(isPickup: false, isDate: false),
                    isDark: isDark,
                  ),
                ),
              ],
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
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}
