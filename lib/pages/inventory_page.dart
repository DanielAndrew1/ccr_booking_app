// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/pages/product_page.dart';
import 'package:ccr_booking/widgets/custom_appbar.dart';
import 'package:ccr_booking/widgets/custom_bg_svg.dart';
import 'package:ccr_booking/widgets/custom_loader.dart';
import 'package:ccr_booking/widgets/custom_product_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ccr_booking/main.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  Key _streamKey = UniqueKey();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _hasConnection = true;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      // 1. THIS IS THE KEY: It allows the body to start from the top of the screen
      extendBodyBehindAppBar: true,
      appBar: const CustomAppBar(text: 'Inventory', showPfp: true),
      body: Stack(
        children: [
          // 2. MATCHED TO HOME PAGE: top: 80, right: 0
          CustomBgSvg(),
          // 3. Add SafeArea or Padding to the Column so content doesn't hide behind AppBar
          Column(
            children: [
              const SizedBox(height: 160), // Height of AppBar + some spacing
              if (!_hasConnection) const NoInternetWidget(),
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    CupertinoSliverRefreshControl(
                      refreshTriggerPullDistance: 50.0,
                      refreshIndicatorExtent: 40.0,
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

                        final products = snapshot.data!;
                        return SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final product = products[index];
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
                            }, childCount: products.length),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
