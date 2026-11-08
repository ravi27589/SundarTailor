import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';
import 'package:sundar_tailor/data/models/customer.dart';
import 'package:sundar_tailor/data/models/tailor_order.dart';
import 'package:sundar_tailor/features/orders/order_print_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('prints values and initials before item measurements without labels',
      () async {
    final original = PrintingPlatform.instance;
    final printer = _CapturingPrinter();
    PrintingPlatform.instance = printer;
    addTearDown(() => PrintingPlatform.instance = original);
    final customer = Customer(
      id: 'customer',
      customerNumber: 'C001',
      name: '  Ravi   Kumar ',
      phone: '123',
      shirtMeasurements: const {'Chest': '40'},
      trouserMeasurements: const {'Waist': '34'},
      pajamaMeasurements: const {},
      suitMeasurements: const {},
      shortsMeasurements: const {},
      kurtaMeasurements: const {},
      safariMeasurements: const {},
      notes: '',
      createdDate: DateTime.utc(2026),
      updatedDate: DateTime.utc(2026),
    );

    await OrderPrintService.printDrafts(
      customer: customer,
      orderedDate: DateTime.utc(2026),
      orderNumber: 'ORD001',
      drafts: [
        OrderDraft(
          itemType: 'Shirt',
          comments: 'Blue',
          quantity: 1,
          deliveryDate: DateTime.utc(2026, 11, 12),
        ),
        OrderDraft(
          itemType: 'Trouser',
          comments: '',
          quantity: 2,
          deliveryDate: DateTime.utc(2026, 11, 13),
        ),
      ],
    );

    final pdf = latin1.decode(printer.bytes!);
    expect(pdf, startsWith('%PDF-'));
    final streams = RegExp(r'stream\r?\n(.*?)\r?\nendstream', dotAll: true)
        .allMatches(pdf)
        .map((match) {
      final bytes = latin1.encode(match.group(1)!);
      final dictionary = pdf.substring(
        pdf.lastIndexOf('<<', match.start),
        match.start,
      );
      return latin1.decode(
        dictionary.contains('/FlateDecode')
            ? ZLibDecoder().convert(bytes)
            : bytes,
      );
    }).join('\n');
    expect(streams, contains('(C001)'));
    expect(streams, contains('(RK)'));
    expect(streams, contains('(ORD001)'));
    expect(streams, contains('(Chest:)'));
    expect(streams, contains('(40)'));
    expect(streams, contains('(Waist:)'));
    expect(streams, contains('(34)'));
    expect(streams.indexOf('(ORD001)'), lessThan(streams.indexOf('(Chest:)')));
    expect(streams, isNot(contains('(Customer ID)')));
    expect(streams, isNot(contains('(Customer)')));
    expect(streams, isNot(contains('(Order No.)')));
    expect(streams, isNot(contains('Ravi')));
    expect(streams, isNot(contains('Kumar')));
  });
}

class _CapturingPrinter extends PrintingPlatform {
  Uint8List? bytes;

  Future<bool> _capture(LayoutCallback onLayout) async {
    bytes = await onLayout(PdfPageFormat.a4);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #layoutPdf) {
      return _capture(invocation.positionalArguments[1] as LayoutCallback);
    }
    return super.noSuchMethod(invocation);
  }
}
