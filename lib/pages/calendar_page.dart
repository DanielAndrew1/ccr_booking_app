// ignore_for_file: deprecated_member_use

import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/widgets/custom_appbar.dart';
import 'package:ccr_booking/widgets/custom_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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

  final double hourHeight = 60.0;
  final double gridLineTopOffset = 10.0;
  final double labelWidth = 75.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((_) {
      if (mounted) setState(() {});
    })..start();
    _fetchBookings();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleInitialSnap());
  }

  Future<void> _fetchBookings() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1)); // Simulate DB fetch
    if (mounted) setState(() => _isLoading = false);
  }

  void _handleInitialSnap() {
    _snapToCurrentTime();
    _scrollDayBarToCenter(7);
  }

  void _snapToCurrentTime() {
    if (!_todayScrollController.hasClients) return;
    final now = DateTime.now().toLocal();
    final double indicatorY =
        (now.hour * hourHeight) +
        (now.minute * (hourHeight / 60.0)) +
        gridLineTopOffset;
    _todayScrollController.animateTo(
      indicatorY - 200,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: CustomAppBar(text: 'Calendar', showPfp: true),
      body: RefreshIndicator(
        onRefresh: _fetchBookings,
        color: AppColors.primary,
        child: Column(
          children: [
            _buildDaySelector(isDark),
            Expanded(
              child: _isLoading
                  ? Center(child: CustomLoader())
                  : PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(
                          () => _selectedDate = DateTime.now().toLocal().add(
                            Duration(days: index - 7),
                          ),
                        );
                        _scrollDayBarToCenter(index);
                      },
                      itemCount: 22,
                      itemBuilder: (context, index) {
                        final isToday = index == 7;
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          controller: isToday ? _todayScrollController : null,
                          child: Stack(
                            children: [
                              _buildTimeGrid(isDark),
                              if (isToday) _buildTimeIndicator(),
                            ],
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

  Widget _buildTimeGrid(bool isDark) {
    return Column(
      children: [
        for (int i = 0; i < 24; i++)
          SizedBox(
            height: hourHeight,
            child: Row(
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Text(
                    _formatHour(i),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Divider(
                    color: isDark
                        ? Colors.white10
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildTimeIndicator() {
    final now = DateTime.now().toLocal();
    final double positionY =
        (now.hour * hourHeight) +
        (now.minute * (hourHeight / 60.0)) +
        gridLineTopOffset;
    return Positioned(
      top: positionY,
      left: labelWidth + 10,
      right: 0,
      child: Row(
        children: [
          CircleAvatar(radius: 5, backgroundColor: AppColors.primary),
          Expanded(child: Container(height: 2, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildDaySelector(bool isDark) {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        controller: _dayScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: 22,
        itemBuilder: (context, index) {
          final date = DateTime.now().toLocal().add(Duration(days: index - 7));
          final isSelected = isSameDay(_selectedDate, date);
          return GestureDetector(
            key: _dayKeys[index],
            onTap: () => _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.ease,
            ),
            child: Container(
              width: 60,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey,
                    ),
                  ),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black),
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

  String _formatHour(int h) => h == 0
      ? '12 AM'
      : h == 12
      ? '12 PM'
      : h > 12
      ? '${h - 12} PM'
      : '$h AM';
  bool isSameDay(DateTime d1, DateTime d2) =>
      d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  void _scrollDayBarToCenter(int i) {
    if (_dayKeys[i].currentContext != null)
      Scrollable.ensureVisible(_dayKeys[i].currentContext!, alignment: 0.5);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _todayScrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}
