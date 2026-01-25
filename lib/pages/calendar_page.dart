// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/core/theme.dart';
import 'package:ccr_booking/widgets/custom_appbar.dart';
import 'package:ccr_booking/widgets/custom_internet_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';

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

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _checkStatus(result);
  }

  void _checkStatus(List<ConnectivityResult> result) {
    if (mounted) {
      setState(
        () => _hasConnection = !result.contains(ConnectivityResult.none),
      );
    }
  }

  void resetToToday() async {
    HapticFeedback.mediumImpact();
    final now = DateTime.now().toLocal();
    final bool alreadyOnTodayPage = isSameDay(_selectedDate, now);

    setState(() => _selectedDate = now);
    _scrollDayBarToCenter(7);

    if (!alreadyOnTodayPage && _pageController.hasClients) {
      await _pageController.animateToPage(
        7,
        duration: const Duration(milliseconds: 500),
        curve: Curves.fastOutSlowIn,
      );
    }

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
      duration: const Duration(milliseconds: 1000),
      curve: Curves.fastLinearToSlowEaseIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bool isNotToday = !isSameDay(_selectedDate, DateTime.now().toLocal());

    // This block forces the system status bar to follow the app theme
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // Background of the status bar
        statusBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark, // Android icons
        statusBarBrightness: isDark
            ? Brightness.dark
            : Brightness.light, // iOS text/icons
        systemNavigationBarColor: isDark
            ? AppColors.darkbg
            : AppColors.lightcolor,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        // resizeToAvoidBottomInset: false stops the "container artifact" from moving with the keyboard
        resizeToAvoidBottomInset: false,
        backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
        appBar: CustomAppBar(
          text: 'Calendar',
          showPfp: true,
          onTodayPressed: isNotToday ? resetToToday : null,
        ),
        body: Column(
          children: [
            if (!_hasConnection) const NoInternetWidget(),
            _buildCompactDaySelector(isDark),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        HapticFeedback.selectionClick();
                        setState(
                          () => _selectedDate = DateTime.now().toLocal().add(
                            Duration(days: index - 7),
                          ),
                        );
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
      ),
    );
  }

  Widget _buildCompactDaySelector(bool isDark) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkbg : AppColors.lightcolor,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        controller: _dayScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 22,
        itemBuilder: (context, index) {
          DateTime date = DateTime.now().toLocal().add(
            Duration(days: index - 7),
          );
          bool isSelected = isSameDay(_selectedDate, date);
          bool isToday = isSameDay(DateTime.now().toLocal(), date);

          return GestureDetector(
            key: _dayKeys[index],
            onTap: () {
              HapticFeedback.mediumImpact();
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 400),
                curve: Curves.fastOutSlowIn,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 50,
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isToday && !isSelected
                    ? Border.all(color: AppColors.primary, width: 1.5)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white54 : Colors.grey.shade600),
                    ),
                  ),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black),
                      fontSize: 16,
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
                      fontSize: 13,
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
                        : Colors.grey.withOpacity(0.2),
                  ),
                ),
              ],
            ),
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
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(child: Container(height: 1.5, color: AppColors.primary)),
        ],
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
          curve: Curves.fastOutSlowIn,
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
