// ignore_for_file: deprecated_member_use, use_build_context_synchronously, unused_field, unused_element

import 'package:flutter/cupertino.dart';
import '../core/imports.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  int? _expandedIndex;
  Key _refreshKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  void _fetchClients() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserProvider>(context, listen: false).fetchAllClients();
      Provider.of<BookingProvider>(context, listen: false).fetchAllBookings();
    });
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return "?";
    List<String> nameParts = name.trim().split(RegExp(r'\s+'));
    if (nameParts.length >= 2) {
      return (nameParts[0][0] + nameParts[1][0]).toUpperCase();
    }
    return nameParts[0][0].toUpperCase();
  }

  Map<String, dynamic> _calculateClientStats(
    String clientName,
    List<dynamic> allBookings,
  ) {
    // Normalize the target name for comparison
    final normalizedTargetName = clientName.trim().toLowerCase();

    // Filter by name (case-insensitive & trimmed) and ensure status isn't canceled or deleted
    final clientBookings = allBookings.where((b) {
      if (b is Map<String, dynamic>) {
        final bName = (b['client_name'] ?? "").toString().trim().toLowerCase();
        final bStatus = (b['status'] ?? "").toString().toLowerCase();
        return bName == normalizedTargetName &&
            bStatus != 'cancelled' &&
            bStatus != 'canceled' &&
            bStatus != 'deleted';
      }
      return false;
    }).toList();

    double totalRevenue = 0.0;
    for (var booking in clientBookings) {
      if (booking is Map<String, dynamic>) {
        final amount = booking['total_price'];
        if (amount != null) {
          totalRevenue += double.tryParse(amount.toString()) ?? 0.0;
        }
      }
    }

    return {'count': clientBookings.length, 'revenue': totalRevenue};
  }

  Future<void> _executeDelete(String clientId, String clientName) async {
    HapticFeedback.selectionClick();
    await Provider.of<UserProvider>(
      context,
      listen: false,
    ).deleteClient(clientId);
    CustomSnackBar.show(
      context,
      "$clientName removed successfully",
      color: AppColors.green,
    );
  }

  void _removeClient(String clientId, String clientName) {
    HapticFeedback.selectionClick();
    showCupertinoDialog(
      context: context,
      builder: (context) => CustomAlertDialogue(
        icon: AppIcons.trash,
        title: "Delete Client",
        body: 'Are you sure you want to delete "$clientName" ?',
        confirm: "Delete",
      ),
    );
  }

  void _editClientDialog(dynamic client) {
    final rootContext = context;
    final nameController = TextEditingController(text: client.name);
    final emailController = TextEditingController(text: client.email);
    final phoneController = TextEditingController(text: client.phone ?? "");
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: 350,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkbg : AppColors.lightcolor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Edit Client",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: _inputDeco("Full Name"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: _inputDeco("Email Address"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: _inputDeco("Phone Number"),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      "Save",
                      AppIcons.edit,
                      isDark,
                      () async {
                        final updatedData = {
                          'name': nameController.text.trim(),
                          'email': emailController.text.trim(),
                          'phone': phoneController.text.trim(),
                        };
                        await Provider.of<UserProvider>(
                          rootContext,
                          listen: false,
                        ).updateClient(client.id, updatedData);
                        if (!mounted) return;
                        Navigator.pop(dialogContext);
                        CustomSnackBar.show(
                          rootContext,
                          "Client updated successfully!",
                          color: AppColors.green,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final userProvider = Provider.of<UserProvider>(context);
    final bookingProvider = Provider.of<BookingProvider>(context);

    final allBookings = bookingProvider.allBookings;
    final clients = userProvider.allClients;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent,
      ),
      child: Container(
        color: isDark ? AppColors.darkbg : AppColors.lightcolor,
        child: Stack(
          children: [
            const CustomBgSvg(),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: const CustomAppBar(
                text: 'Manage Clients',
                showPfp: false,
              ),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endFloat,
              floatingActionButton: Padding(
                padding: const EdgeInsets.only(bottom: 50),
                child: FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddClient()),
                    );
                  },
                  backgroundColor: AppColors.primary,
                  child: SvgPicture.asset(
                    AppIcons.add,
                    color: Colors.white,
                    width: 30,
                  ),
                ),
              ),
              body: CustomScrollView(
                key: _refreshKey,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  CupertinoSliverRefreshControl(
                    onRefresh: () async {
                      _fetchClients();
                      await Future.delayed(const Duration(seconds: 1));
                      if (mounted) setState(() => _refreshKey = UniqueKey());
                    },
                  ),
                  userProvider.isLoading || bookingProvider.isLoading
                      ? const SliverFillRemaining()
                      : clients.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Text(
                              "No clients yet.",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 10,
                            bottom: 110,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final stats = _calculateClientStats(
                                clients[index].name,
                                allBookings,
                              );
                              return _buildClientCard(
                                clients[index],
                                isDark,
                                stats['count'],
                                stats['revenue'],
                              );
                            }, childCount: clients.length),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientCard(
    dynamic client,
    bool isDark,
    int bookings,
    double revenue,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2C2C2C).withOpacity(0.75)
            : Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary,
                child: Text(
                  _getInitials(client.name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _buildContactRow(
                      AppIcons.phone,
                      client.phone ?? "No phone",
                      isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatBox(
                "Total Bookings",
                "$bookings",
                AppIcons.medal,
                isDark,
                borderColor: AppColors.secondary,
              ),
              const SizedBox(width: 10),
              _buildStatBox(
                "Total Revenue",
                "$revenue EGP",
                AppIcons.wallet,
                isDark,
                borderColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  "Edit Client",
                  AppIcons.edit,
                  isDark,
                  () => _editClientDialog(client),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  "Delete",
                  AppIcons.trash,
                  isDark,
                  () => _removeClient(client.id, client.name),
                  isDelete: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(String imagePath, String text, bool isDark) {
    return Row(
      children: [
        SvgPicture.asset(
          imagePath,
          width: 18,
          color: isDark ? Colors.white60 : Colors.black45,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox(
    String label,
    String value,
    String imagePath,
    bool isDark, {
    Color? borderColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: borderColor?.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor ?? Colors.grey),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgPicture.asset(
              imagePath,
              width: 18,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black54,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    String imagePath,
    bool isDark,
    VoidCallback onTap, {
    bool isDelete = false,
  }) {
    return InkWell(
      overlayColor: WidgetStateProperty.all(
        isDelete ? Colors.white.withOpacity(0.2) : AppColors.primary.withOpacity(0.3),
      ),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDelete ? AppColors.red : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDelete ? Colors.transparent : AppColors.primary,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              imagePath,
              width: 18,
              color: isDelete ? Colors.white : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDelete ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
