// ignore_for_file: deprecated_member_use, unused_field

import 'package:flutter/cupertino.dart';
import '../core/imports.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  Key _streamKey = UniqueKey();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _hasConnection = true;

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

    // Determine the refresh indicator color based on your requirements
    final Color refreshColor = isDark ? AppColors.primary : AppColors.secondary;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
        resizeToAvoidBottomInset: false,
        extendBodyBehindAppBar: true,
        appBar: CustomAppBar(
          text: _isSearching ? "" : 'Inventory',
          showPfp: false,
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
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.toLowerCase()),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(right: 25),
              child: GestureDetector(
                onTap: () {
                  if (_isSearching) {
                    _searchController.clear();
                    setState(() => _searchQuery = "");
                    FocusScope.of(context).unfocus();
                  } else {
                    setState(() => _isSearching = true);
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isSearching
                        ? Colors.transparent
                        : AppColors.primary.withAlpha(70),
                  ),
                  child: _isSearching
                      ? const Icon(Icons.close, color: Colors.red, size: 30)
                      : IconHandler.buildIcon(
                          imagePath: "assets/search-normal.svg",
                          color: AppColors.primary,
                          size: 22,
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
                // Removed local NoInternetWidget because it is now managed globally by MyApp overlay
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      CupertinoSliverRefreshControl(
                        // Customizing the color of the spinner
                        builder:
                            (
                              context,
                              refreshState,
                              pulledExtent,
                              refreshTriggerPullDistance,
                              refreshIndicatorExtent,
                            ) {
                              return Center(
                                child: CupertinoActivityIndicator(
                                  radius: 14,
                                  color: refreshColor,
                                ),
                              );
                            },
                        onRefresh: () async {
                          setState(() => _streamKey = UniqueKey());
                          await Future.delayed(const Duration(seconds: 2));
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
                          final filteredProducts = snapshot.data!
                              .where(
                                (p) => p['name']
                                    .toString()
                                    .toLowerCase()
                                    .contains(_searchQuery),
                              )
                              .toList();
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
