import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ProjectQuoteService {
  static final _currency = NumberFormat('#,##0.00', 'en_US');
  static final _date = DateFormat('dd MMMM yyyy');

  static String quoteFileName(String clientName) =>
      '${_fileSafeName(clientName)}_${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf';

  static Future<void> shareQuote({
    required String projectId,
    required String clientName,
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> products,
    required double totalAmount,
    required String paymentPlanType,
    String? paymentFrequency,
    int paymentInterval = 1,
    double? installmentAmount,
    double downPaymentAmount = 0,
  }) async {
    final bytes = await buildQuote(
      projectId: projectId,
      clientName: clientName,
      startDate: startDate,
      endDate: endDate,
      products: products,
      totalAmount: totalAmount,
      paymentPlanType: paymentPlanType,
      paymentFrequency: paymentFrequency,
      paymentInterval: paymentInterval,
      installmentAmount: installmentAmount,
      downPaymentAmount: downPaymentAmount,
    );
    await Printing.sharePdf(bytes: bytes, filename: quoteFileName(clientName));
  }

  static Future<void> shareInvoice({
    required String projectId,
    required String clientName,
    required double totalAmount,
  }) async {
    final bytes = await _buildFinancialDocument(
      title: 'PROJECT INVOICE',
      reference: 'SLI-${projectId.substring(0, 8).toUpperCase()}',
      clientName: clientName,
      amount: totalAmount,
      label: 'Invoice total',
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'site-lapse-invoice-${projectId.substring(0, 8)}.pdf',
    );
  }

  static Future<void> shareReceipt({
    required String receiptNumber,
    required String clientName,
    required double amount,
    required String method,
  }) async {
    final bytes = await _buildFinancialDocument(
      title: 'Quotation',
      reference: receiptNumber,
      clientName: clientName,
      amount: amount,
      label: 'Payment received',
      note: 'Payment method: $method',
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'site-lapse-receipt-$receiptNumber.pdf',
    );
  }

  static Future<Uint8List> _buildFinancialDocument({
    required String title,
    required String reference,
    required String clientName,
    required double amount,
    required String label,
    String? note,
  }) async {
    final document = pw.Document();
    final accent = PdfColor.fromInt(0xFF984848);
    document.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(40),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'SITE LAPSE',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: accent,
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            _detailRow('Reference', reference),
            _detailRow('Client', clientName),
            _detailRow('Date', _date.format(DateTime.now())),
            pw.SizedBox(height: 26),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              color: PdfColor.fromInt(0xFFF8EEEE),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    label,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    '${_currency.format(amount)} EGP',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
            if (note != null) ...[pw.SizedBox(height: 16), pw.Text(note)],
          ],
        ),
      ),
    );
    return document.save();
  }

  static Future<Uint8List> buildQuote({
    required String projectId,
    required String clientName,
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> products,
    required double totalAmount,
    required String paymentPlanType,
    String? paymentFrequency,
    int paymentInterval = 1,
    double? installmentAmount,
    double downPaymentAmount = 0,
  }) async {
    final document = pw.Document();
    final accent = PdfColor.fromInt(0xFF984848);
    final logoBytes = await rootBundle.load(
      'assets/branding/site_lapse_logo_light.png',
    );
    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
    final billableDays = _billableDays(startDate, endDate);
    final paymentRows = _paymentSchedule(
      type: paymentPlanType,
      startDate: startDate,
      endDate: endDate,
      totalAmount: totalAmount,
      monthlyFee: installmentAmount,
      downPayment: downPaymentAmount,
    );
    final productQuantities = <String, Map<String, dynamic>>{};
    for (final product in products) {
      final name = product['name']?.toString() ?? 'Product';
      final price = product['project_price'] ?? product['price'] ?? 0;
      final unitPrice = price is num
          ? price.toDouble()
          : double.tryParse('$price') ?? 0;
      final key = '$name::$unitPrice';
      final existing = productQuantities[key];
      productQuantities[key] = {
        'name': name,
        'quantity': (existing?['quantity'] as int? ?? 0) + 1,
        'unit_price': unitPrice,
        'image_url':
            existing?['image_url'] ?? product['image_url'] ?? product['image'],
      };
    }
    final productRows = await Future.wait(
      productQuantities.entries.map((entry) async {
        final image = await _productImage(entry.value['image_url']?.toString());
        return pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(7),
              child: pw.SizedBox(
                width: 68,
                height: 48,
                child: image == null
                    ? pw.Container(
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFFF0E4E4),
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(5),
                          ),
                        ),
                      )
                    : pw.Image(image, fit: pw.BoxFit.cover),
              ),
            ),
            _tableCell(entry.value['name'].toString()),
            _tableCell(
              '${entry.value['quantity']}',
              align: pw.TextAlign.center,
            ),
            _tableCell(
              (entry.value['unit_price'] as double) > 0
                  ? _currency.format(entry.value['unit_price'])
                  : '',
              align: pw.TextAlign.center,
            ),
            _tableCell(
              (entry.value['unit_price'] as double) > 0
                  ? _currency.format(
                      (entry.value['unit_price'] as double) *
                          (entry.value['quantity'] as int) *
                          billableDays,
                    )
                  : '',
              align: pw.TextAlign.center,
            ),
          ],
        );
      }),
    );
    document.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 105),
        footer: (context) => context.pageNumber == context.pagesCount
            ? pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: pw.BoxDecoration(
                  color: accent,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(26),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total project price',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '${_currency.format(totalAmount)} EGP',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            : pw.SizedBox(),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [pw.Image(logo, width: 180)],
          ),
          pw.SizedBox(height: 28),
          _detailRow('Created on', _date.format(DateTime.now())),
          _detailRow('Client Name', clientName),
          _detailRow(
            'Project period',
            '${_date.format(startDate)} - ${_date.format(endDate)} (${_projectDuration(startDate, endDate)})',
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Included products',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE5E1E1)),
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            columnWidths: const {
              0: pw.IntrinsicColumnWidth(),
              1: pw.FlexColumnWidth(),
              2: pw.IntrinsicColumnWidth(),
              3: pw.IntrinsicColumnWidth(),
              4: pw.IntrinsicColumnWidth(),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: accent),
                children: [
                  _tableCell(
                    'Image',
                    bold: true,
                    align: pw.TextAlign.center,
                    color: PdfColors.white,
                  ),
                  _tableCell(
                    'Product name',
                    bold: true,
                    color: PdfColors.white,
                  ),
                  _tableCell(
                    'Qty',
                    bold: true,
                    align: pw.TextAlign.center,
                    color: PdfColors.white,
                  ),
                  _tableCell(
                    'Price\n(EGP/day)',
                    bold: true,
                    align: pw.TextAlign.center,
                    color: PdfColors.white,
                  ),
                  _tableCell(
                    'Item total\n(EGP)',
                    bold: true,
                    align: pw.TextAlign.center,
                    color: PdfColors.white,
                  ),
                ],
              ),
              ...productRows,
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Payment schedule',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE5E1E1)),
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            columnWidths: const {
              0: pw.IntrinsicColumnWidth(),
              1: pw.FlexColumnWidth(),
              2: pw.IntrinsicColumnWidth(),
              3: pw.FlexColumnWidth(),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: accent),
                children: [
                  _tableCell('Payment', bold: true, color: PdfColors.white),
                  _tableCell('Due date', bold: true, color: PdfColors.white),
                  _tableCell(
                    'Amount (EGP)',
                    bold: true,
                    color: PdfColors.white,
                    align: pw.TextAlign.center,
                  ),
                  _tableCell(
                    'Signature',
                    bold: true,
                    color: PdfColors.white,
                    align: pw.TextAlign.center,
                  ),
                ],
              ),
              ...paymentRows.map(
                (row) => pw.TableRow(
                  children: [
                    _tableCell(row.label),
                    _tableCell(_date.format(row.date)),
                    _tableCell(
                      _currency.format(row.amount),
                      align: pw.TextAlign.center,
                    ),
                    _tableCell(''),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return document.save();
  }

  static pw.Widget _detailRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 7),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 110,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Expanded(child: pw.Text(value)),
      ],
    ),
  );

  static pw.Widget _tableCell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(9),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
      ),
    ),
  );

  static Future<pw.ImageProvider?> _productImage(String? imageUrl) async {
    if (imageUrl == null || !imageUrl.startsWith('http')) return null;
    try {
      return await networkImage(imageUrl);
    } catch (_) {
      return null;
    }
  }

  static int _billableDays(DateTime start, DateTime end) {
    if (end.isBefore(start)) return 0;
    final first = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    return last.difference(first).inDays + 1;
  }

  static String _projectDuration(DateTime start, DateTime end) {
    if (end.isBefore(start)) return '0 days';
    var months = (end.year - start.year) * 12 + end.month - start.month;
    DateTime anniversary(int value) {
      final monthEnd = DateTime(start.year, start.month + value + 1, 0).day;
      return DateTime(
        start.year,
        start.month + value,
        start.day.clamp(1, monthEnd),
      );
    }

    if (anniversary(months).isAfter(end)) months--;
    final days = end.difference(anniversary(months)).inDays;
    final parts = <String>[];
    if (months > 0) {
      parts.add('$months ${months == 1 ? 'month' : 'months'}');
    }
    if (days > 0 || parts.isEmpty) {
      parts.add('$days ${days == 1 ? 'day' : 'days'}');
    }
    return parts.join(', ');
  }

  static String _fileSafeName(String value) => value
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '')
      .toLowerCase();

  static List<_PaymentScheduleRow> _paymentSchedule({
    required String type,
    required DateTime startDate,
    required DateTime endDate,
    required double totalAmount,
    required double? monthlyFee,
    required double downPayment,
  }) {
    if (type == 'one_time_start') {
      return [_PaymentScheduleRow('At start', startDate, totalAmount)];
    }
    if (type == 'one_time_end') {
      return [_PaymentScheduleRow('At end', endDate, totalAmount)];
    }
    final months = _paymentMonths(startDate, endDate);
    final rows = <_PaymentScheduleRow>[];
    if (type == 'down_payment_installments' && downPayment > 0) {
      rows.add(_PaymentScheduleRow('Down payment', startDate, downPayment));
    }
    final amount = type == 'monthly' ? totalAmount / months : (monthlyFee ?? 0);
    for (var index = 0; index < months; index++) {
      final dueDate = DateTime(
        startDate.year,
        startDate.month + index,
        startDate.day,
      );
      rows.add(_PaymentScheduleRow('Month ${index + 1}', dueDate, amount));
    }
    return rows;
  }

  static int _paymentMonths(DateTime start, DateTime end) {
    var months = (end.year - start.year) * 12 + end.month - start.month;
    if (DateTime(start.year, start.month + months, start.day).isBefore(end)) {
      months++;
    }
    return months < 1 ? 1 : months;
  }
}

class _PaymentScheduleRow {
  const _PaymentScheduleRow(this.label, this.date, this.amount);
  final String label;
  final DateTime date;
  final double amount;
}
