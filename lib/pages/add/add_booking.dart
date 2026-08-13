// ignore_for_file: deprecated_member_use, use_build_context_synchronously, unnecessary_underscores, unused_element_parameter
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:site_lapse/core/imports.dart';

class AddBooking extends StatefulWidget {
  final bool isRoot;
  const AddBooking({super.key, this.isRoot = false});

  @override
  State<AddBooking> createState() => _AddBookingState();
}

class _AddBookingState extends State<AddBooking> {
  final SupabaseClient supabase = Supabase.instance.client;

  // Added key to control the CustomSearch state
  final GlobalKey<CustomSearchState> _searchKey =
      GlobalKey<CustomSearchState>();

  Map<String, dynamic>? selectedClient;
  DateTime? pickupDate;
  DateTime? returnDate;
  List<Map<String, dynamic>?> selectedProducts = [null];
  final _projectPriceController = TextEditingController();
  final _installmentController = TextEditingController();
  final _downPaymentController = TextEditingController();
  String? _paymentPlanType;
  String _paymentFrequency = 'month';
  int _paymentInterval = 1;
  File? _contractImage;
  int _currentStep = 0;

  final NumberFormat _currencyFormat = NumberFormat("#,##0", "en_US");

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

  String get projectDuration => _formatDuration(pickupDate, returnDate);

  double get totalPrice {
    return selectedProducts.whereType<Map<String, dynamic>>().fold(0, (
      sum,
      product,
    ) {
      final value = product['project_price'] ?? product['price'] ?? 0;
      return sum +
          (value is num ? value.toDouble() : double.tryParse('$value') ?? 0);
    });
  }

