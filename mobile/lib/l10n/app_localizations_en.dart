// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Hisbah';

  @override
  String get loading => 'Loading…';

  @override
  String get splashTagline => 'Your shop ledger, in your pocket';

  @override
  String get splashSubline => 'Sales, debts and stock in one place';

  @override
  String get splashChecking => 'Checking your session';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginHelper => 'Enter your shop account details';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get showPassword => 'Show';

  @override
  String get hidePassword => 'Hide';

  @override
  String get showPasswordA11y => 'Show password';

  @override
  String get hidePasswordA11y => 'Hide password';

  @override
  String get loginButton => 'Sign in';

  @override
  String get loginSubmitting => 'Signing in…';

  @override
  String get emailRequired => 'Enter your email';

  @override
  String get emailInvalid => 'The email format is not valid';

  @override
  String get passwordRequired => 'Enter your password';

  @override
  String get invalidCredentials => 'The email or password is incorrect.';

  @override
  String get tooManyAttempts => 'Too many attempts. You can try again in';

  @override
  String loginButtonWait(String time) {
    return 'Wait $time';
  }

  @override
  String get networkError =>
      'Cannot reach the server. Check the internet connection and retry.';

  @override
  String get serverError => 'Server error. Please retry shortly.';

  @override
  String serverReference(String reference) {
    return 'Reference: $reference';
  }

  @override
  String get retry => 'Retry';

  @override
  String get sessionExpired => 'Your session has expired. Sign in to continue.';

  @override
  String get accountInactive =>
      'This account is deactivated. Ask the shop owner to reactivate it.';

  @override
  String get storeRequired =>
      'This account has no shop. Contact support to link it to a shop.';

  @override
  String get forbidden => 'You are not allowed to do this.';

  @override
  String get tabHome => 'Home';

  @override
  String get tabPos => 'Sell';

  @override
  String get tabCustomers => 'Customers';

  @override
  String get tabProducts => 'Products';

  @override
  String get tabMore => 'More';

  @override
  String get sellA11y => 'Sell';

  @override
  String get sellCurrentA11y => 'Sell — you are on the sale screen';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get offlineBanner => 'No connection — sales need internet';

  @override
  String get placeholderHome => 'Today — owner and manager landing';

  @override
  String get placeholderCustomers => 'Customers list';

  @override
  String get placeholderProducts => 'Products and low stock';

  @override
  String get placeholderPos => 'Sale cart — employee landing';

  @override
  String get placeholderBody =>
      'This screen is designed in S4 (US-1508). Only the app frame is shown here: header, connection status and navigation.';

  @override
  String get placeholderPosBody =>
      'Scanning, cart and checkout are built in a later sprint (S5). Only the app frame is shown here.';

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleManager => 'Manager';

  @override
  String get roleEmployee => 'Employee';

  @override
  String get moreNote =>
      'In R1, More has only the profile and sign out. Staff management is on the web.';

  @override
  String get logout => 'Sign out';

  @override
  String get logoutConfirmTitle => 'Sign out?';

  @override
  String get logoutConfirmBody =>
      'You will need your email and password to sign in again.';

  @override
  String get stay => 'Stay';

  @override
  String homeGreeting(String name) {
    return 'Hello, $name';
  }

  @override
  String get homeTodaySales => 'Today\'s sales';

  @override
  String homeInvoicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invoices',
      one: '1 invoice',
      zero: 'No invoices yet',
    );
    return '$_temp0';
  }

  @override
  String get homeCash => 'Cash';

  @override
  String get homeCredit => 'On credit';

  @override
  String get homeCollectedToday => 'Collected today';

  @override
  String get homeOutstandingDebts => 'Outstanding debts';

  @override
  String homeCustomersWithDebt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count customers owe',
      one: '1 customer owes',
      zero: 'No customers owe',
    );
    return '$_temp0';
  }

  @override
  String get homeShortcuts => 'Shortcuts';

  @override
  String get homeNewSale => 'New sale';

  @override
  String get homeRecentInvoices => 'Today\'s latest invoices';

  @override
  String get homeNoInvoices => 'No invoices yet today';

  @override
  String get homeNoInvoicesBody =>
      'Start the first sale from the Sell button below.';

  @override
  String get homeWalkIn => 'Walk-in customer';

  @override
  String get homeLoadError => 'Couldn\'t load today\'s dashboard.';

  @override
  String get currencySymbol => '₪';

  @override
  String get scanEntryTitle => 'View product details';

  @override
  String get scanEntryBody =>
      'Name, price and stock. View only, nothing is added to a sale.';

  @override
  String get scanBarcode => 'Scan barcode';

  @override
  String get scanCloseA11y => 'Close the scanner and return to the sale';

  @override
  String get scanTorchOnA11y => 'Turn the light on';

  @override
  String get scanTorchOffA11y => 'Turn the light off';

  @override
  String get scanInstruction => 'Point the barcode inside the frame';

  @override
  String get scanRead => 'Code read';

  @override
  String get scanPaused => 'Scanning paused';

  @override
  String get scanSearchingCode => 'Looking for a barcode…';

  @override
  String get scanSearchingProduct => 'Looking up the product…';

  @override
  String get scanHintTitle => 'Hard to read?';

  @override
  String get scanHintBody =>
      'Move the barcode closer slowly, tilt the product to avoid glare, and turn on the light. Or type it in.';

  @override
  String get scanManual => 'Enter barcode manually';

  @override
  String get scanFound => 'Product found';

  @override
  String get scanPrice => 'Selling price';

  @override
  String get scanStock => 'Current stock';

  @override
  String get scanBarcodeLabel => 'Barcode';

  @override
  String get scanAnother => 'Scan another product';

  @override
  String get scanBackToSale => 'Back to the sale';

  @override
  String get scanNotFoundTitle => 'No product has this barcode';

  @override
  String get scanNotFoundBody => 'Check the number or scan it again.';

  @override
  String get scanAgain => 'Scan again';

  @override
  String get scanDeniedTitle => 'Scanning needs the camera';

  @override
  String get scanDeniedBody =>
      'Hisbah uses the camera only to read barcodes while scanning. Allow it now or type the number.';

  @override
  String get scanAllowCamera => 'Allow camera';

  @override
  String get scanBlockedBody =>
      'Camera permission is denied. Turn it on in the phone settings to read barcodes, or type the number.';

  @override
  String get scanBlockedPath => 'Settings → Apps → Hisbah → Permissions →';

  @override
  String get scanBlockedPathCamera => 'Camera';

  @override
  String get scanBlockedPathAllow => '→ Allow only while using the app';

  @override
  String get scanOpenSettings => 'Open settings';

  @override
  String get manualLabel => 'Barcode number';

  @override
  String get manualHint => 'The digits under the bars';

  @override
  String get manualHelper =>
      'Type the digits as they appear under the barcode lines.';

  @override
  String get manualEmpty => 'Enter the barcode number';

  @override
  String get manualSubmit => 'Show product';

  @override
  String get manualCancelA11y => 'Cancel manual entry';

  @override
  String get lookupFailedTitle => 'Couldn\'t show the product';

  @override
  String get lookupSavedForRetry => 'saved for retry.';
}
