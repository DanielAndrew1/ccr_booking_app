// ignore_for_file: deprecated_member_use, use_build_context_synchronously, unnecessary_underscores, unused_element_parameter
import 'package:intl/intl.dart';
import 'package:site_lapse/core/imports.dart';

class EditBooking extends StatefulWidget {
  final bool isRoot;
  const EditBooking({super.key, this.isRoot = false});

  @override
  State<EditBooking> createState() => _EditBookingState();
}

class _EditBookingState extends State<EditBooking> {
  final SupabaseClient supabase = Supabase.instance.client;

  // Added key to control the CustomSearch state
  final GlobalKey<CustomSearchState> _searchKey =
      GlobalKey<CustomSearchState>();

  String? _bookingId;
  Map<String, dynamic>? selectedClient;
  DateTime? pickupDate;
  DateTime? returnDate;
  List<Map<String, dynamic>?> selectedProducts = [null];
  final _projectPriceController = TextEditingController();
  final _installmentController = TextEditingController();
  final _downPaymentController = TextEditingController();
  String _paymentPlanType = 'one_time_end';
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

  String get projectDuration => _formatProjectDuration(pickupDate, returnDate);

  double get totalPrice {
    final dailySubtotal = selectedProducts
        .whereType<Map<String, dynamic>>()
        .fold(0.0, (sum, product) {
          final value = product['project_price'] ?? product['price'] ?? 0;
          return sum +
              (value is num
                  ? value.toDouble()
                  : double.tryParse('$value') ?? 0);
        });
    return dailySubtotal * _billableProjectDays(pickupDate, returnDate);
  }

  int get _projectPaymentMonths => _paymentMonths(pickupDate, returnDate);
  bool get _allowAtEndPayment => _isLessThanOneMonth(pickupDate, returnDate);
  double get _downPayment =>
      double.tryParse(_downPaymentController.text.replaceAll(',', '').trim()) ??
      0;
  double get _calculatedMonthlyFee =>
      ((totalPrice - _downPayment).clamp(0, double.infinity)) /
      _projectPaymentMonths;

  void _syncCalculatedInstallment() {
    if (_paymentPlanType == 'monthly') {
      _installmentController.text = (totalPrice / _projectPaymentMonths)
          .toStringAsFixed(2);
    } else if (_paymentPlanType == 'down_payment_installments') {
      _installmentController.text = _calculatedMonthlyFee.toStringAsFixed(2);
    }
  }

  void _selectPaymentPlan(String value) {
    setState(() {
      _paymentPlanType = value;
      if (value == 'monthly') {
        _installmentController.text = (totalPrice / _projectPaymentMonths)
            .toStringAsFixed(2);
      } else if (value == 'down_payment_installments') {
        _installmentController.text = _calculatedMonthlyFee.toStringAsFixed(2);
      }
    });
  }

  void _refreshPaymentPlanForDates() {
    if (_paymentPlanType == 'one_time_end' && !_allowAtEndPayment) {
      _paymentPlanType = 'one_time_start';
    }
    if (_paymentPlanType == 'monthly') {
      _installmentController.text = (totalPrice / _projectPaymentMonths)
          .toStringAsFixed(2);
    } else if (_paymentPlanType == 'down_payment_installments') {
      _installmentController.text = _calculatedMonthlyFee.toStringAsFixed(2);
    }
  }

  Future<void> _selectProduct(int index, Map<String, dynamic> product) async {
    var selected = <String, dynamic>{
      ...product,
      'project_price': product['price'] ?? 0,
    };
    if (product['tracks_serial_numbers'] == true) {
      final rows = await supabase
          .from('product_serials')
          .select('id, serial_number')
          .eq('product_id', product['id'])
          .eq('is_maintenance', false)
          .eq('is_retired', false)
          .order('serial_number');
      selected = {
        ...selected,
        'available_serials': List<Map<String, dynamic>>.from(rows),
      };
    }
    if (!mounted) return;
    setState(() => selectedProducts[index] = selected);
  }

  Future<void> _syncSerialAssignments(
    String bookingId,
    List<Map<String, dynamic>> products,
  ) async {
    await supabase
        .from('booking_serial_assignments')
        .delete()
        .eq('booking_id', bookingId);
    final assignments = products
        .where((product) => product['selected_serial_id'] != null)
        .map(
          (product) => {
            'booking_id': bookingId,
            'product_id': product['id'],
            'product_serial_id': product['selected_serial_id'],
          },
        )
        .toList();
    if (assignments.isNotEmpty) {
      await supabase.from('booking_serial_assignments').insert(assignments);
    }
  }

