/// Store-owner registration, the same fields, rules and request as the web /join form
/// (frontend/src/pages/Join.jsx) so both clients create identical accounts through `POST /register`.
/// The owner signs in with the mobile number; the e-mail is optional.
library;

import 'phone_number.dart';

/// Cities offered on step 2 (same list as the web); the API stores them with the street in `address`.
const registrationCities = [
  'الخليل', 'بيت لحم', 'القدس', 'رام الله والبيرة', 'نابلس', 'جنين', 'طولكرم', 'قلقيلية',
  'سلفيت', 'طوباس', 'أريحا', 'غزة', 'شمال غزة', 'دير البلح', 'خان يونس', 'رفح',
];

enum RegistrationField { storeName, ownerName, phone, city, street, email, password, passwordConfirmation, otpCode }

enum RegistrationError {
  storeNameRequired,
  ownerNameRequired,
  phoneRequired,
  phoneInvalid,
  cityRequired,
  streetRequired,
  emailInvalid,
  passwordTooShort,
  passwordMismatch,
  otpCodeInvalid,
}

/// The three steps and the fields each one owns. The SMS code, when codes are on, comes after them.
const registrationSteps = [
  [RegistrationField.storeName, RegistrationField.ownerName],
  [RegistrationField.phone, RegistrationField.city, RegistrationField.street],
  [RegistrationField.email, RegistrationField.password, RegistrationField.passwordConfirmation],
];

/// API field → the form field that shows its error (`address` is the street + city pair; `area` is the city).
const registrationApiFields = {
  'store_name': RegistrationField.storeName,
  'owner_name': RegistrationField.ownerName,
  'owner_phone': RegistrationField.phone,
  'phone': RegistrationField.phone,
  'address': RegistrationField.street,
  'area': RegistrationField.city,
  'email': RegistrationField.email,
  'password': RegistrationField.password,
  'password_confirmation': RegistrationField.passwordConfirmation,
  'otp_code': RegistrationField.otpCode,
};

/// Fields outside the three steps (the SMS code) report step 3.
int stepOf(RegistrationField field) {
  final step = registrationSteps.indexWhere((fields) => fields.contains(field));
  return step < 0 ? registrationSteps.length - 1 : step;
}

class RegistrationDraft {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String storeName = '';
  String ownerName = '';

  /// The owner's mobile: the account signs in with it, and it is the store's phone too.
  String phone = '';
  String? city;
  String street = '';
  String email = '';
  String password = '';
  String passwordConfirmation = '';

  /// The 6-digit SMS code, when codes are on.
  String otpCode = '';

  /// Spaces and dashes are allowed while typing; the API receives `05XXXXXXXX`.
  String get normalizedPhone => normalizePhone(phone) ?? phone.replaceAll(RegExp(r'[\s-]'), '');

  /// Client-side checks of one step, in the web form's order and wording.
  Map<RegistrationField, RegistrationError> validateStep(int step) {
    final e = <RegistrationField, RegistrationError>{};
    if (step == 0) {
      if (storeName.trim().isEmpty) e[RegistrationField.storeName] = RegistrationError.storeNameRequired;
      if (ownerName.trim().isEmpty) e[RegistrationField.ownerName] = RegistrationError.ownerNameRequired;
    }
    if (step == 1) {
      if (phone.trim().isEmpty) {
        e[RegistrationField.phone] = RegistrationError.phoneRequired;
      } else if (normalizePhone(phone) == null) {
        e[RegistrationField.phone] = RegistrationError.phoneInvalid;
      }
      if (city == null || city!.isEmpty) e[RegistrationField.city] = RegistrationError.cityRequired;
      if (street.trim().isEmpty) e[RegistrationField.street] = RegistrationError.streetRequired;
    }
    if (step == 2) {
      if (email.trim().isNotEmpty && !_email.hasMatch(email.trim())) {
        e[RegistrationField.email] = RegistrationError.emailInvalid;
      }
      if (password.length < 8) e[RegistrationField.password] = RegistrationError.passwordTooShort;
      if (passwordConfirmation.isEmpty || passwordConfirmation != password) {
        e[RegistrationField.passwordConfirmation] = RegistrationError.passwordMismatch;
      }
    }
    return e;
  }

  Map<RegistrationField, RegistrationError> validateCode() => {
    if (!RegExp(r'^\d{6}$').hasMatch(otpCode.trim())) RegistrationField.otpCode: RegistrationError.otpCodeInvalid,
  };

  /// The `POST /register` body, built exactly like the web form's.
  Map<String, String> toRequest() => {
    'store_name': storeName.trim(),
    'owner_name': ownerName.trim(),
    'owner_phone': normalizedPhone,
    'phone': normalizedPhone,
    'address': '${street.trim()}، $city',
    'area': city!,
    if (email.trim().isNotEmpty) 'email': email.trim(),
    'password': password,
    'password_confirmation': passwordConfirmation,
    if (otpCode.trim().isNotEmpty) 'otp_code': otpCode.trim(),
  };
}
