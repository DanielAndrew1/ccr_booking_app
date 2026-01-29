// ignore_for_file: deprecated_member_use, use_build_context_synchronously, unnecessary_underscores, unused_element_parameter
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import '../../core/imports.dart';

class AddBooking extends StatefulWidget {
  final bool isRoot;
  const AddBooking({super.key, this.isRoot = false});

  @override
  State<AddBooking> createState() => _AddBookingState();
}

class _AddBookingState extends State<AddBooking> {
  final SupabaseClient supabase = Supabase.instance.client;

  Map<String, dynamic>? selectedClient;
  DateTime? pickupDate;
  DateTime? returnDate;
  List<Map<String, dynamic>?> selectedProducts = [null];

  final NumberFormat _currencyFormat = NumberFormat("#,##0", "en_US");

  // Logic: 29/1 to 29/1 = 0 days, 29/1 to 30/1 = 1 day
  int get totalDays {
    if (pickupDate == null || returnDate == null) return 0;
    final pDate = DateTime(
      pickupDate!.year,
      pickupDate!.month,
      pickupDate!.day,
    );
    final rDate = DateTime(
      returnDate!.year,
      returnDate!.month,
      returnDate!.day,
    );
    final difference = rDate.difference(pDate).inDays;
    return difference < 0 ? 0 : difference;
  }

