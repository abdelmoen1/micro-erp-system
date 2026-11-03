import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/app.dart';
import 'package:smartshop/core/money/fixed_point.dart';
import 'package:smartshop/core/providers.dart';
import 'package:smartshop/core/storage/key_value_store.dart';
import 'package:smartshop/features/auth/data/auth_repository.dart';
import 'package:smartshop/features/print/application/document_painter.dart';
import 'package:smartshop/features/print/application/escpos.dart';
import 'package:smartshop/features/print/application/printer_service.dart';
import 'package:smartshop/features/print/application/print_documents.dart';
import 'package:smartshop/features/print/domain/print_document.dart';
import 'package:smartshop/features/sale/data/sale_repository.dart';
import 'package:smartshop/l10n/app_localizations.dart';

import '../support/fake_api.dart';

class FakePrinter implements PrinterPort {
  bool permission = true;
  bool on = true;
  bool reachable = true;
  List<BluetoothPrinter> printers = const [BluetoothPrinter(name: 'XP-58', address: 'AA:BB')];
  final List<Uint8List> sent = [];
  final List<String> connected = [];
  int disconnects = 0;
  String? systemJob;

  @override
  Future<bool> requestBluetooth() async => permission;

  @override
  Future<bool> bluetoothOn() async => on;

  @override
  Future<List<BluetoothPrinter>> paired() async => printers;

  @override
  Future<bool> connect(String address) async {
    connected.add(address);
    return reachable;
  }

  @override
  Future<bool> write(Uint8List bytes) async {
    sent.add(bytes);
    return true;
  }

  @override
  Future<void> disconnect() async => disconnects++;

  @override
  Future<void> systemPrint(String jobName, Uint8List pdf) async => systemJob = jobName;
}

Map<String, dynamic> saleJson({int id = 40, String paid = '30.00'}) => {
  'id': id,
  'status': 'active',
  'total_amount': '30.00',
  'paid_amount': paid,
  'debt_amount': '0.00',
  'payment_method': 'cash',
  'created_at': '2026-11-01T09:00:00Z',
  'items': [
    {'id': 9, 'product_id': 3, 'item_name': 'زيت زيتون', 'unit': 'piece', 'quantity': '2', 'returned_quantity': '0', 'unit_price': '15.00', 'line_total': '30.00'},
  ],
  'seller': {'id': 1, 'name': 'أبو محمد'},
  'returns': <Object>[],
  'returned_amount': '0.00',
};

const purchaseJson = {
  'id': 12,
  'supplier': {'id': 7, 'name': 'التاج مول'},
  'total': '240.00',
  'returned_amount': '0.00',
  'lines_count': 1,
  'by': 'أبو محمد',
  'at': '2026-11-01T08:00:00Z',
  'items': [
    {'id': 21, 'product_id': 3, 'item_name': 'كولا علبة', 'unit': 'piece', 'quantity': '96', 'returned_quantity': '0', 'cartons': 4, 'pack_size': 24, 'buy_price': '60.00', 'line_total': '240.00'},
  ],
  'returns': <Object>[],
};

