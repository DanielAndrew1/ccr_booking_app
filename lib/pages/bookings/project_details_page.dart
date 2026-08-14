import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:site_lapse/core/imports.dart';
import 'package:url_launcher/url_launcher.dart';

class ProjectDetailsPage extends StatefulWidget {
  const ProjectDetailsPage({super.key, required this.booking});

  final Map<String, dynamic> booking;

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> {
  final _supabase = Supabase.instance.client;
  final _currency = NumberFormat('#,##0', 'en_US');
  List<Map<String, dynamic>> _products = [];
  String? _contractUrl;
  bool _loading = true;

  DateTime get _start => DateTime.parse(widget.booking['pickup_datetime']);
  DateTime get _end => DateTime.parse(widget.booking['return_datetime']);

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final bookingId = widget.booking['id'].toString();
      final rawItems = await _supabase
          .from('booking_items')
          .select('quantity, unit_price, products(*)')
          .eq('booking_id', bookingId);
      final rawAssignments = await _supabase
          .from('booking_serial_assignments')
          .select('product_id, product_serials(serial_number)')
          .eq('booking_id', bookingId);
      final serialsByProduct = <String, List<String>>{};
      for (final raw in rawAssignments as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final serial = row['product_serials'] as Map?;
        if (serial != null) {
          serialsByProduct
              .putIfAbsent(row['product_id'].toString(), () => [])
              .add(serial['serial_number'].toString());
        }
      }
      final products = <Map<String, dynamic>>[];
      for (final raw in rawItems as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final product = Map<String, dynamic>.from(row['products'] as Map);
        final quantity = (row['quantity'] as num?)?.toInt() ?? 1;
        final serials = serialsByProduct[product['id'].toString()] ?? [];
        for (var i = 0; i < quantity; i++) {
          products.add({
            ...product,
            'project_price': row['unit_price'] ?? 0,
            if (i < serials.length) 'selected_serial_number': serials[i],
          });
        }
      }
      final contractUrl = await ProjectCommercialService(
        _supabase,
      ).createContractUrl(widget.booking['contract_path']?.toString());
      if (!mounted) return;
      setState(() {
        _products = products;
        _contractUrl = contractUrl;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _viewQuote() async {
    final bytes = await ProjectQuoteService.buildQuote(
      projectId: widget.booking['id'].toString(),
      clientName: widget.booking['client_name']?.toString() ?? 'Client',
      startDate: _start,
      endDate: _end,
      products: _products,
      totalAmount: (widget.booking['total_price'] as num?)?.toDouble() ?? 0,
      paymentPlanType:
          widget.booking['payment_plan_type']?.toString() ?? 'one_time_end',
      paymentFrequency: widget.booking['payment_frequency']?.toString(),
      paymentInterval:
          int.tryParse('${widget.booking['payment_interval'] ?? 1}') ?? 1,
      installmentAmount: (widget.booking['installment_amount'] as num?)
          ?.toDouble(),
      downPaymentAmount:
          (widget.booking['down_payment_amount'] as num?)?.toDouble() ?? 0,
    );
    if (!mounted) return;
    final fileName = ProjectQuoteService.quoteFileName(
      widget.booking['client_name']?.toString() ?? 'Client',
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (previewContext) {
          final background =
              Theme.of(previewContext).brightness == Brightness.dark
              ? Colors.black
              : Colors.white;
          return Scaffold(
            backgroundColor: background,
            appBar: CustomAppBar(
              text: 'Quote preview',
              showPfp: false,
              actions: [
                IconButton(
                  tooltip: 'Share quote',
                  onPressed: () =>
                      Printing.sharePdf(bytes: bytes, filename: fileName),
                  icon: Icon(Icons.adaptive.share_rounded, color: Colors.white),
                ),
              ],
            ),
            body: PdfPreview(
              build: (_) async => bytes,
              scrollViewDecoration: BoxDecoration(color: background),
              canChangePageFormat: false,
              useActions: false,
              allowPrinting: false,
              allowSharing: false,
            ),
          );
        },
      ),
    );
  }

  String get _contractExtension {
    final path = widget.booking['contract_path']?.toString() ?? '';
    final name = path.split('?').first;
    return name.contains('.') ? name.split('.').last.toLowerCase() : '';
  }

  Future<Uint8List> _downloadContract(String url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Could not load contract');
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
      }
      return Uint8List.fromList(bytes);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _viewContract() async {
    final url = _contractUrl;
    if (url == null) return;
    final extension = _contractExtension;
    const imageTypes = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};

    if (extension == 'pdf') {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CustomLoader()),
      );
      try {
        final bytes = await _downloadContract(url);
        if (!mounted) return;
        Navigator.pop(context);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (previewContext) {
              final background =
                  Theme.of(previewContext).brightness == Brightness.dark
                  ? Colors.black
                  : Colors.white;
              return Scaffold(
                backgroundColor: background,
                appBar: const CustomAppBar(
                  text: 'Signed Contract',
                  showPfp: false,
                ),
                body: PdfPreview(
                  build: (_) async => bytes,
                  scrollViewDecoration: BoxDecoration(color: background),
                  canChangePageFormat: false,
                  useActions: false,
                  allowPrinting: false,
                  allowSharing: false,
                ),
              );
            },
          ),
        );
      } catch (_) {
        if (!mounted) return;
        Navigator.pop(context);
        CustomSnackBar.show(context, 'Could not open this PDF contract.');
      }
      return;
    }

    if (imageTypes.contains(extension)) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: const CustomAppBar(text: 'Signed Contract', showPfp: false),
            body: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Center(
                child: Image.network(
                  url,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const CustomLoader(color: Colors.white),
                  errorBuilder: (_, _, _) => const Text(
                    'Could not display this image',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }

    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      CustomSnackBar.show(context, 'No compatible app found for this file.');
    }
  }

  void _editProject() {
    HapticFeedback.lightImpact();
    Provider.of<BookingProvider>(
      context,
      listen: false,
    ).setEditingBooking(widget.booking);
    Provider.of<NavbarProvider>(context, listen: false).setEditMode(true);
    Provider.of<NavbarProvider>(context, listen: false).setIndex(4);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final booking = widget.booking;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: CustomAppBar(
        text: 'Project Details',
        showPfp: false,
        actions: [
          IconButton(
            tooltip: 'Edit project',
            onPressed: _editProject,
            icon: SvgPicture.asset(
              AppIcons.edit,
              width: 24,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CustomLoader())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                _card(isDark, [
                  _row(
                    'Client',
                    booking['client_name']?.toString() ?? 'N/A',
                    AppIcons.client,
                    isDark,
                  ),
                  _row(
                    'Start date',
                    DateFormat('dd MMMM yyyy').format(_start),
                    AppIcons.returns,
                    isDark,
                  ),
                  _row(
                    'End date',
                    DateFormat('dd MMMM yyyy').format(_end),
                    AppIcons.pickUp,
                    isDark,
                  ),
                  _row(
                    'Duration',
                    _duration(_start, _end),
                    AppIcons.calendar,
                    isDark,
                  ),
                  _row(
                    'Project total',
                    '${_currency.format(booking['total_price'] ?? 0)} EGP',
                    AppIcons.wallet,
                    isDark,
                  ),
                ]),
                const SizedBox(height: 16),
                _sectionTitle('Products', isDark),
                _card(isDark, _productRows(isDark)),
                const SizedBox(height: 16),
                _sectionTitle('Actions', isDark),
                _documentButton(
                  'View quote',
                  AppIcons.booking,
                  _viewQuote,
                  isDark,
                  isFilled: true,
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProjectSiteSetupPage(
                        bookingId: booking['id'].toString(),
                        clientName: booking['client_name']?.toString() ?? '',
                        products: _products,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.location_on_rounded),
                  label: const Text('Select Location'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                if (_contractUrl != null)
                  _documentButton(
                    'View signed contract',
                    AppIcons.verify,
                    _viewContract,
                    isDark,
                    isFilled: false,
                  )
                else
                  Text(
                    'No contract uploaded',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
              ],
            ),
    );
  }

  List<Widget> _productRows(bool isDark) {
    if (_products.isEmpty) {
      return [
        Text(
          'No product details available',
          style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
        ),
      ];
    }
    final grouped = <String, Map<String, dynamic>>{};
    for (final product in _products) {
      final key =
          '${product['id']}::${product['selected_serial_number'] ?? ''}';
      grouped.putIfAbsent(key, () => {...product, 'selected_quantity': 0});
      grouped[key]!['selected_quantity'] =
          (grouped[key]!['selected_quantity'] as int) + 1;
    }
    return grouped.values.map((product) {
      return _row(
        '${product['name']} × ${product['selected_quantity']}${product['selected_serial_number'] == null ? '' : '\nSerial: ${product['selected_serial_number']}'}',
        '',
        AppIcons.inventory,
        isDark,
      );
    }).toList();
  }

  Widget _card(bool isDark, List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isDark ? AppColors.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(children: children),
  );

  Widget _row(String label, String value, String icon, bool isDark) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        SvgPicture.asset(
          icon,
          width: 24,
          colorFilter: const ColorFilter.mode(
            AppColors.primary,
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
        if (value.isNotEmpty) ...[
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _sectionTitle(String title, bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black,
      ),
    ),
  );

  Widget _documentButton(
    String title,
    String icon,
    VoidCallback onTap,
    bool isDark, {
    required bool isFilled,
  }) {
    final iconWidget = SvgPicture.asset(
      icon,
      width: 22,
      colorFilter: ColorFilter.mode(
        isFilled ? Colors.white : AppColors.primary,
        BlendMode.srcIn,
      ),
    );
    if (isFilled) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: iconWidget,
        label: Text(title),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: iconWidget,
      label: Text(title),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  String _duration(DateTime start, DateTime end) {
    var months = (end.year - start.year) * 12 + end.month - start.month;
    DateTime anniversary(int value) {
      final lastDay = DateTime(start.year, start.month + value + 1, 0).day;
      return DateTime(
        start.year,
        start.month + value,
        start.day.clamp(1, lastDay),
      );
    }

    if (anniversary(months).isAfter(end)) months--;
    final days = end.difference(anniversary(months)).inDays;
    return [
      if (months > 0) '$months ${months == 1 ? 'month' : 'months'}',
      if (days > 0 || months == 0) '$days ${days == 1 ? 'day' : 'days'}',
    ].join(', ');
  }
}
