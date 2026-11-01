import 'dart:typed_data';

/// The few ESC/POS commands a receipt needs. Everything is sent as a raster image, which every
/// 58 mm and 80 mm thermal printer understands whatever fonts it has.
abstract final class EscPos {
  /// ESC @: the printer back to its defaults.
  static final init = Uint8List.fromList([0x1B, 0x40]);

  /// Paper out past the cutter, then a partial cut where the printer has one.
  static final finish = Uint8List.fromList([0x1B, 0x64, 0x05, 0x1D, 0x56, 0x42, 0x00]);

  /// Below this a dot prints: type stays solid on heat paper, with no grey to dither.
  static const _threshold = 160;

  /// Cheap printers lose data on one huge image, so it goes in bands of [bandHeight] rows.
  static const bandHeight = 200;

  /// [rgba] is a [width] × [height] image, 4 bytes a pixel. One `GS v 0` command per band.
  static List<Uint8List> raster(Uint8List rgba, int width, int height) {
    final rowBytes = (width + 7) ~/ 8;
    final bands = <Uint8List>[];
    for (var top = 0; top < height; top += bandHeight) {
      final rows = height - top < bandHeight ? height - top : bandHeight;
      final band = Uint8List(8 + rowBytes * rows);
      band.setAll(0, [0x1D, 0x76, 0x30, 0x00, rowBytes & 0xFF, rowBytes >> 8, rows & 0xFF, rows >> 8]);
      for (var y = 0; y < rows; y++) {
        for (var x = 0; x < width; x++) {
          final at = (top + y) * width * 4 + x * 4;
          // Rec. 601 luma, in integers.
          final luma = (rgba[at] * 299 + rgba[at + 1] * 587 + rgba[at + 2] * 114) ~/ 1000;
          if (luma < _threshold) band[8 + y * rowBytes + (x >> 3)] |= 0x80 >> (x & 7);
        }
      }
      bands.add(band);
    }
    return bands;
  }
}