  Future<Set<String>> _reservedSerialIdsForProjectDates() async {
    if (pickupDate == null || returnDate == null) return <String>{};
    final overlapping = await supabase
        .from('bookings')
        .select('id')
        .filter('status', 'neq', 'cancelled')
        .lt('pickup_datetime', returnDate!.toIso8601String())
        .gt('return_datetime', pickupDate!.toIso8601String());
    final bookingIds = (overlapping as List)
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .where((id) => id != _bookingId)
        .toList();
    if (bookingIds.isEmpty) return <String>{};
    final assignments = await supabase
        .from('booking_serial_assignments')
        .select('product_serial_id')
        .inFilter('booking_id', bookingIds);
    return (assignments as List)
        .map((row) => row['product_serial_id']?.toString())
        .whereType<String>()
        .toSet();
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
    return 'Could not save the project changes. Please try again.';
  }

  Future<void> _recordNextPayment() async {
    if (_bookingId == null || selectedClient == null) return;
    final finance = ProjectFinanceService(supabase);
    final schedules = await finance.schedules(_bookingId!);
    final pending = schedules
        .where(
          (schedule) =>
              schedule['status'] != 'paid' && schedule['status'] != 'cancelled',
        )
        .toList();
    if (pending.isEmpty) {
      if (mounted) CustomSnackBar.show(context, 'No outstanding payments');
      return;
    }
    final schedule = pending.first;
    final amountController = TextEditingController(
      text: schedule['amount'].toString(),
    );
    String method = 'cash';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Record payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Due ${DateFormat('dd MMM yyyy').format(DateTime.parse(schedule['due_at']))}',
              ),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  suffixText: 'EGP',
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: method,
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(
                    value: 'bank_transfer',
                    child: Text('Bank transfer'),
                  ),
                  DropdownMenuItem(value: 'card', child: Text('Card')),
                ],
                onChanged: (value) => setDialogState(() => method = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    if (amount <= 0) return;
    await finance.recordPayment(
      scheduleId: schedule['id'].toString(),
      amount: amount,
      method: method,
    );
    final payments = await supabase
        .from('payments')
        .select()
        .eq('payment_schedule_id', schedule['id'])
        .order('created_at', ascending: false)
        .limit(1);
    if (!mounted || payments.isEmpty) return;
    final payment = Map<String, dynamic>.from(payments.first);
    await ProjectQuoteService.shareReceipt(
      receiptNumber:
          payment['receipt_number']?.toString() ??
          'SLR-${payment['id'].toString().substring(0, 8)}',
      clientName: selectedClient!['name'].toString(),
      amount: amount,
      method: method,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingBooking();
    });
  }

  Future<void> _loadExistingBooking() async {
    final bookingProvider = Provider.of<BookingProvider>(
      context,
      listen: false,
    );
    final booking = bookingProvider.editingBooking;
    if (booking == null) return;

    final bookingId = booking['id']?.toString();
    final clientId = booking['client_id'];
    final clientName = booking['client_name']?.toString() ?? '';

    DateTime? parsedPickup;
    DateTime? parsedReturn;
    try {
      if (booking['pickup_datetime'] != null) {
        parsedPickup = DateTime.parse(booking['pickup_datetime']);
      }
      if (booking['return_datetime'] != null) {
        parsedReturn = DateTime.parse(booking['return_datetime']);
      }
    } catch (_) {}

    List<Map<String, dynamic>?> prefilledProducts = [null];
    final List<dynamic> productIds = (booking['product_ids'] as List? ?? [])
        .toList();
    if (productIds.isNotEmpty) {
      final uniqueIds = productIds.map((id) => id.toString()).toSet().toList();
      try {
        final rawData = await supabase
            .from('products')
            .select()
            .inFilter('id', uniqueIds);
        final List<Map<String, dynamic>> productData =
            List<Map<String, dynamic>>.from(rawData);

        final Map<String, Map<String, dynamic>> productMap = {
          for (final p in productData)
            if (p['id'] != null) p['id'].toString(): p,
        };

        final built = productIds
            .map<Map<String, dynamic>?>((id) => productMap[id.toString()])
            .toList();
        built.removeWhere((p) => p == null);

        final serialRows = await supabase
            .from('product_serials')
            .select('id, product_id, serial_number, is_maintenance, is_retired')
            .inFilter('product_id', uniqueIds);
        final assignedRows = await supabase
            .from('booking_serial_assignments')
            .select('product_id, product_serial_id')
            .eq('booking_id', bookingId!);
        final availableByProduct = <String, List<Map<String, dynamic>>>{};
        for (final row in List<Map<String, dynamic>>.from(serialRows)) {
          final isAssignedToThisProject =
              List<Map<String, dynamic>>.from(assignedRows).any(
                (assignment) =>
                    assignment['product_serial_id'].toString() ==
                    row['id'].toString(),
              );
          if ((row['is_maintenance'] == true || row['is_retired'] == true) &&
              !isAssignedToThisProject) {
            continue;
          }
          availableByProduct
              .putIfAbsent(row['product_id'].toString(), () => [])
              .add(row);
        }
        final assignedByProduct = <String, List<String>>{};
        for (final row in List<Map<String, dynamic>>.from(assignedRows)) {
          assignedByProduct
              .putIfAbsent(row['product_id'].toString(), () => [])
              .add(row['product_serial_id'].toString());
        }
        final occurrence = <String, int>{};
        for (final product in built.whereType<Map<String, dynamic>>()) {
          final id = product['id'].toString();
          final position = occurrence[id] ?? 0;
          occurrence[id] = position + 1;
          product['available_serials'] = availableByProduct[id] ?? [];
          final assigned = assignedByProduct[id] ?? [];
          if (position < assigned.length) {
            product['selected_serial_id'] = assigned[position];
          }
        }

        prefilledProducts = List<Map<String, dynamic>?>.from(built);
        if (prefilledProducts.isEmpty || prefilledProducts.last != null) {
          prefilledProducts.add(null);
        }
      } catch (_) {
        prefilledProducts = [null];
      }
    }

    if (!mounted) return;
    setState(() {
      _bookingId = bookingId;
      selectedClient = {'id': clientId, 'name': clientName};
      pickupDate = parsedPickup;
      returnDate = parsedReturn;
      selectedProducts = prefilledProducts;
      _projectPriceController.text = _currencyFormat.format(
        double.tryParse(booking['total_price']?.toString() ?? '') ?? 0,
      );
      _installmentController.text =
          (double.tryParse(booking['installment_amount']?.toString() ?? '') ??
                  0)
              .toStringAsFixed(2);
      _downPaymentController.text =
          (double.tryParse(booking['down_payment_amount']?.toString() ?? '') ??
                  0)
              .toStringAsFixed(2);
      _paymentPlanType =
          booking['payment_plan_type']?.toString() ?? 'one_time_end';
      _paymentFrequency = booking['payment_frequency']?.toString() ?? 'month';
      _paymentInterval =
          int.tryParse(booking['payment_interval']?.toString() ?? '') ?? 1;
    });
    _searchKey.currentState?.setSelectedClientName(clientName);
  }

  Future<void> _saveBooking() async {
    _syncCalculatedInstallment();
    bool isProductsEmpty = !selectedProducts.any((p) => p != null);

    if (_bookingId == null) {
      final fallbackId = Provider.of<BookingProvider>(
        context,
        listen: false,
      ).editingBooking?['id']?.toString();
      if (fallbackId == null) {
        CustomSnackBar.show(context, "Missing booking ID");
        return;
      }
      _bookingId = fallbackId;
    }

    if (selectedClient == null ||
        pickupDate == null ||
        returnDate == null ||
        isProductsEmpty ||
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

        final overlapQuery = supabase
            .from('bookings')
            .select('id, client_name, product_ids')
            .filter('status', 'neq', 'cancelled')
            .lt('pickup_datetime', returnDate!.toIso8601String())
            .gt('return_datetime', pickupDate!.toIso8601String());
        if (_bookingId != null) {
          overlapQuery.neq('id', _bookingId!);
        }
        final List<dynamic> overlaps = await overlapQuery;

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
      final trackedWithoutSerial = validSelection.any(
        (product) =>
            product['tracks_serial_numbers'] == true &&
            product['selected_serial_id'] == null,
      );
      final selectedSerialIds = validSelection
          .map((product) => product['selected_serial_id'])
          .whereType<String>()
          .toList();
      if (trackedWithoutSerial ||
          selectedSerialIds.toSet().length != selectedSerialIds.length) {
        Navigator.pop(context);
        CustomSnackBar.show(
          context,
          trackedWithoutSerial
              ? 'Select a serial number for every tracked item.'
              : 'Each tracked item needs a different serial number.',
          color: AppColors.red,
        );
        return;
      }
      if (selectedSerialIds.isNotEmpty) {
        final reservedSerialIds = await _reservedSerialIdsForProjectDates();
        if (selectedSerialIds.any(reservedSerialIds.contains)) {
          Navigator.pop(context);
          CustomSnackBar.show(
            context,
            'A selected serial is already booked during these dates. Choose another one.',
            color: AppColors.red,
          );
          return;
        }
      }

      await supabase
          .from('bookings')
          .update({
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
          .eq('id', _bookingId!);

      final operations = BookingOperationsService(supabase);
      if (_contractImage != null) {
        final contractPath = await ProjectCommercialService(
          supabase,
        ).uploadContract(projectId: _bookingId!, imageFile: _contractImage!);
        await supabase
            .from('bookings')
            .update({'contract_path': contractPath})
            .eq('id', _bookingId!);
      }
      try {
        await ProjectFinanceService(supabase).syncProjectFinance(_bookingId!);
      } catch (error) {
        debugPrint('Project finance setup failed: $error');
      }
      try {
        await operations.syncBookingItems(
          bookingId: _bookingId!,
          products: validSelection,
        );
        await _syncSerialAssignments(_bookingId!, validSelection);
        await operations.recordStatus(
          bookingId: _bookingId!,
          status: 'upcoming',
          note: 'Booking updated',
        );
      } catch (error) {
        debugPrint('Project detail update failed: $error');
        if (mounted) {
          CustomSnackBar.show(
            context,
            'Project saved. Run the booking-items SQL policy fix to update its products.',
            color: AppColors.red,
          );
        }
      }

      if (!mounted) return;
      Provider.of<NavbarProvider>(context, listen: false).setEditMode(false);

      // RESET EVERYTHING
      setState(() {
        selectedClient = null;
        pickupDate = null;
        returnDate = null;
        selectedProducts = [null];
      });

      // Explicitly clear the CustomSearch internal state
      _searchKey.currentState?.clear();

      CustomSnackBar.show(
        context,
        "Project Updated Successfully!",
        color: AppColors.green,
      );

      Provider.of<BookingProvider>(
        context,
        listen: false,
      ).clearEditingBooking();
      Provider.of<NavbarProvider>(context, listen: false).setEditMode(false);
      Provider.of<NavbarProvider>(context, listen: false).setIndex(2);

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
            _refreshPaymentPlanForDates();
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
                        subtitle:
                            (product['price'] is num
                                    ? product['price'] as num
                                    : num.tryParse('${product['price']}') ??
                                          0) >
                                0
                            ? Text(
                                '${_currencyFormat.format(product['price'])} EGP/day default',
                              )
                            : null,
                        onTap: () {
                          _selectProduct(index, product);
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
    final isEditing =
        Provider.of<BookingProvider>(context).editingBooking != null;

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
                text: isEditing ? "Edit Project" : "Add Project",
                showPfp: true,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () {
                        Provider.of<BookingProvider>(
                          context,
                          listen: false,
                        ).clearEditingBooking();
                        Provider.of<NavbarProvider>(
                          context,
                          listen: false,
                        ).setEditMode(false);
                        Provider.of<NavbarProvider>(
                          context,
                          listen: false,
                        ).setIndex(4);
                      },
                    ),
                  ),
                ],
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
                    _EditStepHeader(currentStep: _currentStep, isDark: isDark),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, animation) => FadeTransition(
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
                      ),
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
                                                                    'EGP/day',
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
                                                      if (product?['tracks_serial_numbers'] ==
                                                          true) ...[
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        DropdownButtonFormField<
                                                          String
                                                        >(
                                                          value:
                                                              product?['selected_serial_id']
                                                                  ?.toString(),
                                                          decoration:
                                                              const InputDecoration(
                                                                labelText:
                                                                    'Select serial',
                                                                isDense: true,
                                                              ),
                                                          items:
                                                              (product?['available_serials']
                                                                          as List? ??
                                                                      [])
                                                                  .map(
                                                                    (
                                                                      serial,
                                                                    ) => DropdownMenuItem<String>(
                                                                      value: serial['id']
                                                                          .toString(),
                                                                      child: Text(
                                                                        serial['serial_number']
                                                                            .toString(),
                                                                      ),
                                                                    ),
                                                                  )
                                                                  .toList(),
                                                          onChanged: (value) =>
                                                              setState(() {
                                                                product?['selected_serial_id'] =
                                                                    value;
                                                              }),
                                                        ),
                                                      ],
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
                              imagePath: AppIcons.returns,
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
                              "Return Date",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _PickerTile(
                              imagePath: AppIcons.pickUp,
                              label: returnDate == null
                                  ? "Select Return Date"
                                  : DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(returnDate!),
                              onTap: () =>
                                  _showCustomDatePicker(isPickup: false),
                              isDark: isDark,
                            ),
                            const SizedBox(height: 30),
                            Text(
                              'Signed contract',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
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
                              onDownPaymentChanged: (_) => setState(() {
                                _installmentController.text =
                                    _calculatedMonthlyFee.toStringAsFixed(2);
                              }),
                            ),
                          ],
                          if (_currentStep == 2) ...[
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
                              allowAtEnd: _allowAtEndPayment,
                              onPaymentPlanChanged: _selectPaymentPlan,
                              onPaymentFrequencyChanged: (value) =>
                                  setState(() => _paymentFrequency = value),
                              onPaymentIntervalChanged: (value) =>
                                  setState(() => _paymentInterval = value),
                              onContractChanged: (value) =>
                                  setState(() => _contractImage = value),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed:
                                    _bookingId == null ||
                                        selectedClient == null ||
                                        pickupDate == null ||
                                        returnDate == null ||
                                        totalPrice <= 0
                                    ? null
                                    : () => ProjectQuoteService.shareQuote(
                                        projectId: _bookingId!,
                                        clientName: selectedClient!['name']
                                            .toString(),
                                        startDate: pickupDate!,
                                        endDate: returnDate!,
                                        products: selectedProducts
                                            .whereType<Map<String, dynamic>>()
                                            .toList(),
                                        totalAmount: totalPrice,
                                        paymentPlanType: _paymentPlanType,
                                        paymentFrequency: _paymentFrequency,
                                        paymentInterval: _paymentInterval,
                                        installmentAmount:
                                            double.tryParse(
                                              _installmentController.text
                                                  .trim(),
                                            ) ??
                                            totalPrice,
                                        downPaymentAmount:
                                            double.tryParse(
                                              _downPaymentController.text
                                                  .trim(),
                                            ) ??
                                            0,
                                      ),
                                icon: const Icon(Icons.picture_as_pdf_outlined),
                                label: const Text('Share PDF Quote'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _bookingId == null
                                    ? null
                                    : _recordNextPayment,
                                icon: const Icon(Icons.payments_outlined),
                                label: const Text(
                                  'Record Payment & Share Receipt',
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed:
                                    _bookingId == null ||
                                        selectedClient == null ||
                                        totalPrice <= 0
                                    ? null
                                    : () => ProjectQuoteService.shareInvoice(
                                        projectId: _bookingId!,
                                        clientName: selectedClient!['name']
                                            .toString(),
                                        totalAmount: totalPrice,
                                      ),
                                icon: const Icon(Icons.receipt_long_outlined),
                                label: const Text('Share PDF Invoice'),
                              ),
                            ),
                            const SizedBox(height: 12),
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
                                  if (_paymentPlanType == 'monthly' ||
                                      _paymentPlanType ==
                                          'down_payment_installments') ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _paymentPlanType == 'monthly'
                                              ? 'Monthly payment:'
                                              : 'Monthly fee:',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          '${_currencyFormat.format(_paymentPlanType == 'monthly' ? totalPrice / _projectPaymentMonths : _calculatedMonthlyFee)} EGP',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
                              _currentStep == 2 ? 'Save Changes' : 'Continue',
                            ),
                          ),
                        ),
                      ],
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

