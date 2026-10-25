/// Store-owner registration, the same fields, rules and request as the web /join form
/// (frontend/src/pages/Join.jsx) so both clients create identical accounts through `POST /register`.
library;

/// Cities offered on step 2 (same list as the web); the API stores them with the street in `address`.
const registrationCities = [
  'الخليل', 'بيت لحم', 'القدس', 'رام الله والبيرة', 'نابلس', 'جنين', 'طولكرم', 'قلقيلية',
  'سلفيت', 'طوباس', 'أريحا', 'غزة', 'شمال غزة', 'دير البلح', 'خان يونس', 'رفح',
];

enum RegistrationField { storeName, ownerName, phone, city, street, email, password, passwordConfirmation }

enum RegistrationError {
  storeNameRequired,
  ownerNameRequired,
  phoneRequired,
  phoneInvalid,
  cityRequired,
  streetRequired,
  emailRequired,
  emailInvalid,
  passwordTooShort,
  passwordMismatch,
}

/// The three steps and the fields each one owns.
const registrationSteps = [
  [RegistrationField.storeName, RegistrationField.ownerName],
  [RegistrationField.phone, RegistrationField.city, RegistrationField.street],
  [RegistrationField.email, RegistrationField.password, RegistrationField.passwordConfirmation],
];

/// API field → the form field that shows its error (`address` is the street + city pair; `area` is the city).
const registrationApiFields = {
  'store_name': RegistrationField.storeName,
  'owner_name': RegistrationField.ownerName,
  'phone': RegistrationField.phone,
  'address': RegistrationField.street,
  'area': RegistrationField.city,
  'email': RegistrationField.email,
  'password': RegistrationField.password,
  'password_confirmation': RegistrationField.passwordConfirmation,
};

int stepOf(RegistrationField field) => registrationSteps.indexWhere((fields) => fields.contains(field));

class RegistrationDraft {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phone = RegExp(r'^\d{9,10}$');

  String storeName = '';
  String ownerName = '';
  String phone = '';
  String? city;
  String street = '';
  String email = '';
  String password = '';
  String passwordConfirmation = '';

  /// Spaces and dashes are allowed while typing; the API receives digits only.
  static String digits(String value) => value.replaceAll(RegExp(r'[\s-]'), '');

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
      } else if (!_phone.hasMatch(digits(phone))) {
        e[RegistrationField.phone] = RegistrationError.phoneInvalid;
      }
      if (city == null || city!.isEmpty) e[RegistrationField.city] = RegistrationError.cityRequired;
      if (street.trim().isEmpty) e[RegistrationField.street] = RegistrationError.streetRequired;
    }
    if (step == 2) {
      if (email.trim().isEmpty) {
        e[RegistrationField.email] = RegistrationError.emailRequired;
      } else if (!_email.hasMatch(email.trim())) {
        e[RegistrationField.email] = RegistrationError.emailInvalid;
      }
      if (password.length < 8) e[RegistrationField.password] = RegistrationError.passwordTooShort;
      if (passwordConfirmation.isEmpty || passwordConfirmation != password) {
        e[RegistrationField.passwordConfirmation] = RegistrationError.passwordMismatch;
      }
    }
    return e;
  }

  /// The `POST /register` body, built exactly like the web form's.
  Map<String, String> toRequest() => {
    'store_name': storeName.trim(),
    'owner_name': ownerName.trim(),
    'phone': digits(phone),
    'address': '${street.trim()}، $city',
    'area': city!,
    'email': email.trim(),
    'password': password,
    'password_confirmation': passwordConfirmation,
  };
}