  Future<void> _previewQuote() async {
    if (selectedClient == null ||
        pickupDate == null ||
        returnDate == null ||
        totalPrice <= 0 ||
        _paymentPlanType == null) {
      CustomSnackBar.show(
        context,
        'Add the client, dates, price, and payment plan first',
      );
      return;
    }
    final bytes = await ProjectQuoteService.buildQuote(
      projectId: 'preview00',
      clientName: selectedClient!['name'].toString(),
      startDate: pickupDate!,
      endDate: returnDate!,
      products: selectedProducts.whereType<Map<String, dynamic>>().toList(),
      totalAmount: totalPrice,
      paymentPlanType: _paymentPlanType!,
      paymentFrequency: _paymentFrequency,
      paymentInterval: _paymentInterval,
      installmentAmount:
          double.tryParse(_installmentController.text.trim()) ?? totalPrice,
      downPaymentAmount:
          double.tryParse(_downPaymentController.text.trim()) ?? 0,
    );
    if (!mounted) return;
    final fileName =
        '${selectedClient!['name'].toString().trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '').toLowerCase()}-quote-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: CustomAppBar(
            text: 'Quote preview',
            showPfp: false,
            actions: [
              IconButton(
                tooltip: 'Share quote',
                icon: Icon(Icons.adaptive.share_outlined),
                onPressed: () =>
                    Printing.sharePdf(bytes: bytes, filename: fileName),
              ),
            ],
          ),
          body: PdfPreview(
            build: (_) async => bytes,
            canChangePageFormat: false,
            useActions: false,
            allowPrinting: false,
            allowSharing: false,
          ),
        ),
      ),
    );
  }

  String _friendlyProjectError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('booking_items') &&
        message.contains('row-level security')) {
      return 'Project saved, but its products could not be linked. Run the booking-items SQL policy fix in Supabase.';
    }
    if (message.contains('down_payment_amount') ||
        message.contains('payment_plan_type')) {
      return 'Your database needs the latest project payment SQL update in Supabase.';
    }
    if (message.contains('row-level security')) {
      return 'You do not have permission to complete this action. Check the Supabase table policies.';
    }
    if (message.contains('network') || message.contains('socket')) {
      return 'Could not reach the server. Check your internet connection and try again.';
    }
    return 'Could not save the project. Please try again.';
  }

  Future<void> _saveBooking() async {
    bool isProductsEmpty = !selectedProducts.any((p) => p != null);

    if (selectedClient == null ||
        pickupDate == null ||
        returnDate == null ||
        isProductsEmpty ||
        _paymentPlanType == null ||
        totalPrice <= 0) {
      CustomSnackBar.show(context, "Please fill in all details");
      return;
    }

    if (returnDate!.isBefore(pickupDate!)) {
      CustomSnackBar.show(context, "Return date must be after pickup date");
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CustomLoader()),
    );

    try {
      final validSelection = selectedProducts
          .where((p) => p != null)
          .cast<Map<String, dynamic>>()
          .toList();

      for (var product in validSelection) {
        final String productId = product['id'].toString();
        if (product['is_unlimited'] == true) continue;
        final int totalQuantity =
            int.tryParse(product['quantity']?.toString() ?? '1') ?? 1;

        int countInCurrent = validSelection
            .where((p) => p['id'].toString() == productId)
            .length;

        if (countInCurrent > totalQuantity) {
          Navigator.pop(context);
          CustomSnackBar.show(
            context,
            "Out of stock: You selected $countInCurrent of '${product['name']}', but only $totalQuantity exist.",
          );
          return;
        }

        final List<dynamic> overlaps = await supabase
            .from('bookings')
            .select('client_name, product_ids')
            .filter('status', 'neq', 'cancelled')
            .lt('pickup_datetime', returnDate!.toIso8601String())
            .gt('return_datetime', pickupDate!.toIso8601String());

        int countInOthers = 0;
        List<String> holders = [];

        for (var b in overlaps) {
          final List<dynamic> pIds = b['product_ids'] ?? [];
          int matchCount = pIds
              .where((id) => id.toString() == productId)
              .length;
          if (matchCount > 0) {
            countInOthers += matchCount;
            holders.add("${b['client_name']} ($matchCount)");
          }
        }

        if (countInCurrent + countInOthers > totalQuantity) {
          Navigator.pop(context);
          CustomSnackBar.show(
            context,
            "Unavailable: '${product['name']}' is currently with: ${holders.join(", ")}",
            icon: Icons.warning_amber_rounded,
          );
          return;
        }
      }

      final List<String> productIds = validSelection
          .map((p) => p['id'].toString())
          .toList();
      final List<String> productNames = validSelection
          .map((p) => p['name'].toString())
          .toList();

      final booking = await supabase
          .from('bookings')
          .insert({
            'client_id': selectedClient!['id'].toString(),
            'client_name': selectedClient!['name'],
            'product_ids': productIds,
            'product_names': productNames,
            'pickup_datetime': pickupDate!.toIso8601String(),
            'return_datetime': returnDate!.toIso8601String(),
            'status': 'upcoming',
            'total_price': totalPrice,
            'payment_plan_type': _paymentPlanType,
            'payment_frequency': _paymentPlanType == 'down_payment_installments'
                ? _paymentFrequency
                : null,
            'payment_interval': _paymentInterval,
            'installment_amount':
                double.tryParse(_installmentController.text.trim()) ??
                totalPrice,
            'down_payment_amount':
                double.tryParse(_downPaymentController.text.trim()) ?? 0,
          })
          .select('id')
          .single();

      final operations = BookingOperationsService(supabase);
      if (_contractImage != null) {
        final contractPath = await ProjectCommercialService(supabase)
            .uploadContract(
              projectId: booking['id'].toString(),
              imageFile: _contractImage!,
            );
        await supabase
            .from('bookings')
            .update({'contract_path': contractPath})
            .eq('id', booking['id']);
      }
      try {
        await ProjectFinanceService(
          supabase,
        ).syncProjectFinance(booking['id'].toString());
      } catch (error) {
        debugPrint('Project finance setup failed: $error');
      }
      try {
        await operations.syncBookingItems(
          bookingId: booking['id'].toString(),
          products: validSelection,
        );
        await operations.recordStatus(
          bookingId: booking['id'].toString(),
          status: 'upcoming',
          note: 'Booking created',
        );
      } catch (error) {
        debugPrint('Project detail setup failed: $error');
        if (mounted) {
          CustomSnackBar.show(
            context,
            'Project saved. Run the booking-items SQL policy fix to save its products.',
            color: AppColors.red,
          );
        }
      }

      if (!mounted) return;
      Navigator.pop(context);

      // RESET EVERYTHING
      setState(() {
        selectedClient = null;
        pickupDate = null;
        returnDate = null;
        selectedProducts = [null];
        _contractImage = null;
        _currentStep = 0;
      });
      _projectPriceController.clear();
      _installmentController.clear();
      _downPaymentController.clear();

      // Explicitly clear the CustomSearch internal state
      _searchKey.currentState?.clear();

      CustomSnackBar.show(
        context,
        "Project Created Successfully!",
        color: AppColors.green,
        icon: Icons.check_circle_outline,
      );

      if (!widget.isRoot) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      CustomSnackBar.show(context, _friendlyProjectError(e));
    }
  }

  void _showCustomDatePicker({required bool isPickup}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
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
    final response = await supabase
        .from('products')
        .select()
        .eq('is_active', true);
    List<Map<String, dynamic>> allProducts = List<Map<String, dynamic>>.from(
      response,
    );
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = sheetContext.isDarkMode;
        return Container(
          height: MediaQuery.of(sheetContext).size.height * 0.75,
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
                          '${_currencyFormat.format(product['price'] ?? 0)} EGP/month default',
                        ),
                        onTap: () {
                          setState(
                            () => selectedProducts[index] = {
                              ...product,
                              'project_price': product['price'] ?? 0,
                            },
                          );
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
      AppIcons.inventory,
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
    final isDark = context.isDarkMode;

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
              appBar: CustomAppBar(text: "Add Project", showPfp: widget.isRoot),
              body: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProjectStepIndicator(
                      currentStep: _currentStep,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                          child: ScaleTransition(
                            scale: Tween<double>(begin: .96, end: 1).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        key: ValueKey(_currentStep),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_currentStep == 0) ...[
                            CustomSearch(
                              key: _searchKey, // Applied the key here
                              onClientSelected: (client) =>
                                  setState(() => selectedClient = client),
                            ),
                            if (selectedClient != null) ...[
                              const SizedBox(height: 12),
                              ProjectClientCard(
                                client: selectedClient!,
                                isDark: isDark,
                              ),
                            ],
                            const SizedBox(height: 28),
                            _SectionHeading(
                              icon: Icons.inventory_2_outlined,
                              title: 'Project products',
                              subtitle:
                                  'Choose everything included in this project',
                              isDark: isDark,
                            ),
                            const SizedBox(height: 10),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: selectedProducts.length,
                              itemBuilder: (context, index) {
                                bool isLast =
                                    index == selectedProducts.length - 1;
                                final product = selectedProducts[index];
                                final imageUrl =
                                    product?['image_url'] ?? product?['image'];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () =>
                                              _showProductSearch(index),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF2A2A2A)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                _buildImageOrIcon(
                                                  imageUrl,
                                                  isDark,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        product?['name'] ??
                                                            "Select Product",
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          color: isDark
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xFF6A6A6A,
                                                                ),
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                      if (product != null)
                                                        TextFormField(
                                                          key: ValueKey(
                                                            '${product['id']}-$index',
                                                          ),
                                                          initialValue:
                                                              '${product['project_price'] ?? product['price'] ?? 0}',
                                                          keyboardType:
                                                              const TextInputType.numberWithOptions(
                                                                decimal: true,
                                                              ),
                                                          inputFormatters: const [
                                                            CurrencyAmountFormatter(),
                                                          ],
                                                          decoration:
                                                              const InputDecoration(
                                                                labelText:
                                                                    'Monthly price per item',
                                                                suffixText:
                                                                    'EGP/month',
                                                                isDense: true,
                                                              ),
                                                          onChanged: (value) {
                                                            product['project_price'] =
                                                                double.tryParse(
                                                                  value
                                                                      .replaceAll(
                                                                        ',',
                                                                        '',
                                                                      ),
                                                                ) ??
                                                                0;
                                                            setState(() {});
                                                          },
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
                                                  () => selectedProducts.add(
                                                    null,
                                                  ),
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
                                                AppIcons.add,
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
                                            () => selectedProducts.removeAt(
                                              index,
                                            ),
                                          ),
                                          child: Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(
                                                0.3,
                                              ),
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
                          ],
                          if (_currentStep == 1) ...[
                            const SizedBox(height: 10),
                            _SectionHeading(
                              icon: Icons.calendar_month_outlined,
                              title: 'Project schedule',
                              subtitle:
                                  'Set the planned start and finish dates',
                              isDark: isDark,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Start date',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _PickerTile(
                              imagePath: AppIcons.pickUp,
                              label: pickupDate == null
                                  ? "Select Pickup Date"
                                  : DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(pickupDate!),
                              onTap: () =>
                                  _showCustomDatePicker(isPickup: true),
                              isDark: isDark,
                            ),
                            const SizedBox(height: 15),
                            Text(
                              'End date',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _PickerTile(
                              imagePath: AppIcons.returns,
                              label: returnDate == null
                                  ? "Select Return Date"
                                  : DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(returnDate!),
                              onTap: () =>
                                  _showCustomDatePicker(isPickup: false),
                              isDark: isDark,
                            ),
                            const SizedBox(height: 28),
                            _SectionHeading(
                              icon: Icons.description_outlined,
                              title: 'Signed contract',
                              subtitle: 'Take or upload the signed agreement',
                              isDark: isDark,
                            ),
                            const SizedBox(height: 12),
                            ProjectCommercialFields(
                              isDark: isDark,
                              priceController: _projectPriceController,
                              installmentController: _installmentController,
                              downPaymentController: _downPaymentController,
                              paymentPlanType: _paymentPlanType,
                              paymentFrequency: _paymentFrequency,
                              paymentInterval: _paymentInterval,
                              contractImage: _contractImage,
                              showPayment: false,
                              onPaymentPlanChanged: (value) =>
                                  setState(() => _paymentPlanType = value),
                              onPaymentFrequencyChanged: (value) =>
                                  setState(() => _paymentFrequency = value),
                              onPaymentIntervalChanged: (value) =>
                                  setState(() => _paymentInterval = value),
                              onContractChanged: (value) =>
                                  setState(() => _contractImage = value),
                            ),
                          ],
                          if (_currentStep == 2) ...[
                            _SectionHeading(
                              icon: Icons.payments_outlined,
                              title: 'Price and payment',
                              subtitle:
                                  'Set the project value and how the client pays',
                              isDark: isDark,
                            ),
                            const SizedBox(height: 12),
                            ProjectCommercialFields(
                              isDark: isDark,
                              priceController: _projectPriceController,
                              installmentController: _installmentController,
                              downPaymentController: _downPaymentController,
                              paymentPlanType: _paymentPlanType,
                              paymentFrequency: _paymentFrequency,
                              paymentInterval: _paymentInterval,
                              contractImage: _contractImage,
                              showContract: false,
                              showPrice: false,
                              onPaymentPlanChanged: (value) =>
                                  setState(() => _paymentPlanType = value),
                              onPaymentFrequencyChanged: (value) =>
                                  setState(() => _paymentFrequency = value),
                              onPaymentIntervalChanged: (value) =>
                                  setState(() => _paymentInterval = value),
                              onContractChanged: (value) =>
                                  setState(() => _contractImage = value),
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
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
                                        projectDuration,
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Total Amount:",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
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
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (_currentStep > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() => _currentStep--),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                minimumSize: const Size.fromHeight(52),
                                side: const BorderSide(
                                  color: AppColors.primary,
                                  width: 1.4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Back'),
                            ),
                          ),
                        if (_currentStep > 0) const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onLongPress: _currentStep == 2
                                ? _previewQuote
                                : null,
                            child: ElevatedButton(
                              onPressed: _currentStep == 2
                                  ? _saveBooking
                                  : () => setState(() => _currentStep++),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                _currentStep == 2
                                    ? 'Confirm Project'
                                    : 'Continue',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_currentStep == 2)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Center(
                          child: Text(
                            'Hold Confirm Project to preview the PDF quote',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
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

class _ProjectStepIndicator extends StatelessWidget {
  const _ProjectStepIndicator({
    required this.currentStep,
    required this.isDark,
  });

  final int currentStep;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const labels = ['Client & products', 'Dates & contract', 'Payment'];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index <= currentStep;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 3,
                      color: index == 0
                          ? Colors.transparent
                          : (active
                                ? AppColors.primary
                                : (isDark ? Colors.white12 : Colors.black12)),
                    ),
                  ),
                  Container(
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primary
                          : (isDark ? Colors.white12 : Colors.black12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : (isDark ? Colors.white60 : Colors.black54),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 3,
                      color: index == labels.length - 1
                          ? Colors.transparent
                          : (index < currentStep
                                ? AppColors.primary
                                : (isDark ? Colors.white12 : Colors.black12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                labels[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: active
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.white54 : Colors.black45),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

String _formatDuration(DateTime? start, DateTime? end) {
  if (start == null || end == null || end.isBefore(start)) {
    return 'Select dates';
  }
  var months = (end.year - start.year) * 12 + end.month - start.month;
  DateTime anniversary(int value) {
    final monthEnd = DateTime(start.year, start.month + value + 1, 0).day;
    return DateTime(
      start.year,
      start.month + value,
      start.day.clamp(1, monthEnd),
    );
  }

  if (anniversary(months).isAfter(end)) {
    months--;
  }
  final remainingDays = end.difference(anniversary(months)).inDays;
  final parts = <String>[];
  if (months > 0) {
    parts.add('$months ${months == 1 ? 'month' : 'months'}');
  }
  if (remainingDays > 0 || parts.isEmpty) {
    parts.add('$remainingDays ${remainingDays == 1 ? 'day' : 'days'}');
  }
  return parts.join(', ');
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(.12),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    ],
  );
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
    final isDark = context.isDarkMode;
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
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryRed : Colors.transparent,
                      borderRadius: BorderRadius.circular(50),
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
            height: 50,
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
