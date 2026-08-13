import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ProjectQuoteService {
  static final _currency = NumberFormat('#,##0.00', 'en_US');
  static final _date = DateFormat('dd MMMM yyyy');

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
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          '${_fileSafeName(clientName)}-quote-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
    );
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
              '${_currency.format(entry.value['unit_price'])} EGP/month',
              align: pw.TextAlign.right,
            ),
          ],
        );
      }),
    );
    document.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [pw.Image(logo, width: 180)],
            ),
            pw.SizedBox(height: 28),
            _detailRow('Created on', _date.format(DateTime.now())),
            _detailRow('Client Name', clientName),
            _detailRow(
              'Project period',
              '${_date.format(startDate)} - ${_date.format(endDate)}',
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              'Included products',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE5E1E1)),
              columnWidths: const {
                0: pw.FixedColumnWidth(84),
                1: pw.FlexColumnWidth(2),
                2: pw.FixedColumnWidth(52),
                3: pw.FixedColumnWidth(92),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: accent),
                  children: [
                    _tableCell('Image', bold: true, color: PdfColors.white),
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
                      'Price / month',
                      bold: true,
                      align: pw.TextAlign.right,
                      color: PdfColors.white,
                    ),
                  ],
                ),
                ...productRows,
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8EEEE)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Payment terms',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    _paymentTerms(
                      paymentPlanType,
                      paymentFrequency,
                      paymentInterval,
                      installmentAmount,
                      downPaymentAmount,
                    ),
                  ),
                ],
              ),
            ),
            pw.Spacer(),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              decoration: pw.BoxDecoration(
                color: accent,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
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
                    '${_currency.format(totalAmount)} EGP/month',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  static String _fileSafeName(String value) => value
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '')
      .toLowerCase();

  static String _paymentTerms(
    String type,
    String? frequency,
    int interval,
    double? installment,
    double downPayment,
  ) {
    switch (type) {
      case 'one_time_start':
        return 'One payment of ${_currency.format(installment ?? 0)} EGP at the start of the project.';
      case 'monthly':
        return 'Monthly payment of ${_currency.format(installment ?? 0)} EGP.';
      case 'down_payment_installments':
        return 'Down payment of ${_currency.format(downPayment)} EGP, then ${_currency.format(installment ?? 0)} EGP every $interval ${frequency ?? 'month'}${interval == 1 ? '' : 's'}.';
      default:
        return 'One payment of ${_currency.format(installment ?? 0)} EGP at the end of the project.';
    }
  }
}
