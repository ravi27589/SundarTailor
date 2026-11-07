import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/customer.dart';
import '../../data/models/tailor_order.dart';

class OrderPrintService {
  static final _dateFormat = DateFormat('dd MMM yyyy');
  static const _a7Landscape = PdfPageFormat(
    105 * PdfPageFormat.mm,
    74 * PdfPageFormat.mm,
    marginAll: 5 * PdfPageFormat.mm,
  );

  static Future<void> printDrafts({
    required Customer customer,
    required List<OrderDraft> drafts,
    required DateTime orderedDate,
    String? orderNumber,
  }) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: _a7Landscape,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Sundar Tailor - Order Sheet'),
          ),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey500),
            ),
            child: pw.TableHelper.fromTextArray(
              headers: const [
                'Customer',
                'Customer ID',
                'Phone',
                'Ordered',
                'Order No.',
              ],
              data: [
                [
                  customer.name,
                  customer.customerNumber,
                  customer.phone,
                  _dateFormat.format(orderedDate),
                  orderNumber ?? 'Not saved',
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          ...drafts.map((draft) {
            final measurements = _measurementsFor(customer, draft.itemType);
            return pw.Container(
              width: double.infinity,
              margin: const pw.EdgeInsets.only(bottom: 16),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${draft.itemType}  x${draft.quantity}',
                    style: const pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                      'Delivery: ${_dateFormat.format(draft.deliveryDate)}'),
                  if (draft.comments.trim().isNotEmpty)
                    pw.Text('Comments: ${draft.comments.trim()}'),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey500),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Measurements',
                          style: const pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          measurements.isEmpty
                              ? 'No measurements recorded'
                              : measurements,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          if (customer.notes.trim().isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text('Customer notes: ${customer.notes.trim()}'),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => document.save());
  }

  static String _measurementsFor(Customer customer, String itemType) {
    final normalized = itemType.toLowerCase();
    final measurements = switch (normalized) {
      'shirt' || 'shirts' => customer.shirtMeasurements,
      'trouser' || 'trousers' => customer.trouserMeasurements,
      'short' || 'shorts' => customer.shortsMeasurements,
      'kurta' => customer.kurtaMeasurements,
      'pajama' || 'pajamas' => customer.pajamaMeasurements,
      'suit' => customer.suitMeasurements,
      'safari' => customer.safariMeasurements,
      _ => const <String, String>{},
    };

    final freeform = measurements['measurements'];
    if (freeform != null) {
      return freeform;
    }
    return measurements.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('\n');
  }
}