void main() {
  late FakeApi api;
  late FakePrinter printer;

  FakeResponse dashboard({bool costs = true}) => FakeResponse(200, {
    'data': {
      'summary': {'total_sales': '156.00', 'invoices_count': 10},
      'sales': {'total': '156.00', 'cash': '114.00', 'credit': '42.00'},
      'payments': {'today': '20.00'},
      'collections': {'at_sale': '114.00', 'debt_repayments': '20.00', 'total': '134.00', 'refunded': '4.00', 'net': '130.00'},
      'returns': {'count': 1, 'total': '4.00', 'refunded': '4.00'},
      'purchases': costs ? {'total': '240.00', 'count': 1, 'owed_to_suppliers': '318.00'} : null,
      'debts': {'total_remaining': '22.00'},
      'customers': {'with_outstanding_debts': 2},
      'insights': {
        'low_stock': {'count': 3},
      },
      'recent_invoices': [
        {'id': 40, 'customer': null, 'total_amount': '30.00', 'type': 'cash', 'created_at': '2026-11-01T09:00:00Z'},
      ],
    },
  });

  Future<void> pumpApp(WidgetTester tester, {String role = 'owner'}) async {
    api.on('GET /me', meOk(role: role));
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore({AuthRepository.tokenKey: '1|tok'})),
          httpAdapterProvider.overrideWithValue(api),
          printerPortProvider.overrideWithValue(printer),
        ],
        child: const SmartShopApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(AppBar).last), rootNavigator: true).pop();
    await tester.pumpAndSettle();
  }

  setUp(() {
    api = FakeApi();
    printer = FakePrinter();
    api.on('GET /dashboard', dashboard());
    api.on('GET /sales', FakeResponse(200, {
      'data': [saleJson()],
      'meta': {'current_page': 1, 'last_page': 1},
    }));
    api.on('GET /sales/40', FakeResponse(200, {'data': saleJson()}));
  });

  group('Home opens what its figures count', () {
    testWidgets('each figure opens its own list, and collected money adds up', (tester) async {
      api.on('GET /debts/balances', const FakeResponse(200, {
        'data': [
          {'customer': {'id': 3, 'name': 'أبو أحمد', 'phone': '0599000002'}, 'open_count': 2, 'oldest_due': '2026-10-01', 'total_remaining': '22.00'},
        ],
      }));
      api.on('GET /payments', const FakeResponse(200, {
        'data': [
          {'total_amount': '20.00', 'method': 'cash', 'paid_at': '2026-11-01T07:00:00Z', 'is_reversed': false, 'customer': {'id': 3, 'name': 'أبو أحمد'}},
        ],
      }));
      api.on('GET /purchases', const FakeResponse(200, {'data': [purchaseJson], 'meta': {'current_page': 1, 'last_page': 1}}));
      api.on('GET /returns/sales', const FakeResponse(200, {'data': <Object>[], 'meta': {'current_page': 1, 'last_page': 1}}));
      await pumpApp(tester);

      await tap(tester, find.byKey(const Key('home.cash')));
      expect(api.requestsTo('GET /sales').last.queryParameters['type'], 'cash');
      expect(api.requestsTo('GET /sales').last.queryParameters['status'], 'active');
      await back(tester);

      await tap(tester, find.byKey(const Key('home.credit')));
      expect(api.requestsTo('GET /sales').last.queryParameters['type'], 'on_credit');
      await back(tester);

      await tap(tester, find.byKey(const Key('home.today.open')));
      expect(api.requestsTo('GET /sales').last.queryParameters.containsKey('type'), isFalse);
      await back(tester);

      await tap(tester, find.byKey(const Key('home.outstanding')));
      expect(find.byKey(const Key('debtors.row.3')), findsOneWidget);
      await back(tester);

      await tap(tester, find.byKey(const Key('home.collected')));
      expect(find.text('₪ 130.00'), findsOneWidget);
      expect(find.text('أبو أحمد'), findsOneWidget);
      await back(tester);

      await tap(tester, find.byKey(const Key('home.purchases')));
      expect(find.byKey(const Key('purchases.row.12')), findsOneWidget);
      await back(tester);

      await tap(tester, find.byKey(const Key('home.returns')));
      expect(api.requestsTo('GET /returns/sales'), isNotEmpty);
      await back(tester);

      await tap(tester, find.byKey(const Key('home.invoice.40')));
      expect(find.byKey(const Key('saleDetail.paper')), findsOneWidget);
    });

    testWidgets('«تحصيل اليوم» shows everything collected, not only debt repayments', (tester) async {
      await pumpApp(tester);
      expect(find.descendant(of: find.byKey(const Key('home.collected')), matching: find.text('134.00 ₪')), findsOneWidget);
    });

    testWidgets('selling lives on the centre button: the shortcuts are suppliers and the registers', (tester) async {
      await pumpApp(tester);
      expect(find.byKey(const Key('home.shortcut.pos')), findsNothing);
      for (final name in ['suppliers', 'customers', 'products', 'sales', 'purchases', 'returns']) {
        expect(find.byKey(Key('home.shortcut.$name')), findsOneWidget);
      }
      expect(find.text('المخزن'), findsWidgets);
    });

    testWidgets('an employee sees neither costs nor suppliers', (tester) async {
      api.on('GET /dashboard', dashboard(costs: false));
      await pumpApp(tester, role: 'employee');
      await tap(tester, find.byKey(const Key('nav.home')));
      expect(find.byKey(const Key('home.purchases')), findsNothing);
      expect(find.byKey(const Key('home.shortcut.suppliers')), findsNothing);
      expect(find.byKey(const Key('home.shortcut.purchases')), findsNothing);
      expect(find.byKey(const Key('home.shortcut.sales')), findsOneWidget);
    });
  });

  group('returns', () {
    testWidgets('a customer return: damaged is sent, the reason is required, the note prints', (tester) async {
      api.on('POST /sales/40/returns', const FakeResponse(201, {
        'data': {
          'id': 5,
          'invoice_id': 40,
          'total_amount': '15.00',
          'debt_reduction': '0.00',
          'refund_amount': '15.00',
          'reason': 'بضاعة تالفة',
          'created_at': '2026-11-01T10:00:00Z',
          'items': [
            {'item_name': 'زيت زيتون', 'unit': 'piece', 'quantity': '1', 'total': '15.00', 'damaged': true},
          ],
        },
      }));
      await pumpApp(tester);
      await tap(tester, find.byKey(const Key('home.invoice.40')));
      await tap(tester, find.byKey(const Key('saleDetail.return')));

      await tester.enterText(find.byKey(const Key('return.quantity.9')), '3');
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const Key('return.save')));
      expect(api.requestsTo('POST /sales/40/returns'), isEmpty);
      expect(find.text('الحد الأقصى 2'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('return.quantity.9')), '1');
      await tap(tester, find.byKey(const Key('return.flag.9')));
      await tap(tester, find.byKey(const Key('return.save')));
      expect(find.text('اكتب سبب الإرجاع.'), findsOneWidget);
      expect(api.requestsTo('POST /sales/40/returns'), isEmpty);

      await tap(tester, find.text('بضاعة تالفة'));
      expect(find.text('₪ 15.00'), findsWidgets);
      await tap(tester, find.byKey(const Key('return.save')));

      final sent = api.requestsTo('POST /sales/40/returns').single;
      expect((sent.data as Map)['items'], [
        {'invoice_item_id': 9, 'quantity': '1.000', 'damaged': true},
      ]);
      expect(sent.headers['Idempotency-Key'], isNotNull);
      expect(find.byKey(const Key('return.done')), findsOneWidget);
      expect(find.text('طباعة'), findsOneWidget);
    });

    testWidgets('an employee can print an invoice but not take goods back', (tester) async {
      await pumpApp(tester, role: 'employee');
      await tap(tester, find.byKey(const Key('nav.home')));
      await tap(tester, find.byKey(const Key('home.invoice.40')));
      expect(find.byKey(const Key('saleDetail.print')), findsOneWidget);
      expect(find.byKey(const Key('saleDetail.return')), findsNothing);
    });

    testWidgets('goods back to a supplier: pieces of the invoice, on the supplier balance', (tester) async {
      api.on('GET /purchases', const FakeResponse(200, {'data': [purchaseJson], 'meta': {'current_page': 1, 'last_page': 1}}));
      api.on('GET /purchases/12', const FakeResponse(200, {'data': purchaseJson}));
      api.on('GET /suppliers/7', const FakeResponse(200, {
        'data': {'id': 7, 'name': 'التاج مول', 'balance': '10.00', 'products': <Object>[], 'payments': <Object>[]},
      }));
      api.on('POST /purchases/12/returns', const FakeResponse(201, {
        'data': {
          'id': 3,
          'purchase_invoice_id': 12,
          'supplier': {'id': 7, 'name': 'التاج مول'},
          'total_amount': '60.00',
          'balance_reduction': '10.00',
          'refund_amount': '50.00',
          'reason': 'خلاف على البضاعة',
          'created_at': '2026-11-01T10:00:00Z',
          'items': [
            {'item_name': 'كولا علبة', 'unit': 'piece', 'quantity': '24', 'total': '60.00', 'from_stock': true},
          ],
        },
        'balance': '0.00',
      }));
      await pumpApp(tester);
      await tap(tester, find.byKey(const Key('home.shortcut.purchases')));
      await tap(tester, find.byKey(const Key('purchases.row.12')));
      await tap(tester, find.byKey(const Key('purchase.return')));

      await tester.enterText(find.byKey(const Key('return.quantity.21')), '24');
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -600));
      await tester.pumpAndSettle();
      // 60.00 goes back: 10.00 off what is owed, the other 50.00 the supplier pays back.
      expect(find.text('₪ 50.00'), findsOneWidget);
      await tap(tester, find.text('خلاف على البضاعة'));
      await tap(tester, find.byKey(const Key('return.save')));

      expect((api.requestsTo('POST /purchases/12/returns').single.data as Map)['items'], [
        {'purchase_item_id': 21, 'quantity': '24.000', 'from_stock': true},
      ]);
      expect(find.byKey(const Key('return.done')), findsOneWidget);
    });
  });

  group('printing', () {
    testWidgets('a paired printer gets the invoice as an image, and stays chosen', (tester) async {
      await pumpApp(tester);
      await tap(tester, find.byKey(const Key('home.invoice.40')));
      await tap(tester, find.byKey(const Key('saleDetail.print')));
      expect(find.text('XP-58'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('print.send')));
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      expect(printer.connected, ['AA:BB']);
      expect(printer.disconnects, 1);
      expect(printer.sent.first, EscPos.init);
      expect(printer.sent.last, EscPos.finish);
      expect(printer.sent[1].sublist(0, 4), [0x1D, 0x76, 0x30, 0x00]);
      expect(find.byKey(const Key('print.done')), findsOneWidget);
    });

    testWidgets('an unreachable printer says so and sends nothing', (tester) async {
      printer.reachable = false;
      await pumpApp(tester);
      await tap(tester, find.byKey(const Key('home.invoice.40')));
      await tap(tester, find.byKey(const Key('saleDetail.print')));
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('print.send')));
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('print.failed')), findsOneWidget);
      expect(printer.sent, isEmpty);
    });

    testWidgets('no permission, Bluetooth off and no printer each explain themselves', (tester) async {
      printer
        ..permission = false
        ..printers = const [];
      await pumpApp(tester);
      await tap(tester, find.byKey(const Key('home.invoice.40')));
      await tap(tester, find.byKey(const Key('saleDetail.print')));
      expect(find.text('اسمح للتطبيق باستخدام البلوتوث عشان يوصل للطابعة.'), findsOneWidget);

      printer.permission = true;
      await tap(tester, find.byKey(const Key('print.retry')));
      expect(find.textContaining('ما في طابعة مقترنة'), findsOneWidget);
      expect(find.byKey(const Key('print.other')), findsOneWidget);
    });

    test('raster is one bit a dot, black set, in rows of whole bytes', () {
      // 10 × 2: the first row black, the second white.
      final rgba = Uint8List(10 * 2 * 4);
      for (var i = 0; i < rgba.length; i++) {
        rgba[i] = i < 40 ? (i % 4 == 3 ? 255 : 0) : 255;
      }
      final band = EscPos.raster(rgba, 10, 2).single;
      expect(band.sublist(0, 8), [0x1D, 0x76, 0x30, 0x00, 2, 0, 2, 0]);
      expect(band.sublist(8), [0xFF, 0xC0, 0x00, 0x00]);
    });

    test('a long image goes out in bands', () {
      final bands = EscPos.raster(Uint8List(8 * (EscPos.bandHeight + 3) * 4), 8, EscPos.bandHeight + 3);
      expect(bands, hasLength(2));
      expect(bands[1][6], 3);
    });

    testWidgets('Arabic lays out across the paper, and A4 is cut into pages', (tester) async {
      await tester.runAsync(() async {
        final loader = FontLoader('IBMPlexSansArabic')
          ..addFont(rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf').then((d) => d))
          ..addFont(rootBundle.load('assets/fonts/IBMPlexSansArabic-Bold.ttf').then((d) => d));
        await loader.load();

        final document = PrintDocument(
          title: 'فاتورة مبيعات',
          number: '#40',
          storeName: 'الشريف ماركت',
          storePhone: '0599123456',
          storeAddress: 'غزة، شارع الوحدة',
          facts: const [('التاريخ', '01/11/2026  09:00'), ('البائع', 'رائد الشريف'), ('الزبون', 'أبو أحمد الطويل')],
          rows: [
            for (var i = 0; i < 40; i++)
              PrintRow(name: 'زيت زيتون بكر ممتاز 750 مل $i', detail: '2 قطعة × ₪ 15.00', amount: '₪ 30.00'),
          ],
          totals: const [PrintTotal('الإجمالي', '₪ 1,200.00', strong: true), PrintTotal('المدفوع · نقدي', '₪ 1,000.00'), PrintTotal('المتبقي دين', '₪ 200.00')],
          stamp: 'ملغاة',
          footer: 'شكراً لتعاملكم معنا',
        );

        final roll = await paintDocument(document, width: 384);
        expect(roll, hasLength(1));
        expect(roll.single.width, 384);

        final a4 = await paintDocument(document, width: 1000, scale: 1.3, pageHeight: 1400);
        expect(a4.length, greaterThan(1));
        for (final page in a4) {
          expect(page.height, lessThanOrEqualTo(1400));
        }

        // Written for a person to look at: PRINT_PREVIEW_DIR=<folder> flutter test ...
        final preview = Platform.environment['PRINT_PREVIEW_DIR'];
        if (preview != null) {
          final png = await roll.single.toByteData(format: ui.ImageByteFormat.png);
          File('$preview/receipt-58mm.png').writeAsBytesSync(png!.buffer.asUint8List());
        }
      });
    });

    testWidgets('the sales invoice is a table with its discount, on both rolls', (tester) async {
      await tester.runAsync(() async {
        final loader = FontLoader('IBMPlexSansArabic')
          ..addFont(rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf').then((d) => d))
          ..addFont(rootBundle.load('assets/fonts/IBMPlexSansArabic-Bold.ttf').then((d) => d));
        await loader.load();

        final t = await AppLocalizations.delegate.load(const Locale('ar'));
        final sale = SaleReceipt.fromJson({
          'data': {
            'id': 101,
            'status': 'active',
            'total_amount': '100.00',
            'discount_amount': '1.00',
            'paid_amount': '100.00',
            'debt_amount': '0.00',
            'payment_method': 'cash',
            'items': [
              {'item_name': 'أرز بسمتي 5 كغ', 'unit': 'piece', 'quantity': '2', 'unit_price': '35.00', 'line_total': '70.00'},
              {'item_name': 'جبنة بيضاء', 'unit': 'kg', 'quantity': '0.500', 'unit_price': '36.00', 'line_total': '18.00'},
              {'item_name': 'ماء 600 مل', 'unit': 'piece', 'pack_size': 12, 'quantity': '1', 'unit_price': '13.00', 'line_total': '13.00'},
            ],
            'customer': {'id': 4, 'name': 'أبو أحمد', 'phone': '0599123456'},
            'seller': {'id': 1, 'name': 'رائد'},
            'created_at': '2026-11-03T09:30:00Z',
          },
        });
        expect(sale.subtotal, Money.parse('101.00'));
        expect(sale.charged(Money.parse('70.00')), Money.parse('69.31'), reason: '70 less 70/101 of the 1.00 discount');

        final document = saleDocument(t, sale, null);
        expect(document.columns, ('الصنف', 'الكمية', 'السعر', 'المبلغ'));
        expect(document.rows.first.quantity, '2');
        expect(document.rows[1].quantity, '0.500 كغ');
        expect(document.rows.last.quantity, '1 كرتونة');
        expect(document.rows.first.price, '35.00');
        expect(document.rows.last.detail, '= 12 قطعة');
        expect([for (final total in document.totals) total.label], ['المجموع', 'الخصم', 'الإجمالي', 'المدفوع · نقداً']);
        expect(document.totals[1].value, '₪ 1.00');
        expect(document.totals.singleWhere((total) => total.strong).value, '₪ 100.00');

        for (final (name, width, scale) in [('58mm', 384, 1.0), ('80mm', 576, 1.4)]) {
          final roll = await paintDocument(document, width: width, scale: scale);
          expect(roll.single.width, width);
          final preview = Platform.environment['PRINT_PREVIEW_DIR'];
          if (preview != null) {
            final png = await roll.single.toByteData(format: ui.ImageByteFormat.png);
            File('$preview/invoice-$name.png').writeAsBytesSync(png!.buffer.asUint8List());
          }
        }
      });
    });
  });
}
