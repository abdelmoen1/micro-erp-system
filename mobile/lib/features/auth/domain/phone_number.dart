import '../../../core/widgets/latin_digits.dart';

/// The sign-in mobile number in its one local form, `05XXXXXXXX` (the server's
/// `App\Support\PhoneNumber`): spaces, dashes, Arabic digits and +970 / 00970 / +972 are accepted
/// while typing. Null when the text is not a mobile number.
String? normalizePhone(String input) {
  var digits = latinDigits(input.trim()).replaceAll(RegExp(r'[\s\-().]'), '');
  digits = digits.replaceFirst(RegExp(r'^(\+|00)'), '');
  digits = digits.replaceFirstMapped(RegExp(r'^(970|972)0?(5\d{8})$'), (m) => '0${m[2]}');
  return RegExp(r'^05\d{8}$').hasMatch(digits) ? digits : null;
}

/// `059•••••56` for confirmations on screen.
String maskPhone(String local) =>
    local.length < 5 ? local : '${local.substring(0, 3)}•••••${local.substring(local.length - 2)}';
