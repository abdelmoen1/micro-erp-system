import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../domain/print_document.dart';

const _ink = Color(0xFF000000);
const _font = 'IBMPlexSansArabic';

/// One block of the page: how tall it is and how it draws itself.
class _Block {
  const _Block(this.height, this.paint);

  final double height;
  final void Function(Canvas canvas, double top) paint;
}

/// Lays [document] out and draws it black on white, right to left. Thermal printers have no Arabic
/// font worth using, so the page is always an image: Flutter shapes the text and the printer only
/// prints dots. [width] is in dots and [scale] sizes the type; with [pageHeight] the document is cut
/// between blocks into as many pages as it needs, otherwise it is one long roll.
Future<List<ui.Image>> paintDocument(PrintDocument document, {required int width, double scale = 1, double? pageHeight}) async {
  final blocks = _Layout(width.toDouble(), scale).blocks(document);
  final margin = 10 * scale;
  final pages = <List<_Block>>[[]];
  var used = margin * 2;
  for (final block in blocks) {
    if (pageHeight != null && used + block.height > pageHeight && pages.last.isNotEmpty) {
      pages.add([]);
      used = margin * 2;
    }
    pages.last.add(block);
    used += block.height;
  }

  return Future.wait(pages.map((page) => _draw(page, width, margin)));
}

Future<ui.Image> _draw(List<_Block> blocks, int width, double margin) {
  final height = blocks.fold<double>(margin * 2, (sum, block) => sum + block.height).ceil();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..drawColor(const Color(0xFFFFFFFF), BlendMode.src);
  var top = margin;
  for (final block in blocks) {
    block.paint(canvas, top);
    top += block.height;
  }
  return recorder.endRecording().toImage(width, height);
}

class _Layout {
  _Layout(this.width, this.scale);

  final double width;
  final double scale;

  double get _inset => 8 * scale;
  double get _inner => width - _inset * 2;

  TextPainter _text(String text, double size, {FontWeight weight = FontWeight.w500, TextAlign align = TextAlign.right, double? box}) =>
      TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontFamily: _font, fontSize: size * scale, fontWeight: weight, color: _ink, height: 1.35),
        ),
        textDirection: TextDirection.rtl,
        textAlign: align,
      )..layout(minWidth: box ?? 0, maxWidth: box ?? _inner);

  _Block _gap(double height) => _Block(height * scale, (_, _) {});

  _Block _centered(String text, double size, {FontWeight weight = FontWeight.w500}) {
    final painter = _text(text, size, weight: weight, align: TextAlign.center, box: _inner);
    return _Block(painter.height, (canvas, top) => painter.paint(canvas, Offset(_inset, top)));
  }

  /// Label on the right, value on the left; a long value wraps inside its own side.
  _Block _pair(String label, String value, {double size = 21, FontWeight weight = FontWeight.w500}) {
    final left = _text(label, size, weight: weight);
    final right = _text(value, size, weight: weight == FontWeight.w500 ? FontWeight.w600 : weight, box: null);
    final valueBox = math.min(right.width, _inner - left.width - 12 * scale);
    final wrapped = _text(value, size, weight: weight == FontWeight.w500 ? FontWeight.w600 : weight, align: TextAlign.left, box: valueBox);
    return _Block(math.max(left.height, wrapped.height) + 3 * scale, (canvas, top) {
      left.paint(canvas, Offset(width - _inset - left.width, top));
      wrapped.paint(canvas, Offset(_inset, top));
    });
  }

  _Block _rule() => _Block(16 * scale, (canvas, top) {
    final paint = Paint()
      ..color = _ink
      ..strokeWidth = 2 * scale;
    final y = top + 8 * scale;
    for (var x = _inset; x < width - _inset; x += 12 * scale) {
      canvas.drawLine(Offset(x, y), Offset(x + 6 * scale, y), paint);
    }
  });

  _Block _item(PrintRow row) {
    final name = _text(row.name, 22, weight: FontWeight.w700);
    final detail = row.detail == null ? null : _text(row.detail!, 19);
    final amount = _text(row.amount, 22, weight: FontWeight.w700);
    final detailHeight = math.max(detail?.height ?? 0, amount.height);
    return _Block(name.height + detailHeight + 8 * scale, (canvas, top) {
      name.paint(canvas, Offset(width - _inset - name.width, top));
      final line = top + name.height;
      detail?.paint(canvas, Offset(width - _inset - detail.width, line));
      amount.paint(canvas, Offset(_inset, line));
    });
  }

  _Block _stamp(String text) {
    final painter = _text(text, 30, weight: FontWeight.w700, align: TextAlign.center, box: _inner);
    final pad = 6 * scale;
    return _Block(painter.height + pad * 2 + 8 * scale, (canvas, top) {
      canvas.drawRect(
        Rect.fromLTWH(_inset, top, _inner, painter.height + pad * 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = _ink
          ..strokeWidth = 3 * scale,
      );
      painter.paint(canvas, Offset(_inset, top + pad));
    });
  }

  _Block _note(String text) {
    final painter = _text(text, 20);
    return _Block(painter.height + 4 * scale, (canvas, top) => painter.paint(canvas, Offset(width - _inset - painter.width, top)));
  }

  List<_Block> blocks(PrintDocument d) => [
    _centered(d.storeName, 30, weight: FontWeight.w700),
    if ((d.storePhone ?? '').isNotEmpty) _centered(d.storePhone!, 20),
    if ((d.storeAddress ?? '').isNotEmpty) _centered(d.storeAddress!, 20),
    _gap(6),
    _centered('${d.title} ${d.number}', 25, weight: FontWeight.w700),
    if (d.stamp != null) ...[_gap(6), _stamp(d.stamp!)],
    _rule(),
    for (final (label, value) in d.facts) _pair(label, value),
    _rule(),
    for (final row in d.rows) _item(row),
    _rule(),
    for (final total in d.totals)
      total.strong
          ? _pair(total.label, total.value, size: 28, weight: FontWeight.w700)
          : _pair(total.label, total.value),
    if (d.note != null) ...[_gap(6), _note(d.note!)],
    if (d.footer != null) ...[_gap(10), _centered(d.footer!, 20)],
  ];
}
