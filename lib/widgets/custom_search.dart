// ignore_for_file: deprecated_member_use, unnecessary_underscores

import '../core/imports.dart';

class CustomSearch extends StatefulWidget {
  final Function(Map<String, dynamic>) onClientSelected;

  const CustomSearch({super.key, required this.onClientSelected});

  @override
  State<CustomSearch> createState() => CustomSearchState(); // Removed underscore
}

class CustomSearchState extends State<CustomSearch> {
  // Removed underscore
  final SupabaseClient supabase = Supabase.instance.client;

  String selectedClientName = '';
  List<Map<String, dynamic>> allClients = [];
  List<Map<String, dynamic>> filteredClients = [];
  bool isLoading = false;

  // Added this method to be called from the parent
  void clear() {
    setState(() {
      selectedClientName = '';
      filteredClients = allClients;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  Future<void> _fetchClients() async {
    setState(() => isLoading = true);
    try {
      final data = await supabase.from('clients').select();
      setState(() {
        allClients = List<Map<String, dynamic>>.from(data);
        filteredClients = allClients;
      });
    } catch (e) {
      debugPrint("Error fetching clients: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _filterClients(String query) {
    setState(() {
      final searchLower = query.toLowerCase();
      filteredClients = allClients.where((client) {
        final name = client['name'].toString().toLowerCase();
        final phone = client['phone'].toString().toLowerCase();
        return name.contains(searchLower) || phone.contains(searchLower);
      }).toList();
    });
  }

  void _showSearchSheet() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Select Client",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: "Search name or phone number...",
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SvgPicture.asset(
                        "assets/search-normal.svg",
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(
                          isDark ? Colors.white38 : Colors.grey,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    _filterClients(val);
                    setModalState(() {});
                  },
                ),
                const SizedBox(height: 15),
                Expanded(
                  child: isLoading
                      ? const Center(child: CustomLoader())
                      : filteredClients.isEmpty
                      ? Center(
                          child: Text(
                            "No clients found",
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.grey,
                            ),
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredClients.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: isDark ? Colors.white10 : Colors.grey[200],
                          ),
                          itemBuilder: (context, index) {
                            final client = filteredClients[index];

                            String initials = '';
                            if (client['name'] != null) {
                              final names = client['name'].toString().split(
                                ' ',
                              );
                              if (names.isNotEmpty) {
                                initials += names[0][0].toUpperCase();
                              }
                              if (names.length > 1) {
                                initials += names[1][0].toUpperCase();
                              }
                            }

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 4,
                              ),
                              title: Text(
                                client['name'],
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              subtitle: Text(
                                client['phone'],
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: Colors.grey,
                              ),
                              onTap: () {
                                setState(
                                  () => selectedClientName = client['name'],
                                );
                                widget.onClientSelected(client);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Client",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showSearchSheet,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SvgPicture.asset(
                  "assets/user-search.svg",
                  color: selectedClientName.isEmpty
                      ? Colors.grey
                      : AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedClientName.isEmpty
                        ? "Search client"
                        : selectedClientName,
                    style: TextStyle(
                      color: selectedClientName.isEmpty
                          ? const Color(0xFF6A6A6A)
                          : (isDark ? Colors.white : Colors.black),
                      fontSize: 16,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.white70),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
