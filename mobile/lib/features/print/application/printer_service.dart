import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';

import '../../../core/providers.dart';
import '../domain/print_document.dart';
import 'document_painter.dart';
import 'escpos.dart';

/// A printer already paired with the phone from Android's Bluetooth settings.
class BluetoothPrinter {
  const BluetoothPrinter({required this.name, required this.address});

  final String name;
  final String address;
}

/// The roll in the printer, by its printable width in dots at 203 dpi.
enum PaperWidth {
  mm58(384, 1),
  mm80(576, 1.4);

  const PaperWidth(this.dots, this.scale);

  final int dots;
  final double scale;

  static PaperWidth fromName(String? name) => name == mm80.name ? mm80 : mm58;
}

/// The phone's side of printing, behind an interface so tests need no printer.
abstract interface class PrinterPort {
  /// Android 12 and later ask the user once; older phones grant it with the app.
  Future<bool> requestBluetooth();
  Future<bool> bluetoothOn();
  Future<List<BluetoothPrinter>> paired();
  Future<bool> connect(String address);
  Future<bool> write(Uint8List bytes);
  Future<void> disconnect();

  /// Android's own print screen: Wi-Fi and USB printers, or saving a PDF.
  Future<void> systemPrint(String jobName, Uint8List pdf);
}

class DevicePrinterPort implements PrinterPort {
  @override
  Future<bool> requestBluetooth() async => (await Permission.bluetoothConnect.request()).isGranted;

  @override
  Future<bool> bluetoothOn() => PrintBluetoothThermal.bluetoothEnabled;

  @override
  Future<List<BluetoothPrinter>> paired() async => [
    for (final device in await PrintBluetoothThermal.pairedBluetooths)
      BluetoothPrinter(name: device.name, address: device.macAdress),
  ];

  @override
  Future<bool> connect(String address) async {
    if (await PrintBluetoothThermal.connectionStatus) await PrintBluetoothThermal.disconnect;
    return PrintBluetoothThermal.connect(macPrinterAddress: address);
  }

  @override
  Future<bool> write(Uint8List bytes) => PrintBluetoothThermal.writeBytes(bytes);

  @override
  Future<void> disconnect() async {
    await PrintBluetoothThermal.disconnect;
  }

  @override
  Future<void> systemPrint(String jobName, Uint8List pdf) async {
    await Printing.layoutPdf(name: jobName, format: PdfPageFormat.a4, onLayout: (_) async => pdf);
  }
}

final printerPortProvider = Provider<PrinterPort>((ref) => DevicePrinterPort());

/// The printer the shop chose stays chosen, so the next invoice is one press away.
class PrinterChoice {
  const PrinterChoice({this.address, this.paper = PaperWidth.mm58});

  final String? address;
  final PaperWidth paper;
}

class PrintFailed implements Exception {
  const PrintFailed();
}

class PrinterService {
  PrinterService(this._port, this._read, this._write);

  static const _addressKey = 'printer.address';
  static const _paperKey = 'printer.paper';

  final PrinterPort _port;
  final Future<String?> Function(String key) _read;
  final Future<void> Function(String key, String value) _write;

  PrinterPort get port => _port;

  Future<PrinterChoice> choice() async =>
      PrinterChoice(address: await _read(_addressKey), paper: PaperWidth.fromName(await _read(_paperKey)));

  /// Sends the document to the printer in one connection. Throws [PrintFailed] if it cannot be
  /// reached or stops taking data; nothing is recorded by printing, so trying again is safe.
  Future<void> printBluetooth(PrintDocument document, BluetoothPrinter printer, PaperWidth paper) async {
    await _write(_addressKey, printer.address);
    await _write(_paperKey, paper.name);

    final pages = await paintDocument(document, width: paper.dots, scale: paper.scale);
    final rgba = await pages.single.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bands = EscPos.raster(rgba!.buffer.asUint8List(), pages.single.width, pages.single.height);

    if (!await _port.connect(printer.address)) throw const PrintFailed();
    try {
      for (final part in [EscPos.init, ...bands, EscPos.finish]) {
        if (!await _port.write(part)) throw const PrintFailed();
      }
    } finally {
      await _port.disconnect();
    }
  }

  /// A4 pages for Android's print screen: 1000 dots across a 190 mm line.
  Future<void> printSystem(PrintDocument document) async {
    final pages = await paintDocument(document, width: 1000, scale: 1.3, pageHeight: 1400);
    final pdf = pw.Document();
    for (final page in pages) {
      final png = await page.toByteData(format: ui.ImageByteFormat.png);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(10 * PdfPageFormat.mm),
          build: (_) => pw.Align(
            alignment: pw.Alignment.topCenter,
            child: pw.Image(pw.MemoryImage(png!.buffer.asUint8List())),
          ),
        ),
      );
    }
    await _port.systemPrint(document.jobName, await pdf.save());
  }
}

final printerServiceProvider = Provider<PrinterService>((ref) {
  final store = ref.watch(keyValueStoreProvider);
  return PrinterService(ref.watch(printerPortProvider), store.read, store.write);
});