class _EditStepHeader extends StatelessWidget {
  const _EditStepHeader({required this.currentStep, required this.isDark});
  final int currentStep;
  final bool isDark;
  @override
  Widget build(BuildContext context) {
    const labels = ['Client & products', 'Dates & contract', 'Payment'];
    return Row(
      children: List.generate(3, (index) {
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
                      shape: BoxShape.circle,
                      color: active
                          ? AppColors.primary
                          : (isDark ? Colors.white12 : Colors.black12),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: active ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 3,
                      color: index == 2
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
                      : Colors.grey,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

String _formatProjectDuration(DateTime? start, DateTime? end) {
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

int _billableProjectDays(DateTime? start, DateTime? end) {
  if (start == null || end == null || end.isBefore(start)) return 0;
  final first = DateTime(start.year, start.month, start.day);
  final last = DateTime(end.year, end.month, end.day);
  return last.difference(first).inDays + 1;
}

int _paymentMonths(DateTime? start, DateTime? end) {
  if (start == null || end == null || end.isBefore(start)) return 1;
  var months = (end.year - start.year) * 12 + end.month - start.month;
  final anniversary = DateTime(start.year, start.month + months, start.day);
  if (anniversary.isBefore(end)) months++;
  return months < 1 ? 1 : months;
}

bool _isLessThanOneMonth(DateTime? start, DateTime? end) {
  if (start == null || end == null || end.isBefore(start)) return true;
  final nextMonth = DateTime(start.year, start.month + 1, start.day);
  return end.isBefore(nextMonth);
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

int indexPage = 0;
