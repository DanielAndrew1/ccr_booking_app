// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/core/user_provider.dart';
import 'package:ccr_booking/widgets/custom_appbar.dart';
import 'package:ccr_booking/widgets/custom_loader.dart';
import 'package:flutter/cupertino.dart'; // Added for CupertinoSliverRefreshControl
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
      // Assuming your UserProvider has a fetchClients method
      Provider.of<UserProvider>(context, listen: false).fetchAllClients();
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

  void _removeClient(String clientId, String clientName) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirm Delete"),
        content: Text("Are you sure you want to remove $clientName?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              // Update this to your provider's delete client method
              Provider.of<UserProvider>(
                context,
                listen: false,
              ).deleteClient(clientId);
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProvider = Provider.of<UserProvider>(context);
    final clients =
        userProvider.allClients; // Assuming this exists in your provider

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: const CustomAppBar(text: 'Manage Clients', showPfp: false),
      body: CustomScrollView(
        key: _refreshKey,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // Cupertino Refresh Control with Custom Loader
          CupertinoSliverRefreshControl(
            refreshTriggerPullDistance: 200.0,
            refreshIndicatorExtent: 100.0,
            onRefresh: () async {
              _fetchClients();
              await Future.delayed(const Duration(seconds: 2));
              if (mounted) {
                setState(() {
                  _refreshKey = UniqueKey();
                });
              }
            },
            builder:
                (
                  context,
                  refreshState,
                  pulledExtent,
                  refreshTriggerPullDistance,
                  refreshIndicatorExtent,
                ) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: CustomLoader(size: 24),
                    ),
                  );
                },
          ),

          // Content Area
          userProvider.isLoading
              ? const SliverFillRemaining(child: Center(child: CustomLoader()))
              : clients.isEmpty
              ? const SliverFillRemaining(
                  child: Center(child: Text("No clients found")),
                )
              : SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final client = clients[index];
                      final bool isExpanded = _expandedIndex == index;

                      return _buildClientCard(
                        client: client,
                        isDark: isDark,
                        index: index,
                        isExpanded: isExpanded,
                      );
                    }, childCount: clients.length),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildClientCard({
    required dynamic client,
    required bool isDark,
    required int index,
    bool isExpanded = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: isDark
                  ? AppColors.primary.withOpacity(0.2)
                  : AppColors.secondary.withOpacity(0.2),
              child: Text(
                _getInitials(client.name),
                style: TextStyle(
                  color: isDark ? AppColors.primary : AppColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              client.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Text(client.email ?? "No email provided"),
            trailing: AnimatedRotation(
              duration: const Duration(milliseconds: 300),
              turns: isExpanded ? 0.5 : 0,
              child: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
            ),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _expandedIndex = isExpanded ? null : index;
              });
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: isExpanded
                ? _buildActionButtons(client)
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(dynamic client) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      // Navigate to client detail or edit page
                    },
                    child: const Center(
                      child: Text(
                        "View Profile",
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _removeClient(client.id, client.name),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text(
                    "Delete",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
