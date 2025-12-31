// ignore_for_file: deprecated_member_use

import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/widgets/custom_appbar.dart';
import 'package:ccr_booking/widgets/custom_loader.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// 1. Keep this GlobalKey accessible so the Navbar can reach it
final GlobalKey<CalendarPageState> calendarKey = GlobalKey<CalendarPageState>();

class CalendarPage extends StatefulWidget {
  // FIXED: Removed the redundant 'key' assignment that caused your error
  CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => CalendarPageState();
}

class CalendarPageState extends State<CalendarPage> {
  final PageController _pageController = PageController(initialPage: 7);
  DateTime _selectedDate = DateTime.now().toLocal();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  // Navbar reset method: This is what the Navbar calls via the GlobalKey
  void resetToToday() {
    setState(() => _selectedDate = DateTime.now().toLocal());
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        7,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _fetchBookings() async {
    setState(() => _isLoading = true);
    // Logic to fetch from Supabase would go here
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _isLoading = false);
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
        child: _isLoading
            ? Center(child: CustomLoader())
            : Column(
                children: [
                  _buildDaySelector(isDark),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: 22, // 1 week past, today, 2 weeks future
                      onPageChanged: (index) {
                        setState(() {
                          _selectedDate = DateTime.now().toLocal().add(
                            Duration(days: index - 7),
                          );
                        });
                      },
                      itemBuilder: (context, index) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            height: 1440, // 24 hours * 60 pixels
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: Column(
                              children: List.generate(
                                24,
                                (i) => SizedBox(
                                  height: 60,
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 50,
                                        child: Text(
                                          "$i:00",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.black54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: isDark
                                              ? Colors.white10
                                              : Colors.black12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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

  Widget _buildDaySelector(bool isDark) {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 22,
        itemBuilder: (context, index) {
          final date = DateTime.now().toLocal().add(Duration(days: index - 7));
          final isSelected =
              date.day == _selectedDate.day &&
              date.month == _selectedDate.month;

          return GestureDetector(
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
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
}
