import 'package:intl/intl.dart';
import 'package:site_lapse/core/imports.dart';

class ProjectDraftsPage extends StatefulWidget {
  const ProjectDraftsPage({super.key});

  @override
  State<ProjectDraftsPage> createState() => _ProjectDraftsPageState();
}

class _ProjectDraftsPageState extends State<ProjectDraftsPage> {
  final _supabase = Supabase.instance.client;
  final _dateFormat = DateFormat('d MMM yyyy');
  final _currencyFormat = NumberFormat('#,##0', 'en_US');
  List<Map<String, dynamic>> _drafts = [];
  bool _loading = true;
  String? _confirmingId;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    try {
      final rows = await _supabase
          .from('bookings')
          .select()
          .eq('status', 'draft')
          .order('pickup_datetime');
      if (!mounted) return;
      setState(() {
        _drafts = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      CustomSnackBar.show(context, 'Could not load project drafts.');
    }
  }

  Future<void> _confirmDraft(Map<String, dynamic> draft) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm project?'),
        content: Text(
          'This will move ${draft['client_name'] ?? 'this draft'} into your bookings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (approved != true) return;

    final id = draft['id'].toString();
    setState(() => _confirmingId = id);
    try {
      await _supabase
          .from('bookings')
          .update({'status': 'upcoming'})
          .eq('id', id)
          .eq('status', 'draft');
      try {
        await ProjectFinanceService(_supabase).syncProjectFinance(id);
        await BookingOperationsService(_supabase).recordStatus(
          bookingId: id,
          status: 'upcoming',
          note: 'Draft confirmed as booking',
        );
      } catch (error) {
        debugPrint('Draft confirmation setup failed: $error');
      }
      if (!mounted) return;
      setState(() {
        _drafts.removeWhere((item) => item['id'].toString() == id);
        _confirmingId = null;
      });
      CustomSnackBar.show(
        context,
        'Project confirmed and added to bookings.',
        color: AppColors.green,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _confirmingId = null);
      CustomSnackBar.show(context, 'Could not confirm this draft.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: const CustomAppBar(text: 'Project Drafts', showPfp: false),
      body: Stack(
        children: [
          const CustomBgSvg(),
          if (_loading)
            const Center(child: CustomLoader())
          else if (_drafts.isEmpty)
            Center(
              child: Text(
                'No saved drafts',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 16,
                ),
              ),
            )
          else
            RefreshIndicator(
              onRefresh: _loadDrafts,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
                itemCount: _drafts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final draft = _drafts[index];
                  final start = DateTime.tryParse(
                    draft['pickup_datetime']?.toString() ?? '',
                  );
                  final end = DateTime.tryParse(
                    draft['return_datetime']?.toString() ?? '',
                  );
                  final confirming = _confirmingId == draft['id'].toString();
                  return Material(
                    color: isDark
                        ? AppColors.darkSurface
                        : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProjectDetailsPage(booking: draft),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              draft['client_name']?.toString() ?? 'Project',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              start == null || end == null
                                  ? 'Dates not available'
                                  : '${_dateFormat.format(start)} – ${_dateFormat.format(end)}',
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_currencyFormat.format((draft['total_price'] as num?) ?? 0)} EGP',
                              style: const TextStyle(color: AppColors.primary),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: confirming
                                    ? null
                                    : () => _confirmDraft(draft),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                child: confirming
                                    ? const CustomLoader(
                                        size: 20,
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      )
                                    : const Text('Confirm booking'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
