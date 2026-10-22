// Renders every raster brand asset from HisbahMarkPainter, so the launcher icons, favicon and
// brand masters cannot drift from the mark drawn in the app. Run from mobile/ after changing
// the mark:
//
//   flutter test tool/brand/render_brand_assets_test.dart
//
// Writes: Android legacy + adaptive launcher icons, web favicon / PWA icons, the Windows .ico,
// and docs/design/assets/brand (SVG masters + PNG lockups).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/core/theme/hisbah_tokens.dart';
import 'package:smartshop/core/widgets/hisbah_logo.dart';

const _res = 'android/app/src/main/res';
const _docs = '../docs/design/assets/brand';

/// Launcher tile corner, as a share of the side (same as [HisbahMarkTile]).
const _corner = 0.225;

/// SVG number: at most 3 decimals, no trailing zeros.
String _n(num v) => double.parse(v.toStringAsFixed(3)).toString().replaceFirst(RegExp(r'\.0$'), '');

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Draws the mark centred in a [side]-px square at [scale] of the side, optionally on a tile.
Future<Uint8List> _icon(
  int side, {
  required double scale,
  required Color ink,
  Color? tile,
  bool rounded = true,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final s = side.toDouble();
  if (tile != null) {
    final paint = Paint()..color = tile;
    rounded
        ? canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & Size(s, s), Radius.circular(s * _corner)), paint)
        : canvas.drawRect(Offset.zero & Size(s, s), paint);
  }
  final markSide = s * scale;
  canvas.translate((s - markSide) / 2, (s - markSide) / 2);
  HisbahMarkPainter(color: ink).paint(canvas, Size.square(markSide));
  final image = await recorder.endRecording().toImage(side, side);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

/// PNG-compressed .ico (Windows Vista+).
Uint8List _ico(List<(int, Uint8List)> images) {
  final header = BytesBuilder()
    ..add(_u16(0))
    ..add(_u16(1))
    ..add(_u16(images.length));
  var offset = 6 + 16 * images.length;
  final data = BytesBuilder();
  for (final (side, png) in images) {
    header
      ..addByte(side >= 256 ? 0 : side)
      ..addByte(side >= 256 ? 0 : side)
      ..addByte(0)
      ..addByte(0)
      ..add(_u16(1))
      ..add(_u16(32))
      ..add(_u32(png.length))
      ..add(_u32(offset));
    offset += png.length;
    data.add(png);
  }
  return (header..add(data.takeBytes())).takeBytes();
}

Uint8List _u16(int v) => (ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List();
Uint8List _u32(int v) => (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List();

void _write(String path, List<int> bytes) => File(path)
  ..createSync(recursive: true)
  ..writeAsBytesSync(bytes);

String _svg(String body, {String viewBox = '0 0 100 100'}) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="$viewBox">\n$body\n</svg>\n';

String _markPaths(String stroke) =>
    '  <g fill="none" stroke="$stroke" stroke-linecap="butt" stroke-linejoin="miter">\n'
    '    <path d="${HisbahMarkPainter.svgLetter}" stroke-width="${_n(HisbahMarkPainter.letterStroke)}"/>\n'
    '    <path d="${HisbahMarkPainter.svgRule}" stroke-width="${_n(HisbahMarkPainter.ruleStroke)}"/>\n'
    '  </g>';

void main() {
  testWidgets('render brand assets', (tester) async {
    const teal = HisbahColors.primary;
    const ivory = HisbahColors.surface;

    await tester.runAsync(() async {
      // Android: legacy square icon (pre-8.0 launchers) and adaptive layers (108 dp canvas; the
      // mark stays inside the 66 dp safe circle). The foreground doubles as the Android 13
      // themed-icon monochrome layer.
      const densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};
      for (final MapEntry(key: name, value: k) in densities.entries) {
        _write(
          '$_res/mipmap-$name/ic_launcher.png',
          await _icon((48 * k).round(), scale: 1 - 2 * HisbahMarkPainter.tileInset, ink: ivory, tile: teal),
        );
        _write('$_res/mipmap-$name/ic_launcher_foreground.png', await _icon((108 * k).round(), scale: 0.64, ink: ivory));
      }

      // Web: favicon, PWA icons (rounded tile) and maskable icons (full bleed, 80 % safe zone).
      _write('web/favicon.png', await _icon(32, scale: 0.84, ink: ivory, tile: teal));
      for (final side in [192, 512]) {
        _write('web/icons/Icon-$side.png', await _icon(side, scale: 1 - 2 * HisbahMarkPainter.tileInset, ink: ivory, tile: teal));
        _write('web/icons/Icon-maskable-$side.png', await _icon(side, scale: 0.7, ink: ivory, tile: teal, rounded: false));
      }

      // Windows: small sizes give the mark more of the tile so it stays legible.
      _write(
        'windows/runner/resources/app_icon.ico',
        _ico([
          for (final side in [16, 24, 32, 48, 64, 128, 256])
            (side, await _icon(side, scale: side <= 32 ? 0.84 : 1 - 2 * HisbahMarkPainter.tileInset, ink: ivory, tile: teal)),
        ]),
      );

      // Brand masters.
      File('$_docs/hisbah-mark.svg')
        ..createSync(recursive: true)
        ..writeAsStringSync(_svg(_markPaths(_hex(teal))));
      File('$_docs/hisbah-mark-reversed.svg').writeAsStringSync(_svg(_markPaths(_hex(ivory))));
      File('$_docs/hisbah-mark-mono.svg').writeAsStringSync(_svg(_markPaths('currentColor')));
      final inset = 100 * HisbahMarkPainter.tileInset;
      final k = 1 - 2 * HisbahMarkPainter.tileInset;
      File('$_docs/hisbah-app-icon.svg').writeAsStringSync(
        _svg(
          '  <rect width="100" height="100" rx="${_n(100 * _corner)}" fill="${_hex(teal)}"/>\n'
          '  <g transform="translate(${_n(inset)} ${_n(inset)}) scale(${_n(k)})">\n${_markPaths(_hex(ivory))}\n  </g>',
        ),
      );
      _write('$_docs/hisbah-app-icon-1024.png', await _icon(1024, scale: k, ink: ivory, tile: teal));
    });

    // Lockups (mark + wordmark) need the app font, so they render through widgets.
    final plex = FontLoader('IBMPlexSansArabic')..addFont(rootBundle.load('assets/fonts/IBMPlexSansArabic-Bold.ttf'));
    await plex.load();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<void> lockup(String name, Color ink, Color? ground, {required bool vertical}) async {
      const key = Key('lockup');
      tester.view.physicalSize = vertical ? const Size(640, 640) : const Size(960, 400);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: Container(
                color: ground,
                padding: const EdgeInsets.all(48),
                child: HisbahLogo(markSize: vertical ? 320 : 240, vertical: vertical, color: ink),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final image = await tester.renderObject<RenderRepaintBoundary>(find.byKey(key)).toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        _write('$_docs/$name.png', bytes!.buffer.asUint8List());
      });
    }

    await lockup('hisbah-logo-vertical', teal, HisbahColors.ground, vertical: true);
    await lockup('hisbah-logo-horizontal', teal, HisbahColors.ground, vertical: false);
    await lockup('hisbah-logo-horizontal-reversed', ivory, teal, vertical: false);
    await lockup('hisbah-logo-horizontal-mono', Colors.black, null, vertical: false);
  });
}
