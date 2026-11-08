import 'package:flutter/widgets.dart' show StringCharacters;
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
          ...drafts.expand((draft) {
            final measurements = _measurementsFor(customer, draft.itemType);
            return <pw.Widget>[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey500),
                ),
                child: pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey500),
                  children: [
                    pw.TableRow(
                      repeat: true,
                      children: [
                        pw.TableHelper.fromTextArray(
                          headerCount: 0,
                          border: null,
                          data: [
                            [
                              customer.customerNumber,
                              _customerInitials(customer.name),
                              orderNumber ?? 'Not saved',
                            ],
                          ],
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                '${draft.itemType}  x${draft.quantity}',
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
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                margin: const pw.EdgeInsets.only(bottom: 16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                        'Delivery: ${_dateFormat.format(draft.deliveryDate)}'),
                    if (draft.comments.trim().isNotEmpty)
                      pw.Text('Comments: ${draft.comments.trim()}'),
                  ],
                ),
              ),
            ];
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

  static String _customerInitials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part.characters.first.toUpperCase())
      .join();

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