  double get totalPrice {
    double sum = 0;
    for (var product in selectedProducts) {
      if (product != null) {
        sum += (double.tryParse(product['price'].toString()) ?? 0);
      }
    }
    return sum * totalDays;
  }

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
        'total_price': totalPrice,
      });

      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar("Booking Saved Successfully!", Colors.green);
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

  void _showCustomDatePicker({required bool isPickup}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Pickup min is Today. Return min is day after Pickup (or Tomorrow if Pickup not set).
    DateTime minSelectable = isPickup
        ? today
        : (pickupDate?.add(const Duration(days: 1)) ??
              today.add(const Duration(days: 1)));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CustomDatePickerSheet(
        minDate: minSelectable,
        initialDate: isPickup
            ? (pickupDate ?? today)
            : (returnDate ?? minSelectable),
        onDateSelected: (selectedDate) {
          setState(() {
            if (isPickup) {
              pickupDate = selectedDate;
              // DEFAULT LOGIC: Set return date to the day after pickup automatically
              returnDate = selectedDate.add(const Duration(days: 1));
            } else {
              returnDate = selectedDate;
            }
          });
        },
      ),
    );
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
                      leading: _buildImageOrIcon(imageUrl, isDark),
                      title: Text(
                        product['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        "${_currencyFormat.format(product['price'])} EGP/Day",
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Widget _buildImageOrIcon(
    String? imagePath,
    bool isDark, {
    double size = 40,
    Color? tintColor,
  }) {
    if (imagePath != null) {
      if (imagePath.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imagePath,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildPlaceholderIcon(isDark),
          ),
        );
      }
      return SvgPicture.asset(
        imagePath,
        width: size,
        height: size,
        colorFilter: tintColor != null
            ? ColorFilter.mode(tintColor, BlendMode.srcIn)
            : null,
      );
    }
    return _buildPlaceholderIcon(isDark);
  }

  Widget _buildPlaceholderIcon(bool isDark) {
    return SvgPicture.asset(
      "assets/box.svg",
      width: 32,
      height: 32,
      colorFilter: ColorFilter.mode(
        isDark ? Colors.white70 : Colors.black54,
        BlendMode.srcIn,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Container(
        color: isDark ? AppColors.darkbg : AppColors.lightcolor,
        child: Stack(
          children: [
            const CustomBgSvg(),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: CustomAppBar(
                text: "Add a Booking",
                showPfp: widget.isRoot,
              ),
              body: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
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
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF2A2A2A)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildImageOrIcon(imageUrl, isDark),
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
                                                      : Color(0xFF6A6A6A),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              if (product != null)
                                                Text(
                                                  "${_currencyFormat.format(product['price'])} EGP / Day",
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.w600,
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
                                    width: 50,
                                    height: 50,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary,
                                    ),
                                    child: Center(
                                      child: _buildImageOrIcon(
                                        "assets/add-square.svg",
                                        isDark,
                                        size: 28,
                                        tintColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                GestureDetector(
                                  onTap: () => setState(
                                    () => selectedProducts.removeAt(index),
                                  ),
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.3),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.red,
                                      size: 26,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    Text(
                      "Pickup Date",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _PickerTile(
                      imagePath: "assets/calendar.svg",
                      label: pickupDate == null
                          ? "Select Pickup Date"
                          : DateFormat('dd/MM/yyyy').format(pickupDate!),
                      onTap: () => _showCustomDatePicker(isPickup: true),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      "Return Date",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _PickerTile(
                      imagePath: "assets/calendar.svg",
                      label: returnDate == null
                          ? "Select Return Date"
                          : DateFormat('dd/MM/yyyy').format(returnDate!),
                      onTap: () => _showCustomDatePicker(isPickup: false),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.primary.withOpacity(0.1)
                            : AppColors.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isDark
                              ? AppColors.primary
                              : AppColors.secondary,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Duration:",
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                "$totalDays ${totalDays == 1 ? 'Day' : 'Days'}",
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Total Amount:",
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "${_currencyFormat.format(totalPrice)} EGP",
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.primary
                                      : AppColors.secondary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _saveBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          "Confirm Booking",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomDatePickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime minDate;
  final Function(DateTime) onDateSelected;

  const _CustomDatePickerSheet({
    required this.initialDate,
    required this.minDate,
    required this.onDateSelected,
  });

  @override
  State<_CustomDatePickerSheet> createState() => _CustomDatePickerSheetState();
}

class _CustomDatePickerSheetState extends State<_CustomDatePickerSheet> {
  late DateTime _selectedDay = DateTime(
    widget.initialDate.year,
    widget.initialDate.month,
    widget.initialDate.day,
  );
  late DateTime _displayedMonth = DateTime(
    widget.initialDate.year,
    widget.initialDate.month,
  );

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final primaryRed = AppColors.primary;

    final daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;
    final firstWeekday =
        DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday % 7;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: () => setState(() {
                  _selectedDay = widget.minDate;
                  _displayedMonth = DateTime(
                    widget.minDate.year,
                    widget.minDate.month,
                  );
                }),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryRed),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text("Reset", style: TextStyle(color: primaryRed)),
              ),
              IconButton(
                icon: const Icon(Icons.cancel_outlined),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: primaryRed),
                onPressed: () => setState(
                  () => _displayedMonth = DateTime(
                    _displayedMonth.year,
                    _displayedMonth.month - 1,
                  ),
                ),
              ),
              Text(
                DateFormat('MMMM yyyy').format(_displayedMonth),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryRed,
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: primaryRed),
                onPressed: () => setState(
                  () => _displayedMonth = DateTime(
                    _displayedMonth.year,
                    _displayedMonth.month + 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map(
                  (d) => Text(
                    d,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
              ),
              itemCount: daysInMonth + firstWeekday,
              itemBuilder: (context, index) {
                if (index < firstWeekday) return const SizedBox.shrink();
                int day = index - firstWeekday + 1;
                DateTime checkDate = DateTime(
                  _displayedMonth.year,
                  _displayedMonth.month,
                  day,
                );

                bool isPast = checkDate.isBefore(widget.minDate);
                bool isSelected =
                    _selectedDay.day == day &&
                    _selectedDay.month == _displayedMonth.month &&
                    _selectedDay.year == _displayedMonth.year;

                return GestureDetector(
                  onTap: isPast
                      ? null
                      : () => setState(() => _selectedDay = checkDate),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryRed : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: primaryRed.withOpacity(0.3),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        "$day",
                        style: TextStyle(
                          color: isPast
                              ? Colors.grey.withOpacity(0.4)
                              : (isSelected
                                    ? Colors.white
                                    : (isDark ? Colors.white : Colors.black87)),
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 15),
          Text(
            "Selected Date",
            style: TextStyle(color: isDark ? Colors.white70 : Colors.grey),
          ),
          Text(
            DateFormat('dd/MM/yyyy').format(_selectedDay),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () {
                widget.onDateSelected(_selectedDay);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                "Apply Date",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final String? imagePath;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  const _PickerTile({
    required this.label,
    required this.onTap,
    required this.isDark,
    this.imagePath,
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
          if (imagePath != null)
            CustomNavbar.buildIcon(
              imagePath: imagePath!,
              color: AppColors.primary,
              size: 20,
            ),
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
