import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/app.dart';
import 'package:smartshop/core/providers.dart';
import 'package:smartshop/core/storage/key_value_store.dart';
import 'package:smartshop/features/auth/data/auth_repository.dart';
import 'package:smartshop/features/auth/presentation/subscription_expired_screen.dart' show externalLinkLauncherProvider;

import '../support/fake_api.dart';
import 'products_test.dart' show productJson;

/// «More»: the web back office on the phone — staff, store details, stock, sales history and the
/// account — with the role rules of the server.
void main() {
  late FakeApi api;
  late List<Uri> opened;

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
          externalLinkLauncherProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
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

  Future<void> openMore(WidgetTester tester) => tap(tester, find.byKey(const Key('nav.more')));

  setUp(() {
    api = FakeApi();
    opened = [];
    api.on('GET /dashboard', dashboardOk());
    api.on('GET /subscription', subscriptionOk(state: 'trial', hasAccess: true));
  });

  testWidgets('the owner sees every section; an employee sees no staff, store details or negative stock', (tester) async {
    await pumpApp(tester);
    await openMore(tester);
    for (final key in ['more.staff', 'more.store', 'more.lowStock', 'more.negative', 'more.sales', 'more.password', 'more.subscription', 'more.support']) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
    expect(find.textContaining('تجربة مجانية حتى 20/10/2026'), findsOneWidget);

    // The support number opens WhatsApp with the store named.
    await tap(tester, find.byKey(const Key('more.subscription')));
    expect(opened.single.toString(), startsWith('https://wa.me/970599000000?text='));
    expect(Uri.decodeComponent(opened.single.query), contains('Demo Shop'));
  });

  testWidgets('an employee: sales, low stock and the account, nothing of the owner', (tester) async {
    await pumpApp(tester, role: 'employee');
    await openMore(tester);
    expect(find.byKey(const Key('more.staff')), findsNothing);
    expect(find.byKey(const Key('more.store')), findsNothing);
    expect(find.byKey(const Key('more.negative')), findsNothing);
    expect(find.byKey(const Key('more.sales')), findsOneWidget);
    expect(find.byKey(const Key('more.lowStock')), findsOneWidget);
    expect(find.byKey(const Key('more.password')), findsOneWidget);
  });

  testWidgets('staff: invite by link (WhatsApp or copy), change a role, deactivate after a confirmation', (tester) async {
    api.on('GET /users', const FakeResponse(200, {
      'data': [
        {'id': 5, 'name': 'سامي', 'email': 'sami@shop.ps', 'role': 'employee', 'status': 'active'},
        {'id': 6, 'name': 'رامي', 'email': 'rami@shop.ps', 'role': 'manager', 'status': 'inactive'},
      ],
    }));
    await pumpApp(tester);
    await openMore(tester);
    await tap(tester, find.byKey(const Key('more.staff')));

    expect(find.text('سامي'), findsOneWidget);
    expect(find.text('موقوف'), findsOneWidget);

    // Invite a manager for 3 days.
    api.on('POST /invitations', const FakeResponse(201, {
      'message': 'تم إنشاء الدعوة بنجاح',
      'invitation': {'id': 1, 'email': null, 'role': 'manager', 'expires_at': '2026-10-28T10:00:00.000000Z', 'token': 'abc+123'},
    }));
    await tap(tester, find.byKey(const Key('staff.invite')));
    await tap(tester, find.byKey(const Key('invite.role.manager')));
    await tap(tester, find.byKey(const Key('invite.hours.72')));
    await tap(tester, find.byKey(const Key('invite.create')));
    expect(api.requestsTo('POST /invitations').single.data, {'role': 'manager', 'expires_in_hours': 72});
    expect(find.text('https://hisbah-web.vercel.app/invite?invite=abc%2B123'), findsOneWidget);

    await tap(tester, find.byKey(const Key('invite.whatsapp')));
    expect(opened.single.host, 'wa.me');
    expect(Uri.decodeComponent(opened.single.query), contains('https://hisbah-web.vercel.app/invite?invite=abc%2B123'));

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tap(tester, find.byKey(const Key('invite.copy')));
    expect(copied, 'https://hisbah-web.vercel.app/invite?invite=abc%2B123');
    expect(find.text('نُسخ الرابط.'), findsOneWidget);
    await tap(tester, find.byKey(const Key('invite.done')));

    // Make Sami a manager.
    api.on('PATCH /users/5/role', const FakeResponse(200, {'message': 'ok'}));
    await tap(tester, find.byKey(const Key('staff.row.5')));
    await tap(tester, find.byKey(const Key('staff.makeRole')));
    expect(api.requestsTo('PATCH /users/5/role').single.data, {'role': 'manager'});

    // Deactivate: asked first; cancelling sends nothing.
    api.on('POST /users/5/deactivate', const FakeResponse(200, {'message': 'ok'}));
    await tap(tester, find.byKey(const Key('staff.row.5')));
    await tap(tester, find.byKey(const Key('staff.deactivate')));
    expect(find.text('إيقاف سامي؟'), findsOneWidget);
    await tap(tester, find.byKey(const Key('confirm.cancel')));
    expect(api.requestsTo('POST /users/5/deactivate'), isEmpty);
    await tap(tester, find.byKey(const Key('staff.row.5')));
    await tap(tester, find.byKey(const Key('staff.deactivate')));
    await tap(tester, find.byKey(const Key('confirm.ok')));
    expect(api.requestsTo('POST /users/5/deactivate'), hasLength(1));

    // An inactive member has no actions.
    await tester.tap(find.byKey(const Key('staff.row.6')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('staff.makeRole')), findsNothing);
  });

  testWidgets('store details: Arabic-keyboard digits, server messages under the field, the session reloads', (tester) async {
    api.on('GET /my-store', const FakeResponse(200, {
      'user': 'Demo owner',
      'store': {'id': 1, 'name': 'Demo Shop', 'phone': null, 'address': 'غزة', 'area': null},
    }));
    await pumpApp(tester);
    await openMore(tester);
    await tap(tester, find.byKey(const Key('more.store')));

    await tester.enterText(find.byKey(const Key('store.phone')), '٥٩٩');
    api.on('PATCH /my-store', const FakeResponse(422, {
      'message': 'البيانات غير صالحة.',
      'code': 'VALIDATION_FAILED',
      'errors': {'phone': ['رقم الهاتف 9 أو 10 أرقام ويبدأ بـ 0، مثل 0599123456.']},
    }));
    await tap(tester, find.byKey(const Key('store.save')));
    expect(api.requestsTo('PATCH /my-store').single.data, {'name': 'Demo Shop', 'phone': '599', 'address': 'غزة', 'area': null});
    expect(find.text('رقم الهاتف 9 أو 10 أرقام ويبدأ بـ 0، مثل 0599123456.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('store.name')), 'بقالة الأمل');
    await tester.enterText(find.byKey(const Key('store.phone')), '0599123456');
    api.on('PATCH /my-store', const FakeResponse(200, {
      'message': 'تم تحديث إعدادات المتجر بنجاح',
      'store': {'id': 1, 'name': 'بقالة الأمل', 'phone': '0599123456', 'address': 'غزة', 'area': null},
    }));
    final meCalls = api.requestsTo('GET /me').length;
    await tap(tester, find.byKey(const Key('store.save')));
    expect(api.requestsTo('PATCH /my-store').last.data, containsPair('name', 'بقالة الأمل'));
    expect(api.requestsTo('GET /me').length, meCalls + 1, reason: 'the receipt header reads the new name');
    expect(find.text('حُفظت بيانات المحل.'), findsOneWidget);
  });

  testWidgets('user guide: offered on Home until finished, walks the add-product and sale steps, then reopens from More', (tester) async {
    await pumpApp(tester);
    expect(find.byKey(const Key('guide.card')), findsOneWidget);

    await tap(tester, find.byKey(const Key('guide.start')));
    expect(find.text('الخطوة 1 من 4'), findsOneWidget);
    await tap(tester, find.byKey(const Key('guide.next')));
    expect(find.byKey(const Key('guide.step.addProduct')), findsOneWidget);
    expect(find.byKey(const Key('guide.addProduct')), findsOneWidget);
    await tap(tester, find.byKey(const Key('guide.skip')));
    expect(find.byKey(const Key('guide.step.sale')), findsOneWidget);
    expect(find.byKey(const Key('guide.sell')), findsOneWidget);
    await tap(tester, find.byKey(const Key('guide.skip')));
    await tap(tester, find.byKey(const Key('guide.finish')));

    expect(find.byKey(const Key('guide.card')), findsNothing, reason: 'finished: not offered again');
    await openMore(tester);
    await tap(tester, find.byKey(const Key('more.guide')));
    expect(find.byKey(const Key('guide.step.welcome')), findsOneWidget);
  });

  testWidgets('user guide: an employee gets the sale step only; «later» hides the card', (tester) async {
    await pumpApp(tester, role: 'employee');
    await openMore(tester);
    await tap(tester, find.byKey(const Key('more.guide')));
    expect(find.text('الخطوة 1 من 3'), findsOneWidget);
    await tap(tester, find.byKey(const Key('guide.next')));
    expect(find.byKey(const Key('guide.step.sale')), findsOneWidget);
  });

  testWidgets('support: type, subject and details are required; a sent complaint is listed with the team’s reply', (tester) async {
    api.on('GET /support-tickets', const FakeResponse(200, {
      'data': [
        {'id': 1, 'type': 'account', 'subject': 'تجديد الاشتراك', 'details': 'كيف أجدد؟', 'status': 'closed', 'reply': 'تواصلنا معك.', 'created_at': '2026-10-20T08:00:00Z'},
      ],
    }));
    await pumpApp(tester, role: 'employee');
    await openMore(tester);
    await tap(tester, find.byKey(const Key('more.support')));
    expect(find.text('تواصلنا معك.'), findsOneWidget);
    expect(find.text('مغلقة'), findsOneWidget);

    await tap(tester, find.byKey(const Key('support.send')));
    expect(find.text('اختر نوع الدعم.'), findsOneWidget);
    expect(find.text('اكتب موضوع المشكلة.'), findsOneWidget);
    expect(api.requestsTo('POST /support-tickets'), isEmpty);

    await tap(tester, find.byKey(const Key('support.type.technical')));
    await tester.enterText(find.byKey(const Key('support.subject')), 'الطابعة لا تطبع');
    await tester.enterText(find.byKey(const Key('support.details')), 'بعد البيع تظهر رسالة خطأ.');
    api.on('POST /support-tickets', const FakeResponse(201, {'message': 'ok', 'data': {'id': 2}}));
    await tap(tester, find.byKey(const Key('support.send')));
    expect(api.requestsTo('POST /support-tickets').single.data, {
      'type': 'technical',
      'subject': 'الطابعة لا تطبع',
      'details': 'بعد البيع تظهر رسالة خطأ.',
    });
    expect(find.text('وصلت شكواك إلى فريق حسبة، وسنرد عليك هنا.'), findsOneWidget);
    expect(api.requestsTo('GET /support-tickets'), hasLength(2), reason: 'the list reloads after sending');
  });

  testWidgets('password: checked before sending, the server’s «wrong current password» shown, success returns', (tester) async {
    await pumpApp(tester, role: 'employee');
    await openMore(tester);
    await tap(tester, find.byKey(const Key('more.password')));

    await tester.enterText(find.byKey(const Key('pw.current')), 'old-pass');
    await tester.enterText(find.byKey(const Key('pw.new')), 'New-pass-2026');
    await tester.enterText(find.byKey(const Key('pw.confirm')), 'other');
    await tap(tester, find.byKey(const Key('pw.save')));
    expect(find.text('تأكيد كلمة المرور لا يطابقها.'), findsOneWidget);
    expect(api.requestsTo('PATCH /me/password'), isEmpty);

    await tester.enterText(find.byKey(const Key('pw.confirm')), 'New-pass-2026');
    api.on('PATCH /me/password', const FakeResponse(422, {
      'message': 'البيانات غير صالحة.',
      'code': 'VALIDATION_FAILED',
      'errors': {'current_password': ['كلمة المرور الحالية غير صحيحة.']},
    }));
    await tap(tester, find.byKey(const Key('pw.save')));
    expect(find.text('كلمة المرور الحالية غير صحيحة.'), findsOneWidget);

    api.on('PATCH /me/password', const FakeResponse(200, {'message': 'ok'}));
    await tap(tester, find.byKey(const Key('pw.save')));
    expect(api.requestsTo('PATCH /me/password').last.data, {
      'current_password': 'old-pass',
      'password': 'New-pass-2026',
      'password_confirmation': 'New-pass-2026',
    });
    expect(find.byKey(const Key('pw.save')), findsNothing);
    expect(find.text('تم تغيير كلمة المرور، وسُجّل الخروج من الأجهزة الأخرى.'), findsOneWidget);
  });

  Map<String, Object?> sale(int id, {String status = 'active', String paid = '45.00', String? customer}) => {
    'id': id,
    'status': status,
    'total_amount': '45.00',
    'paid_amount': paid,
    'debt_amount': paid == '45.00' ? '0.00' : '45.00',
    'payment_method': 'cash',
    'items': [
      {'item_name': 'تمر مجهول 1 كغ', 'unit': 'piece', 'quantity': '1', 'unit_price': '45.00', 'line_total': '45.00'},
    ],
    'customer': customer == null ? null : {'id': 4, 'name': customer, 'phone': '0599123456'},
    'seller': {'id': 1, 'name': 'Demo owner'},
    'created_at': '2026-10-25T09:30:00.000000Z',
  };

  testWidgets('sales history: today by default, other periods, a tap opens the invoice, the owner can void it', (tester) async {
    api.on('GET /sales', FakeResponse(200, {
      'data': [sale(41), sale(40, paid: '0.00', customer: 'أبو محمد')],
      'meta': {'current_page': 1, 'last_page': 1},
    }));
    await pumpApp(tester);
    await openMore(tester);
    await tap(tester, find.byKey(const Key('more.sales')));

    final today = api.requestsTo('GET /sales').single.queryParameters;
    expect(today['from'], today['to']);
    expect(find.text('فاتورة #40 · أبو محمد'), findsOneWidget);
    expect(find.text('فاتورة #41 · بلا زبون'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('sales.row.40')), matching: find.text('دين')), findsOneWidget);

    await tap(tester, find.byKey(const Key('sales.period.all')));
    expect(api.requestsTo('GET /sales').last.queryParameters.containsKey('from'), isFalse);

    api.on('GET /sales/40', FakeResponse(200, {'data': sale(40, paid: '0.00', customer: 'أبو محمد')}));
    await tap(tester, find.byKey(const Key('sales.row.40')));
    expect(find.byKey(const Key('saleDetail.paper')), findsOneWidget);
    expect(find.byKey(const Key('saleDetail.void')), findsOneWidget);
  });

  testWidgets('an employee opens invoices but cannot void them', (tester) async {
    api.on('GET /sales', FakeResponse(200, {'data': [sale(41)], 'meta': {'current_page': 1, 'last_page': 1}}));
    api.on('GET /sales/41', FakeResponse(200, {'data': sale(41)}));
    await pumpApp(tester, role: 'employee');
    await openMore(tester);
    await tap(tester, find.byKey(const Key('more.sales')));
    await tap(tester, find.byKey(const Key('sales.row.41')));
    expect(find.byKey(const Key('saleDetail.paper')), findsOneWidget);
    expect(find.byKey(const Key('saleDetail.void')), findsNothing);
  });

  group('inventory', () {
    final water = {
      ...productJson(id: 12, name: 'ماء 600 مل', barcode: '6223000777777', price: '2.50', stock: '30'),
      'pack_size': 24,
      'pack_price': '54.00',
    };

    setUp(() {
      api.on('GET /products', FakeResponse(200, {'data': [water]}));
      api.on('GET /products/12', FakeResponse(200, {'data': water}));
      api.on('GET /products/12/movements', const FakeResponse(200, {
        'data': [
          {'id': 3, 'type': 'sale', 'quantity': '-2', 'balance_after': '30', 'reason': null, 'reference_type': 'invoice', 'reference_id': 40, 'created_at': '2026-10-25T09:30:00Z'},
          {'id': 1, 'type': 'opening', 'quantity': '32', 'balance_after': '32', 'reason': null, 'reference_type': null, 'reference_id': null, 'created_at': '2026-10-24T09:30:00Z'},
        ],
      }));
    });

    Future<void> openWater(WidgetTester tester, {String role = 'owner'}) async {
      await pumpApp(tester, role: role);
      await tap(tester, find.byKey(const Key('nav.products')));
      await tap(tester, find.byKey(const Key('products.row.12')));
    }

    testWidgets('a product page: stock, prices, carton and every movement', (tester) async {
      await openWater(tester);
      expect(find.byKey(const Key('product.stock')), findsOneWidget);
      expect(find.text('بيع · فاتورة #40'), findsOneWidget);
      expect(find.text('رصيد افتتاحي'), findsOneWidget);
      expect(find.textContaining('كرتونة 24 قطعة'), findsOneWidget);
    });

    testWidgets('a shelf count sends the difference with its reason, once', (tester) async {
      await openWater(tester);
      await tap(tester, find.byKey(const Key('product.adjust')));
      await tester.enterText(find.byKey(const Key('adjust.quantity')), '٢٧');
      await tester.pump();
      final preview = tester.widget<Text>(find.byKey(const Key('adjust.preview'))).data!.replaceAll(RegExp('[\u2066\u2069]'), '');
      expect(preview, 'المسجّل 30 قطعة ← بعد التعديل 27 قطعة');

      api.on('POST /stock-adjustments', FakeResponse(201, {'message': 'ok', 'product': {...water, 'current_stock': '27'}}));
      await tap(tester, find.byKey(const Key('adjust.save')));
      final sent = api.requestsTo('POST /stock-adjustments').single;
      expect(sent.data, {'product_id': 12, 'quantity': '-3', 'reason': 'جرد الرف'});
      expect(sent.headers['Idempotency-Key'], isNotNull);
      expect(find.text('تعدّلت الكمية. صارت 27 قطعة'), findsOneWidget);
    });

    testWidgets('cartons received add their pieces; a count equal to the record is refused', (tester) async {
      await openWater(tester);
      await tap(tester, find.byKey(const Key('product.adjust')));
      await tester.enterText(find.byKey(const Key('adjust.quantity')), '30');
      await tester.pump();
      expect(find.text('العدد مطابق للمسجّل؛ لا شيء لتعديله.'), findsOneWidget);

      await tap(tester, find.byKey(const Key('adjust.mode.cartons')));
      await tester.enterText(find.byKey(const Key('adjust.quantity')), '2');
      await tester.pump();
      expect(find.byKey(const Key('adjust.preview')), findsOneWidget);
      api.on('POST /stock-adjustments', FakeResponse(201, {'message': 'ok', 'product': {...water, 'current_stock': '78'}}));
      await tap(tester, find.byKey(const Key('adjust.save')));
      expect(api.requestsTo('POST /stock-adjustments').single.data, {'product_id': 12, 'quantity': '2', 'reason': 'استلام بضاعة', 'unit': 'pack'});
    });

    testWidgets('editing prices sends only the product fields, never the stock', (tester) async {
      await openWater(tester);
      await tap(tester, find.byKey(const Key('product.edit')));
      await tester.enterText(find.byKey(const Key('edit.selling_price')), '2.75');
      api.on('PATCH /products/12', FakeResponse(200, {'data': {...water, 'selling_price': '2.75'}}));
      await tap(tester, find.byKey(const Key('edit.save')));
      final body = api.requestsTo('PATCH /products/12').single.data as Map;
      expect(body['selling_price'], '2.75');
      expect(body['pack_size'], '24');
      expect(body.containsKey('current_stock'), isFalse);
      expect(find.text('حُفظت التعديلات.'), findsOneWidget);
    });

    testWidgets('an employee sees the product and its movements but changes nothing', (tester) async {
      await openWater(tester, role: 'employee');
      expect(find.text('بيع · فاتورة #40'), findsOneWidget);
      expect(find.byKey(const Key('product.adjust')), findsNothing);
      expect(find.byKey(const Key('product.edit')), findsNothing);
      expect(find.text('تعديل البضاعة والكمية للمالك أو المدير.'), findsOneWidget);
    });

    testWidgets('a stopped product is listed under «موقوفة» and comes back with one button', (tester) async {
      final stopped = {...water, 'status': 'inactive'};
      await pumpApp(tester);
      await tap(tester, find.byKey(const Key('nav.products')));
      api
        ..on('GET /products', FakeResponse(200, {'data': [stopped]}))
        ..on('GET /products/12', FakeResponse(200, {'data': stopped}));
      await tap(tester, find.text('موقوفة'));
      expect(api.requestsTo('GET /products').last.queryParameters['status'], 'inactive');

      await tap(tester, find.byKey(const Key('products.row.12')));
      expect(find.byKey(const Key('product.adjust')), findsNothing);
      api
        ..on('PATCH /products/12', FakeResponse(200, {'data': water}))
        ..on('GET /products/12', FakeResponse(200, {'data': water}));
      await tap(tester, find.byKey(const Key('product.reactivate')));
      expect(api.requestsTo('PATCH /products/12').single.data, {'status': 'active'});
      expect(find.text('رجع الصنف إلى البيع والقائمة كما كان.'), findsOneWidget);
      expect(find.byKey(const Key('product.adjust')), findsOneWidget);
    });

    testWidgets('low and negative stock lists open the product', (tester) async {
      api.on('GET /products/low-stock', FakeResponse(200, {'data': [{...water, 'current_stock': '3', 'is_low_stock': true}]}));
      api.on('GET /products/negative-stock', FakeResponse(200, {
        'data': [
          {
            'product': {...water, 'current_stock': '-2'},
            'sales': [
              {'invoice_id': 40, 'quantity': '5', 'balance_after': '-2', 'created_at': '2026-10-25T09:30:00Z', 'created_by': 'سامي'},
            ],
          },
        ],
      }));
      await pumpApp(tester);
      await openMore(tester);
      await tap(tester, find.byKey(const Key('more.lowStock')));
      expect(find.textContaining('التنبيه عند'), findsOneWidget);
      await tap(tester, find.byKey(const Key('stockList.row.12')));
      expect(find.byKey(const Key('product.stock')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tap(tester, find.byKey(const Key('more.negative')));
      expect(find.textContaining('فاتورة #40'), findsOneWidget);
      expect(find.textContaining('سامي'), findsOneWidget);
    });
  });
}
