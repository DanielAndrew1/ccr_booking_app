// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/main.dart';
import 'package:ccr_booking/widgets/custom_appbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'home_page.dart' hide NoInternetWidget; // Import to use NoInternetWidget

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => CalendarPageState();
}

class CalendarPageState extends State<CalendarPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ScrollController _todayScrollController = ScrollController();
  final PageController _pageController = PageController(initialPage: 7);
  final ScrollController _dayScrollController = ScrollController();
  final List<GlobalKey> _dayKeys = List.generate(22, (index) => GlobalKey());

  Ticker? _ticker;
  DateTime _selectedDate = DateTime.now().toLocal();
  bool _isLoading = false;

  // Connectivity
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _hasConnection = true;

  final double hourHeight = 60.0;
  final double labelWidth = 75.0;
  final double circleSize = 10.0;
  final double gridLineTopOffset = 10.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _checkStatus,
    );

    _ticker = createTicker((elapsed) {
      if (mounted) setState(() {});
    })..start();

    _fetchBookings();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInitialSnap();
    });
  }

  // --- Connectivity Logic ---
  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _checkStatus(result);
  }

  void _checkStatus(List<ConnectivityResult> result) {
    setState(() {
      _hasConnection = !result.contains(ConnectivityResult.none);
    });
  }

  // --- Public Method (Called by Navbar) ---
  void resetToToday() {
    final now = DateTime.now().toLocal();
    setState(() => _selectedDate = now);

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        7,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
    _scrollDayBarToCenter(7);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _snapToCurrentTime();
    });
  }

  Future<void> _fetchBookings() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) setState(() => _isLoading = false);
  }

  void _handleInitialSnap() {
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      _snapToCurrentTime();
      _scrollDayBarToCenter(7);
    });
  }

  void _snapToCurrentTime() {
    if (!_todayScrollController.hasClients) return;

    final now = DateTime.now().toLocal();
    final double indicatorY =
        (now.hour * hourHeight) +
        (now.minute * (hourHeight / 60.0)) +
        gridLineTopOffset;

    final double viewportHeight =
        _todayScrollController.position.viewportDimension;
    final double targetScroll = (indicatorY + 20.0) - (viewportHeight / 2);

    _todayScrollController.animateTo(
      targetScroll.clamp(0.0, _todayScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.fastLinearToSlowEaseIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: CustomAppBar(text: 'Calendar', showPfp: true),
      body: Column(
        children: [
          if (!_hasConnection) const NoInternetWidget(),
          _buildDaySelector(isDark),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedDate = DateTime.now().toLocal().add(
                          Duration(days: index - 7),
                        );
                      });
                      _scrollDayBarToCenter(index);
                    },
                    itemCount: 22,
                    itemBuilder: (context, pageIndex) {
                      final pageDate = DateTime.now().toLocal().add(
                        Duration(days: pageIndex - 7),
                      );
                      final isToday = isSameDay(
                        pageDate,
                        DateTime.now().toLocal(),
                      );

                      return SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        controller: isToday
                            ? _todayScrollController
                            : ScrollController(),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20.0),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _buildTimeGrid(isDark),
                              if (isToday) _buildTimeIndicator(),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeGrid(bool isDark) {
    return Column(
      children: [
        for (int i = 0; i < 24; i++)
          SizedBox(
            height: hourHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Text(
                    _formatHour(i),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Container(
                    margin: EdgeInsets.only(top: gridLineTopOffset),
                    height: 1.0,
                    color: isDark
                        ? Colors.white10
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            SizedBox(width: labelWidth + 15),
            Expanded(
              child: Container(
                margin: EdgeInsets.only(top: gridLineTopOffset),
                height: 1.0,
                color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 115),
      ],
    );
  }

  Widget _buildTimeIndicator() {
    final now = DateTime.now().toLocal();
    final double positionY =
        (now.hour * hourHeight) +
        (now.minute * (hourHeight / 60.0)) +
        (now.second * (hourHeight / 3600.0)) +
        gridLineTopOffset;

    return Positioned(
      left: labelWidth + 15 - (circleSize / 2),
      top: positionY - (circleSize / 2),
      right: 0,
      child: Row(
        children: [
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(child: Container(height: 2, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildDaySelector(bool isDark) {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkbg : AppColors.lightcolor,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.builder(
        controller: _dayScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: 22,
        itemBuilder: (context, index) {
          DateTime date = DateTime.now().toLocal().add(
            Duration(days: index - 7),
          );
          bool isSelected = isSameDay(_selectedDate, date);
          bool isToday = isSameDay(DateTime.now().toLocal(), date);
          return GestureDetector(
            key: _dayKeys[index],
            onTap: () => _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 65,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: isToday && !isSelected
                    ? Border.all(color: AppColors.primary, width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.grey.shade600),
                    ),
                  ),
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _scrollDayBarToCenter(int index) {
    if (index >= 0 && index < _dayKeys.length) {
      final context = _dayKeys[index].currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 500),
        );
      }
    }
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour == 12) return '12 PM';
    return hour > 12 ? '${hour - 12} PM' : '$hour AM';
  }

  bool isSameDay(DateTime d1, DateTime d2) =>
      d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;

  @override
  void dispose() {
    _ticker?.dispose();
    _connectivitySubscription.cancel();
    _todayScrollController.dispose();
    _dayScrollController.dispose();
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
