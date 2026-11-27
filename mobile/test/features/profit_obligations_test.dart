import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/app.dart';
import 'package:smartshop/core/money/fixed_point.dart';
import 'package:smartshop/core/providers.dart';
import 'package:smartshop/core/storage/key_value_store.dart';
import 'package:smartshop/features/auth/data/auth_repository.dart';
import 'package:smartshop/features/customers/domain/customer.dart';
import 'package:smartshop/features/customers/presentation/record_payment_screen.dart';
import 'package:smartshop/l10n/app_localizations.dart';

import '../support/fake_api.dart';

/// 2026-11-28: net profit on Home, «الالتزامات» in More, the account a transfer repayment
/// arrived on, and swiping between the tabs.
void main() {
  late FakeApi api;

  FakeResponse dashboard({Map<String, dynamic>? profit}) => FakeResponse(200, {
    'data': {
      'summary': {'total_sales': '156.00', 'invoices_count': 3},
      'sales': {'total': '156.00', 'cash': '114.00', 'credit': '42.00'},
      'payments': {'today': '20.00'},
      'collections': {
        'at_sale': '114.00',
        'debt_repayments': '20.00',
        'total': '134.00',
        'refunded': '0.00',
        'net': '134.00',
      },
      'debts': {'total_remaining': '22.00'},
      'customers': {'with_outstanding_debts': 2},
      'profit': profit,
      'recent_invoices': <Object>[],
    },
  });

  const profit = {
    'sales_profit': '58.00',
    'discounts': '2.00',
    'returns_profit': '6.00',
    'obligations': '40.00',
    'net': '10.00',
    'uncosted_lines': 2,
  };

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

  setUp(() => api = FakeApi());

  group('net profit on Home', () {
    testWidgets('replaces the collections tile and opens how it is made', (tester) async {
      api.on('GET /dashboard', dashboard(profit: profit));
      await pumpApp(tester);

      expect(find.byKey(const Key('home.collected')), findsNothing);
      expect(
        find.descendant(of: find.byKey(const Key('home.netProfit')), matching: find.text('10.00 ₪')),
        findsOneWidget,
      );
      expect(find.text('صافي ربح اليوم'), findsOneWidget);

      await tap(tester, find.byKey(const Key('home.netProfit')));
      expect(find.text('+ ₪ 58.00'), findsOneWidget);
      expect(find.text('− ₪ 2.00'), findsOneWidget);
      expect(find.text('− ₪ 6.00'), findsOneWidget);
      expect(find.text('− ₪ 40.00'), findsOneWidget);
      expect(find.byKey(const Key('profit.uncosted')), findsOneWidget);
      expect(find.textContaining('صنفان بيعا اليوم'), findsOneWidget);
      // The collections it replaced stay one tap away.
      await tester.scrollUntilVisible(find.byKey(const Key('profit.collections')), 200);
      expect(find.byKey(const Key('profit.collections')), findsOneWidget);
    });

    testWidgets('a loss reads as a loss', (tester) async {
      api.on('GET /dashboard', dashboard(profit: {...profit, 'net': '-25.50', 'uncosted_lines': 0}));
      await pumpApp(tester);

      expect(find.text('-25.50 ₪'), findsOneWidget);
      expect(find.text('خسارة بعد التكلفة والالتزامات'), findsOneWidget);
    });

    testWidgets('staff phones (no profit figure) keep the collections tile', (tester) async {
      api.on('GET /dashboard', dashboard());
      await pumpApp(tester, role: 'manager');

      expect(find.byKey(const Key('home.collected')), findsOneWidget);
      expect(find.byKey(const Key('home.netProfit')), findsNothing);
    });
  });

  testWidgets('obligations: add the first one from More, then see its daily share', (tester) async {
    api.on('GET /dashboard', dashboard(profit: profit));
    api.onSequence('GET /obligations', [
      const FakeResponse(200, {'data': <Object>[]}),
      const FakeResponse(200, {
        'data': [
          {'id': 1, 'name': 'إيجار المحل', 'amount': '700.00', 'frequency': 'weekly', 'active': true},
        ],
      }),
    ]);
    api.on(
      'POST /obligations',
      const FakeResponse(201, {
        'data': {'id': 1},
      }),
    );
    await pumpApp(tester);

    await tap(tester, find.byKey(const Key('nav.more')));
    await tap(tester, find.byKey(const Key('more.obligations')));
    expect(find.text('لا التزامات بعد'), findsOneWidget);

    await tap(tester, find.text('إضافة التزام'));
    await tap(tester, find.byKey(const Key('ob.save')));
    expect(find.text('اكتب اسم الالتزام.'), findsOneWidget);
    expect(api.requestsTo('POST /obligations'), isEmpty);

    await tester.enterText(find.byKey(const Key('ob.name')), 'إيجار المحل');
    await tester.enterText(find.byKey(const Key('ob.amount')), '700');
    await tap(tester, find.byKey(const Key('ob.freq.weekly')));
    await tap(tester, find.byKey(const Key('ob.save')));

    expect(api.requestsTo('POST /obligations').single.data, {
      'name': 'إيجار المحل',
      'amount': '700.00',
      'frequency': 'weekly',
      'active': true,
    });
    expect(find.byKey(const Key('ob.row.1')), findsOneWidget);
    expect(find.text('حصة اليوم ₪ 100.00'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const Key('ob.dailyTotal')), matching: find.text('₪ 100.00')),
      findsOneWidget,
    );
  });

  group('debt repayment', () {
    const customer = Customer(
      id: 4,
      name: 'أبو محمد',
      phone: '0599123456',
      balance: Money.cents(10000),
      creditLimit: Money.cents(50000),
    );

    Future<void> pumpPayment(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore({AuthRepository.tokenKey: '1|tok'})),
            httpAdapterProvider.overrideWithValue(api),
          ],
          child: const MaterialApp(
            locale: Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RecordPaymentScreen(customer: customer, remaining: Money.cents(10000)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a transfer names the account it arrived on, then the done mark plays', (tester) async {
      api.on(
        'GET /receiving-accounts',
        const FakeResponse(200, {
          'data': [
            {
              'id': 9,
              'provider': 'palpay',
              'account_name': 'حساب المحل',
              'account_identifier': '0599000000',
              'active': true,
            },
          ],
        }),
      );
      api.on(
        'POST /customers/4/debts/pay-all',
        const FakeResponse(201, {
          'data': {'payment_group_id': 'g', 'debts_count': 1, 'total_paid': '100.00', 'remaining_after': '0.00'},
        }),
      );
      await pumpPayment(tester);

      // PalPay is the default method: the account row is there.
      await tap(tester, find.byKey(const Key('payment.account')));
      expect(api.requestsTo('GET /receiving-accounts').single.queryParameters['provider'], 'palpay');
      await tap(tester, find.text('حساب المحل'));
      expect(find.text('تغيير'), findsOneWidget);

      await tap(tester, find.byKey(const Key('payment.confirm')));
      expect(api.requestsTo('POST /customers/4/debts/pay-all').single.data, {
        'method': 'palpay',
        'receiving_account_id': 9,
      });
      expect(find.text('استُلمت ₪ 100.00'), findsOneWidget);
      expect(find.byKey(const Key('payment.doneAccount')), findsOneWidget);
    });

    testWidgets('cash hides the account and never sends one', (tester) async {
      api.on(
        'POST /customers/4/debts/pay-all',
        const FakeResponse(201, {
          'data': {'payment_group_id': 'g', 'debts_count': 1, 'total_paid': '100.00', 'remaining_after': '0.00'},
        }),
      );
      await pumpPayment(tester);

      await tap(tester, find.text('نقداً'));
      expect(find.byKey(const Key('payment.account')), findsNothing);
      await tap(tester, find.byKey(const Key('payment.confirm')));
      expect(api.requestsTo('POST /customers/4/debts/pay-all').single.data, {'method': 'cash'});
    });
  });

  testWidgets('a swipe moves along the bar: right to the customers, left back home', (tester) async {
    api.on('GET /dashboard', dashboard(profit: profit));
    api.on('GET /customers', const FakeResponse(200, {'data': <Object>[]}));
    await pumpApp(tester);
    expect(find.byKey(const Key('home.today')), findsOneWidget);

    // In Arabic the bar reads right to left: a swipe to the right shows the next tab.
    await tester.fling(find.byKey(const Key('home.today')), const Offset(400, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customers.query')), findsOneWidget);

    // From the list area: a text field keeps its own sideways drag (moving the cursor).
    await tester.flingFrom(const Offset(180, 520), const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home.today')), findsOneWidget);
    expect(find.byKey(const Key('customers.query')), findsNothing);
  });
}
