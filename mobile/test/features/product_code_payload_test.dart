import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/core/money/fixed_point.dart';
import 'package:smartshop/features/products/domain/product_code_payload.dart';

void main() {
  group('parseProductCode — only what the code carries', () {
    test('a plain EAN-13 is a barcode and nothing else', () {
      final p = parseProductCode('6281007041235') as ProductCodeData;
      expect(p.barcode, '6281007041235');
      expect(p.name, isNull);
      expect(p.sellingPrice, isNull);
      expect(p.fromCode, {'barcode'});
    });

    test('a GS1 Digital Link gives the GTIN, padded GTIN-14 becomes EAN-13', () {
      final p = parseProductCode('https://id.gs1.org/01/06281007041235/10/LOT42') as ProductCodeData;
      expect(p.barcode, '6281007041235');
      expect(p.fromCode, {'barcode'});
    });

    test('a GS1 element string (01) with more AIs gives the GTIN', () {
      expect((parseProductCode('(01)06281007041235(17)270101') as ProductCodeData).barcode, '6281007041235');
      expect((parseProductCode('010628100704123517270101\u001d10ABC') as ProductCodeData).barcode, '6281007041235');
    });

    test('a JSON code fills only valid known keys', () {
      final p = parseProductCode('{"name":"تمر مجهول 1 كغ","barcode":"6281007041235","price":"45","unit":"piece","color":"red"}') as ProductCodeData;
      expect(p.name, 'تمر مجهول 1 كغ');
      expect(p.barcode, '6281007041235');
      expect(p.sellingPrice, '45.00');
      expect(p.unit, ProductUnit.piece);
    });

    test('invalid JSON values are dropped, not guessed', () {
      final p = parseProductCode('{"name":"Tea","price":"cheap","unit":"box"}') as ProductCodeData;
      expect(p.fromCode, {'name'});
      expect(p.sellingPrice, isNull);
      expect(p.unit, isNull);
    });

    test('a web link, free text or an empty code is unreadable', () {
      for (final raw in ['https://example-brand.com/promo?id=88', 'Visit our shop today!', '   ', '{"foo":1}', '{not json']) {
        final p = parseProductCode(raw);
        expect(p, isA<UnreadableCode>(), reason: raw);
        expect((p as UnreadableCode).raw, raw);
      }
    });
  });
}
