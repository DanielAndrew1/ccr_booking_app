// ignore_for_file: deprecated_member_use

import 'package:ccr_booking/pages/edit_booking.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../core/imports.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final ScrollController _calendarScrollController = ScrollController();

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  List<Map<String, dynamic>> _pickups = [];
  List<Map<String, dynamic>> _returns = [];

  final int daysBehind = 30;
  final int daysAhead = 30;

  @override
  void initState() {
    super.initState();
    _fetchDayBookings();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToToday(animate: false);
    });
  }

  void _scrollToToday({bool animate = true}) {
    if (_calendarScrollController.hasClients) {
      const double itemWidth = 85.0;
      final double screenWidth = MediaQuery.of(context).size.width;

      final double offset =
          (daysBehind * itemWidth) - (screenWidth / 2) + (itemWidth / 2) + 7.5;

      if (animate) {
        _calendarScrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
        );
      } else {
        _calendarScrollController.jumpTo(offset);
      }
    }
  }

  Future<void> _fetchDayBookings() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final startOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    ).toIso8601String();
    final endOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      23,
      59,
      59,
    ).toIso8601String();

    try {
      final pickupData = await supabase
          .from('bookings')
          .select()
          .gte('pickup_datetime', startOfDay)
          .lte('pickup_datetime', endOfDay)
          .neq('status', 'cancelled');
      final returnData = await supabase
          .from('bookings')
          .select()
          .gte('return_datetime', startOfDay)
          .lte('return_datetime', endOfDay)
          .neq('status', 'cancelled');

      if (mounted) {
        setState(() {
          _pickups = List<Map<String, dynamic>>.from(pickupData);
          _returns = List<Map<String, dynamic>>.from(returnData);
        });
      }
    } catch (e) {
      if (mounted) CustomSnackBar.show(context, "Error loading bookings: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBooking(String id) async {
    try {
      await supabase
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('id', id);

      CustomSnackBar.show(context, "Booking deleted successfully");

      _fetchDayBookings();
    } catch (e) {
      CustomSnackBar.show(context, "Error deleting booking: $e");
    }
  }

  void _showBookingDetails(Map<String, dynamic> booking) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    final bool isDark = themeProvider.isDarkMode;
    final currencyFormat = NumberFormat("#,##0", "en_US");

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252525) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Booking Details",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            indexPage = 4;
                            

                            // 1. Set the booking data for the Add/Edit page to read
                            Provider.of<BookingProvider>(
                              context,
                              listen: false,
                            ).setEditingBooking(booking);

                            // 2. Tell the Navbar to enter "Edit Mode"
                            Provider.of<NavbarProvider>(
                              context,
                              listen: false,
                            ).setEditMode(true);

                            // 3. Close the dialog
                            Navigator.pop(dialogContext);

                            // 4. Switch the Navbar index to the middle tab (index 2)
                            Provider.of<NavbarProvider>(
                              context,
                              listen: false,
                            ).setIndex(2);
                          },
                          borderRadius: BorderRadius.circular(50),
                          child: Ink(
                            padding: const EdgeInsets.all(10),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: SvgPicture.asset(
                              "assets/message-edit.svg",
                              colorFilter: ColorFilter.mode(
                                isDark ? Colors.white : Colors.black,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(
                    height: 32,
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                  _detailRow(
                    "Client",
                    booking['client_name'] ?? "N/A",
                    "assets/profile-2user.svg",
                    isDark,
                  ),
                  _detailRow(
                    "Products",
                    (booking['product_names'] as List? ?? []).join(", "),
                    "assets/box.svg",
                    isDark,
                  ),
                  _detailRow(
                    "Pickup Date",
                    DateFormat(
                      'dd MMM yyyy',
                    ).format(DateTime.parse(booking['pickup_datetime'])),
                    "assets/send-square.svg",
                    isDark,
                  ),
                  _detailRow(
                    "Return Date",
                    DateFormat(
                      'dd MMM yyyy',
                    ).format(DateTime.parse(booking['return_datetime'])),
                    "assets/vuesax.svg",
                    isDark,
                  ),
                  _detailRow(
                    "Total Price",
                    "${currencyFormat.format(booking['total_price'])} EGP",
                    "assets/wallet.svg",
                    isDark,
                    valueColor: isDark
                        ? AppColors.primary
                        : AppColors.secondary,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: "Done",
                      onPressed: () async => Navigator.pop(dialogContext),
                      color: WidgetStateProperty.all(
                        isDark ? AppColors.primary : AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(
    String label,
    String value,
    String imagePath,
    bool isDark, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SvgPicture.asset(
              imagePath,
              width: 22,
              color: isDark ? AppColors.primary : AppColors.secondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color:
                        valueColor ?? (isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    final now = DateTime.now();
    final bool isNotToday =
        _selectedDate.year != now.year ||
        _selectedDate.month != now.month ||
        _selectedDate.day != now.day;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: CustomAppBar(
        onTodayPressed: isNotToday
            ? () {
                setState(() => _selectedDate = DateTime.now());
                _fetchDayBookings();
                _scrollToToday();
              }
            : null,
        text: "Bookings",
        showPfp: true,
      ),
      body: Stack(
        children: [
          const CustomBgSvg(),
          SafeArea(
            child: Column(
              children: [
                _buildCalendarStrip(isDark),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CustomLoader())
                      : RefreshIndicator(
                          onRefresh: _fetchDayBookings,
                          color: AppColors.primary,
                          backgroundColor: isDark
                              ? const Color(0xFF2A2A2A)
                              : Colors.white,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 10),
                                _buildSectionHeader(
                                  "Pickups",
                                  _pickups.length,
                                  AppColors.primary,
                                  isDark,
                                ),
                                const SizedBox(height: 16),
                                _buildBookingList(
                                  _pickups,
                                  isDark,
                                  isPickup: true,
                                ),
                                const SizedBox(height: 32),
                                _buildSectionHeader(
                                  "Returns",
                                  _returns.length,
                                  AppColors.secondary,
                                  isDark,
                                ),
                                const SizedBox(height: 16),
                                _buildBookingList(
                                  _returns,
                                  isDark,
                                  isPickup: false,
                                ),
                                const SizedBox(height: 120),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarStrip(bool isDark) {
    return Container(
      height: 115,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        controller: _calendarScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: daysBehind + 1 + daysAhead,
        itemBuilder: (context, index) {
          final date = DateTime.now()
              .subtract(Duration(days: daysBehind))
              .add(Duration(days: index));
          final isSelected = DateUtils.isSameDay(date, _selectedDate);
          final isToday = DateUtils.isSameDay(date, DateTime.now());

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedDate = date);
              _fetchDayBookings();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 70,
              margin: const EdgeInsets.only(left: 15),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? const Color(0xFF252525) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: isToday && !isSelected
                    ? Border.all(
                        color: AppColors.primary.withOpacity(0.5),
                        width: 2,
                      )
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.7),
                          blurRadius: 4,
                          offset: const Offset(0, 0),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.transparent,
                          blurRadius: 0,
                          offset: const Offset(0, 0),
                        ),
                      ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(date).toUpperCase(),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white.withOpacity(0.8)
                          : (isToday ? AppColors.primary : Colors.grey),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    DateFormat('MMM').format(date).toUpperCase(),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white.withOpacity(0.8)
                          : Colors.grey,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    int count,
    Color color,
    bool isDark,
  ) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "$count",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingList(
    List<Map<String, dynamic>> bookings,
    bool isDark, {
    required bool isPickup,
  }) {
    if (bookings.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.03)
              : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Column(
          children: [
            SvgPicture.asset(
              isPickup ? "assets/send-square.svg" : "assets/vuesax.svg",
              width: 40,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            const SizedBox(height: 12),
            Text(
              "No ${isPickup ? 'pickups' : 'returns'} for today",
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final accentColor = isPickup ? AppColors.primary : AppColors.secondary;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Slidable(
              key: ValueKey(booking['id']),
              endActionPane: ActionPane(
                motion: const ScrollMotion(),
                extentRatio: 0.28,
                children: [
                  CustomSlidableAction(
                    onPressed: (context) =>
                        _deleteBooking(booking['id'].toString()),
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          "assets/trash.svg",
                          height: 22,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _showBookingDetails(booking);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252525) : Colors.white,
                    border: isDark
                        ? null
                        : Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(isDark ? 0.15 : 0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: SvgPicture.asset(
                          isPickup
                              ? "assets/send-square.svg"
                              : "assets/vuesax.svg",
                          width: 26,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking['client_name'] ?? 'Unknown Client',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.grey.withOpacity(0.4),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
