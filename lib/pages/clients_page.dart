// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/widgets/custom_appbar.dart';
import 'package:ccr_booking/widgets/custom_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'home_page.dart'; // To access NoInternetWidget

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final supabase = Supabase.instance.client;
  int? _expandedIndex;
  List<Map<String, dynamic>> _clients = [];
  bool _isLoading = true;

  // Connectivity
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _hasConnection = true;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _checkStatus,
    );
    _fetchClients();
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _checkStatus(result);
  }

  void _checkStatus(List<ConnectivityResult> result) {
    setState(() => _hasConnection = !result.contains(ConnectivityResult.none));
  }

  Future<void> _fetchClients() async {
    try {
      final response = await supabase.from('clients').select().order('name');
      setState(() {
        _clients = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error fetching clients: $e");
    }
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return "?";
    List<String> nameParts = name.trim().split(RegExp(r'\s+'));
    if (nameParts.length >= 2) {
      return (nameParts[0][0] + nameParts[1][0]).toUpperCase();
    }
    return nameParts[0][0].toUpperCase();
  }

  void _deleteClient(String clientId, String clientName) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirm Delete"),
        content: Text(
          "Are you sure you want to remove $clientName from your records?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await supabase.from('clients').delete().eq('id', clientId);
              Navigator.pop(context);
              _fetchClients();
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: const CustomAppBar(text: 'Manage Clients', showPfp: false),
      body: Column(
        children: [
          if (!_hasConnection) const NoInternetWidget(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _isLoading
                  ? Center(child: CustomLoader())
                  : RefreshIndicator(
                      onRefresh: _fetchClients,
                      color: AppColors.primary,
                      child: _clients.isEmpty
                          ? const Center(child: Text("No clients found"))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _clients.length,
                              itemBuilder: (context, index) {
                                final client = _clients[index];
                                return _buildClientCard(
                                  client: client,
                                  isDark: isDark,
                                  index: index,
                                  isExpanded: _expandedIndex == index,
                                );
                              },
                            ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientCard({
    required Map<String, dynamic> client,
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
      child: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
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
                  _getInitials(client['name'] ?? ""),
                  style: TextStyle(
                    color: isDark ? AppColors.primary : AppColors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                client['name'] ?? "Unknown",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(client['email'] ?? "No email provided"),
              trailing: AnimatedRotation(
                duration: const Duration(milliseconds: 300),
                turns: isExpanded ? 0.5 : 0,
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.grey,
                ),
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
                  ? _buildActionButtons(client, isDark)
                  : const SizedBox(width: double.infinity, height: 0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> client, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              // Edit Info Button (Styled like "Change Role" from UsersPage)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    // Logic to navigate to Edit Client page
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        "Edit Info",
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
              // Delete Button (Styled like "Remove User" from UsersPage)
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
                  onPressed: () => _deleteClient(
                    client['id'].toString(),
                    client['name'] ?? "",
                  ),
                  icon: const Icon(Icons.person_remove_outlined, size: 18),
                  label: const Text(
                    "Remove Client",
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
