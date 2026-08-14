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
  final _contactNameController = TextEditingController();
  final _contactRoleController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _projectNameController = TextEditingController();
  final _projectAddressController = TextEditingController();
  final _estimatedDurationController = TextEditingController();
  final _projectTypeController = TextEditingController();
  String? _paymentPlanType;
  String _paymentFrequency = 'month';
  int _paymentInterval = 1;
  File? _contractImage;
  int _currentStep = 0;
  final GlobalKey _confirmButtonKey = GlobalKey();
  bool _isProjectMenuOpen = false;
  bool _contactInfoSaved = false;
  bool _customDuration = false;
  bool _customProjectType = false;

  static const _durationOptions = [
    '1 month',
    '3 months',
    '6 months',
    '12 months',
    '18 months',
    '24 months',
    '36 months',
    'Custom',
  ];
  static const _projectTypeOptions = [
    'Construction',
    'Renovation',
    'Interior fit-out',
    'Infrastructure',
    'Maintenance',
    'Event',
    'Other',
  ];

  final NumberFormat _currencyFormat = NumberFormat("#,##0", "en_US");

  Future<void> _showContactInfoEditor() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: .45),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Contact info',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProjectTextField(
                      controller: _contactNameController,
                      label: 'Contact full name',
                      imagePath: AppIcons.profile,
                      isDark: isDark,
                    ),
                    _ProjectTextField(
                      controller: _contactRoleController,
                      label: 'Role',
                      imagePath: AppIcons.client,
                      isDark: isDark,
                    ),
                    _ProjectTextField(
                      controller: _contactPhoneController,
                      label: 'Phone number',
                      imagePath: AppIcons.phone,
                      keyboardType: TextInputType.phone,
                      isDark: isDark,
                    ),
                    _ProjectTextField(
                      controller: _contactEmailController,
                      label: 'Email (optional)',
                      imagePath: AppIcons.email,
                      keyboardType: TextInputType.emailAddress,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: () {
                          if (_contactNameController.text.trim().isEmpty ||
                              _contactRoleController.text.trim().isEmpty ||
                              _contactPhoneController.text.trim().isEmpty) {
                            CustomSnackBar.show(
                              sheetContext,
                              'Add the contact name, role, and phone number.',
                            );
                            return;
                          }
                          setState(() => _contactInfoSaved = true);
                          Navigator.pop(sheetContext);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Save contact'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

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
    final dailySubtotal = selectedProducts
        .whereType<Map<String, dynamic>>()
        .fold(0.0, (sum, product) {
          final value = product['project_price'] ?? product['price'] ?? 0;
          return sum +
              (value is num
                  ? value.toDouble()
                  : double.tryParse('$value') ?? 0);
        });
    return dailySubtotal * _billableDays(pickupDate, returnDate);
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
      _paymentPlanType = null;
    }
    if (_paymentPlanType == 'monthly') {
      _installmentController.text = (totalPrice / _projectPaymentMonths)
          .toStringAsFixed(2);
    } else if (_paymentPlanType == 'down_payment_installments') {
      _installmentController.text = _calculatedMonthlyFee.toStringAsFixed(2);
    }
  }

  DateTime _endDateFromEstimatedDuration(DateTime start) {
    final value = _estimatedDurationController.text.trim().toLowerCase();
    final match = RegExp(
      r'^(\d+)\s*(day|days|week|weeks|month|months|year|years)$',
    ).firstMatch(value);
    if (match == null) return start.add(const Duration(days: 1));

    final amount = int.tryParse(match.group(1)!) ?? 1;
    final unit = match.group(2)!;
    if (unit.startsWith('day')) return start.add(Duration(days: amount));
    if (unit.startsWith('week')) {
      return start.add(Duration(days: amount * 7));
    }
    final months = unit.startsWith('year') ? amount * 12 : amount;
    final targetMonth = DateTime(start.year, start.month + months, 1);
    final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
    return DateTime(
      targetMonth.year,
      targetMonth.month,
      start.day.clamp(1, lastDay),
    );
  }

  void _refreshEndDateFromEstimate() {
    if (pickupDate == null ||
        _estimatedDurationController.text.trim().isEmpty) {
      return;
    }
    returnDate = _endDateFromEstimatedDuration(pickupDate!);
    _refreshPaymentPlanForDates();
  }

  String? _currentStepError() {
    switch (_currentStep) {
      case 0:
        if (selectedClient == null) return 'Select a client to continue.';
      case 1:
        if (_projectNameController.text.trim().isEmpty ||
            _projectAddressController.text.trim().isEmpty ||
            _estimatedDurationController.text.trim().isEmpty ||
            _projectTypeController.text.trim().isEmpty) {
          return 'Fill in all project details to continue.';
        }
      case 2:
        final products = selectedProducts.whereType<Map<String, dynamic>>();
        if (products.isEmpty) return 'Select at least one product.';
        if (products.any((product) {
          final raw = product['project_price'] ?? product['price'] ?? 0;
          final price = raw is num
              ? raw.toDouble()
              : double.tryParse('$raw') ?? 0;
          return price <= 0;
        })) {
          return 'Add a daily price for every selected product.';
        }
        if (products.any(
          (product) =>
              product['tracks_serial_numbers'] == true &&
              product['selected_serial_id'] == null,
        )) {
          return 'Select a serial number for every tracked product.';
        }
      case 3:
        if (pickupDate == null || returnDate == null) {
          return 'Select the project start and end dates.';
        }
      case 4:
        if (_paymentPlanType == null) return 'Select a payment plan.';
        if (_paymentPlanType == 'down_payment_installments' &&
            double.tryParse(_downPaymentController.text.trim()) == null) {
          return 'Enter the down payment.';
        }
    }
    return null;
  }

  void _continueProject() {
    final error = _currentStepError();
    if (error != null) {
      CustomSnackBar.show(context, error);
      return;
    }
    setState(() => _currentStep++);
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
    final fileName = ProjectQuoteService.quoteFileName(
      selectedClient!['name'].toString(),
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (previewContext) {
          final background =
              Theme.of(previewContext).brightness == Brightness.dark
              ? Colors.black
              : Colors.white;
          return Scaffold(
            backgroundColor: background,
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
              scrollViewDecoration: BoxDecoration(color: background),
              canChangePageFormat: false,
              useActions: false,
              allowPrinting: false,
              allowSharing: false,
            ),
          );
        },
      ),
    );
  }

  Future<void> _showProjectMenu() async {
    final renderBox =
        _confirmButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final buttonPosition = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;
    setState(() => _isProjectMenuOpen = true);

    final action = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close project actions',
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, _, __) {
        return Stack(
          children: [
            Positioned(
              left: buttonPosition.dx,
              bottom:
                  MediaQuery.sizeOf(dialogContext).height -
                  buttonPosition.dy +
                  18,
              width: buttonSize.width,
              child: Material(
                color: Colors.transparent,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      height: buttonSize.height,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: _ProjectMenuOption(
                          label: 'Draft',
                          showDivider: false,
                          onTap: () => Navigator.pop(dialogContext, 'draft'),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 30,
                      bottom: -10,
                      child: ClipPath(
                        clipper: _DownTriangleClipper(),
                        child: Container(
                          width: 20,
                          height: 11,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (transitionContext, animation, __, child) {
        final screenSize = MediaQuery.sizeOf(transitionContext);
        final arrowOrigin = Alignment(
          ((buttonPosition.dx + buttonSize.width - 14) / screenSize.width) * 2 -
              1,
          (buttonPosition.dy / screenSize.height) * 2 - 1,
        );
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            alignment: arrowOrigin,
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeIn,
            ),
            child: child,
          ),
        );
      },
    );

    if (mounted) setState(() => _isProjectMenuOpen = false);
    if (action == 'draft') await _saveBooking(asDraft: true);
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

  Future<void> _saveBooking({bool asDraft = false}) async {
    _syncCalculatedInstallment();
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
        final maintenanceSerials = await supabase
            .from('product_serials')
            .select('id')
            .inFilter('id', selectedSerialIds)
            .or('is_maintenance.eq.true,is_retired.eq.true');
        if ((maintenanceSerials as List).isNotEmpty) {
          Navigator.pop(context);
          CustomSnackBar.show(
            context,
            'A selected serial is down for maintenance. Choose another one.',
            color: AppColors.red,
          );
          return;
        }
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

      final booking = await supabase
          .from('bookings')
          .insert({
            'client_id': selectedClient!['id'].toString(),
            'client_name': selectedClient!['name'],
            'product_ids': productIds,
            'product_names': productNames,
            'pickup_datetime': pickupDate!.toIso8601String(),
            'return_datetime': returnDate!.toIso8601String(),
            'status': asDraft ? 'draft' : 'upcoming',
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
            'project_name': _projectNameController.text.trim(),
            'project_address': _projectAddressController.text.trim(),
            'estimated_duration': _estimatedDurationController.text.trim(),
            'project_type': _projectTypeController.text.trim(),
            'contact_full_name': _contactNameController.text.trim(),
            'contact_role': _contactRoleController.text.trim(),
            'contact_phone': _contactPhoneController.text.trim(),
            'contact_email': _contactEmailController.text.trim().isEmpty
                ? null
                : _contactEmailController.text.trim(),
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
      if (!asDraft) {
        try {
          await ProjectFinanceService(
            supabase,
          ).syncProjectFinance(booking['id'].toString());
        } catch (error) {
          debugPrint('Project finance setup failed: $error');
        }
      }
      try {
        await operations.syncBookingItems(
          bookingId: booking['id'].toString(),
          products: validSelection,
        );
        await _syncSerialAssignments(booking['id'].toString(), validSelection);
        await operations.recordStatus(
          bookingId: booking['id'].toString(),
          status: asDraft ? 'draft' : 'upcoming',
          note: asDraft ? 'Project saved as draft' : 'Booking created',
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
      _contactNameController.clear();
      _contactRoleController.clear();
      _contactPhoneController.clear();
      _contactEmailController.clear();
      _projectNameController.clear();
      _projectAddressController.clear();
      _estimatedDurationController.clear();
      _projectTypeController.clear();

      // Explicitly clear the CustomSearch internal state
      _searchKey.currentState?.clear();

      CustomSnackBar.show(
        context,
        asDraft ? 'Project saved as draft!' : 'Project Created Successfully!',
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
              returnDate = _endDateFromEstimatedDuration(selectedDate);
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
                text: "Add Project",
                showPfp: widget.isRoot,
                actions: [
                  IconButton(
                    tooltip: 'Draft projects',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProjectDraftsPage(),
                      ),
                    ),
                    icon: SvgPicture.asset(
                      AppIcons.save,
                      width: 24,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
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
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Contact info',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: _contactInfoSaved
                                      ? 'Edit contact info'
                                      : 'Add contact info',
                                  onPressed: _showContactInfoEditor,
                                  icon: SvgPicture.asset(
                                    _contactInfoSaved
                                        ? AppIcons.edit
                                        : AppIcons.add,
                                    width: 26,
                                    colorFilter: const ColorFilter.mode(
                                      AppColors.primary,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_contactInfoSaved) ...[
                              const SizedBox(height: 8),
                              _ContactInfoCard(
                                name: _contactNameController.text.trim(),
                                role: _contactRoleController.text.trim(),
                                phone: _contactPhoneController.text.trim(),
                                email: _contactEmailController.text.trim(),
                                isDark: isDark,
                                onTap: _showContactInfoEditor,
                              ),
                            ],
                          ],
                          if (_currentStep == 1) ...[
                            _ProjectTextField(
                              controller: _projectNameController,
                              label: 'Project name',
                              imagePath: AppIcons.booking,
                              isDark: isDark,
                            ),
                            _ProjectTextField(
                              controller: _projectAddressController,
                              label: 'Address',
                              imagePath: AppIcons.sendDirectional,
                              isDark: isDark,
                            ),
                            _ProjectDropdownField(
                              label: 'Estimated project duration',
                              imagePath: AppIcons.calendar,
                              isDark: isDark,
                              value: _customDuration
                                  ? 'Custom'
                                  : (_durationOptions.contains(
                                          _estimatedDurationController.text,
                                        )
                                        ? _estimatedDurationController.text
                                        : null),
                              options: _durationOptions,
                              onChanged: (value) => setState(() {
                                _customDuration = value == 'Custom';
                                _estimatedDurationController.text =
                                    _customDuration ? '' : value;
                                _refreshEndDateFromEstimate();
                              }),
                            ),
                            if (_customDuration)
                              _ProjectTextField(
                                controller: _estimatedDurationController,
                                label: 'Enter estimated duration',
                                imagePath: AppIcons.calendar,
                                isDark: isDark,
                                onChanged: (_) =>
                                    setState(_refreshEndDateFromEstimate),
                              ),
                            _ProjectDropdownField(
                              label: 'Project type',
                              imagePath: AppIcons.inventory,
                              isDark: isDark,
                              value: _customProjectType
                                  ? 'Other'
                                  : (_projectTypeOptions.contains(
                                          _projectTypeController.text,
                                        )
                                        ? _projectTypeController.text
                                        : null),
                              options: _projectTypeOptions,
                              onChanged: (value) => setState(() {
                                _customProjectType = value == 'Other';
                                _projectTypeController.text = _customProjectType
                                    ? ''
                                    : value;
                              }),
                            ),
                            if (_customProjectType)
                              _ProjectTextField(
                                controller: _projectTypeController,
                                label: 'Enter project type',
                                imagePath: AppIcons.inventory,
                                isDark: isDark,
                              ),
                          ],
                          if (_currentStep == 2) ...[
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
                          if (_currentStep == 3) ...[
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
                              'End date',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black54,
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
                              onDownPaymentChanged: (_) => setState(() {
                                _installmentController.text =
                                    _calculatedMonthlyFee.toStringAsFixed(2);
                              }),
                            ),
                          ],
                          if (_currentStep == 4) ...[
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
                              allowAtEnd: _allowAtEndPayment,
                              onPaymentPlanChanged: _selectPaymentPlan,
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
                                  if (_paymentPlanType == 'monthly' ||
                                      _paymentPlanType ==
                                          'down_payment_installments') ...[
                                    SizedBox(height: 4),
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
                            onLongPress: _currentStep == 4
                                ? _previewQuote
                                : null,
                            child: ElevatedButton(
                              key: _confirmButtonKey,
                              onPressed: _currentStep == 4
                                  ? () => _saveBooking()
                                  : _continueProject,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(52),
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  right: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _currentStep == 4
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Flexible(
                                          child: Text(
                                            'Confirm Project',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        SizedBox(
                                          width: 28,
                                          height: 32,
                                          child: IconButton(
                                            tooltip: 'Project save options',
                                            padding: EdgeInsets.zero,
                                            style: IconButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(28, 32),
                                              maximumSize: const Size(28, 32),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            onPressed: _showProjectMenu,
                                            icon: AnimatedRotation(
                                              turns: _isProjectMenuOpen
                                                  ? 0.5
                                                  : 0,
                                              duration: const Duration(
                                                milliseconds: 220,
                                              ),
                                              curve: Curves.easeOut,
                                              child: const Icon(
                                                Icons
                                                    .keyboard_arrow_down_rounded,
                                                size: 20,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text('Continue'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_currentStep == 4)
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

class _ProjectMenuOption extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool showDivider;

  const _ProjectMenuOption({
    required this.label,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            indent: 22,
            endIndent: 22,
            color: Colors.white24,
          ),
      ],
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
    const labels = ['Contact', 'Details', 'Products', 'Dates', 'Payment'];
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

class _ProjectTextField extends StatelessWidget {
  const _ProjectTextField({
    required this.controller,
    required this.label,
    required this.imagePath,
    required this.isDark,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String imagePath;
  final bool isDark;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      textCapitalization: keyboardType == TextInputType.emailAddress
          ? TextCapitalization.none
          : TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(13),
          child: SvgPicture.asset(
            imagePath,
            width: 21,
            colorFilter: const ColorFilter.mode(
              AppColors.primary,
              BlendMode.srcIn,
            ),
          ),
        ),
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );
}

class _ProjectDropdownField extends StatelessWidget {
  const _ProjectDropdownField({
    required this.label,
    required this.imagePath,
    required this.isDark,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String imagePath;
  final bool isDark;
  final String? value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderRadius: BorderRadius.circular(14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(13),
          child: SvgPicture.asset(
            imagePath,
            width: 21,
            colorFilter: const ColorFilter.mode(
              AppColors.primary,
              BlendMode.srcIn,
            ),
          ),
        ),
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      items: options
          .map((option) => DropdownMenuItem(value: option, child: Text(option)))
          .toList(),
      onChanged: (selection) {
        if (selection != null) onChanged(selection);
      },
    ),
  );
}

class _ContactInfoCard extends StatelessWidget {
  const _ContactInfoCard({
    required this.name,
    required this.role,
    required this.phone,
    required this.email,
    required this.isDark,
    required this.onTap,
  });

  final String name;
  final String role;
  final String phone;
  final String email;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: .45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .16),
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              AppIcons.profile,
              colorFilter: const ColorFilter.mode(
                AppColors.primary,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  role,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                _ContactLine(icon: AppIcons.phone, text: phone),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _ContactLine(icon: AppIcons.email, text: email),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.text});
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SvgPicture.asset(
        icon,
        width: 17,
        colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    ],
  );
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

int _billableDays(DateTime? start, DateTime? end) {
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

class _DownTriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width / 2, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
