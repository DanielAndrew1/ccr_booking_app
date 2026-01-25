// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/core/theme.dart';
import 'package:ccr_booking/pages/product_page.dart';
import 'package:ccr_booking/widgets/custom_appbar.dart';
import 'package:ccr_booking/widgets/custom_bg_svg.dart';
import 'package:ccr_booking/widgets/custom_internet_notification.dart';
import 'package:ccr_booking/widgets/custom_loader.dart';
import 'package:ccr_booking/widgets/custom_product_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  Key _streamKey = UniqueKey();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _hasConnection = true;

  // --- Search Logic ---
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _checkStatus,
    );
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

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
        // This stops THIS scaffold from moving, but if your navbar is in a parent
        // scaffold, you must apply this setting there as well.
        resizeToAvoidBottomInset: false,

        extendBodyBehindAppBar: true,
        appBar: CustomAppBar(
          text: _isSearching ? "" : 'Inventory',
          showPfp: !_isSearching,
          hideLeading: _isSearching,
          actions: [
            if (_isSearching) ...[
              IconButton(
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    _searchQuery = "";
                    FocusScope.of(context).unfocus();
                  });
                },
                icon: Icon(
                  Icons.adaptive.arrow_back_rounded,
                  color: Colors.white,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofocus: true,
                  // FIX: Forces the keyboard to be dark or light based on your theme
                  keyboardAppearance: isDark
                      ? Brightness.dark
                      : Brightness.light,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(
                    hintText: 'Search...',
                    hintStyle: TextStyle(color: Colors.white60),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(right: 25),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isSearching
                      ? Colors.transparent
                      : AppColors.primary.withAlpha(70),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    if (_isSearching) {
                      _searchController.clear();
                      setState(() => _searchQuery = "");
                    } else {
                      setState(() => _isSearching = true);
                    }
                  },
                  icon: Icon(
                    _isSearching ? Icons.close : Icons.search,
                    color: _isSearching ? Colors.red : AppColors.primary,
                    size: _isSearching ? 30 : 25,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            const CustomBgSvg(),
            Column(
              children: [
                const SizedBox(height: 140),
                if (!_hasConnection) const NoInternetWidget(),
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      CupertinoSliverRefreshControl(
                        onRefresh: () async {
                          setState(() => _streamKey = UniqueKey());
                          await Future.delayed(const Duration(seconds: 2));
                        },
                        builder:
                            (
                              context,
                              refreshState,
                              pulledExtent,
                              refreshTriggerPullDistance,
                              refreshIndicatorExtent,
                            ) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: CustomLoader(size: 24),
                                ),
                              );
                            },
                      ),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        key: _streamKey,
                        stream: Supabase.instance.client
                            .from('products')
                            .stream(primaryKey: ['id'])
                            .order('name'),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SliverFillRemaining(
                              child: Center(child: CustomLoader()),
                            );
                          }

                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const SliverFillRemaining(
                              child: Center(child: Text("No products yet.")),
                            );
                          }

                          final allProducts = snapshot.data!;
                          final filteredProducts = allProducts.where((product) {
                            final name = (product['name'] ?? '')
                                .toString()
                                .toLowerCase();
                            return name.contains(_searchQuery);
                          }).toList();

                          if (filteredProducts.isEmpty) {
                            return SliverFillRemaining(
                              child: Center(
                                child: Text(
                                  'No items match "${_searchController.text}"',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            );
                          }

                          return SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final product = filteredProducts[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: CustomProductTile(
                                    title: product['name'] ?? 'Unnamed',
                                    price: (product['price'] as num).toDouble(),
                                    imageUrl: product['image_url'],
                                    route: ProductPage(
                                      productId: product['id'].toString(),
                                    ),
                                  ),
                                );
                              }, childCount: filteredProducts.length),
                            ),
                          );
                        },
                      ),
                      // Optional: Add space at bottom if keyboard covers results
                      if (_isSearching)
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: MediaQuery.of(context).viewInsets.bottom,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
