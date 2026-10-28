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
  String get guideTitle => 'User guide';

  @override
  String get guideCardTitle => 'New to Hisbah?';

  @override
  String get guideCardBody =>
      'Try it in two minutes: add a product by its barcode, then sell it on an invoice.';

  @override
  String get guideStart => 'Start the guide';

  @override
  String get guideLater => 'Later';

  @override
  String guideStep(int n, int total) {
    return 'Step $n of $total';
  }

  @override
  String get guideWelcomeTitle => 'Welcome to Hisbah';

  @override
  String get guideWelcomeBody =>
      'Together we will try the two things a shop does most: adding a product by barcode and making an invoice by barcode. Everything here is real and saved in your store.';

  @override
  String get guideAddTitle => 'Add your first product by barcode';

  @override
  String get guideAdd1 =>
      'Tap «Scan a product now» and point the camera at the barcode of any product in your shop.';

  @override
  String get guideAdd2 =>
      'If the product is known we fill in its name; you type the price and the quantity on hand.';

  @override
  String get guideAdd3 => 'Tap «Save», then come back to continue the guide.';

  @override
  String get guideAddAction => 'Scan a product now';

  @override
  String get guideAddDone => 'You added your first product. Well done!';

  @override
  String get guideSaleTitle => 'Make your first invoice by barcode';

  @override
  String get guideSale1 =>
      'Tap «Open the sale screen», then scan the product; it goes straight into the cart.';

  @override
  String get guideSale2 =>
      'Scan it again to add one more, or scan other products.';

  @override
  String get guideSale3 =>
      'Tap «Complete sale», choose cash or credit to a customer, then save the invoice.';

  @override
  String get guideSaleAction => 'Open the sale screen';

  @override
  String get guideDoneTitle => 'Ready to work!';

  @override
  String get guideDoneBody =>
      'Invoices are under «Sales», debts under «Customers» and stock under «Products». Settings and support are under «More», where you can open this guide any time.';

  @override
  String get guideFinish => 'Start working';

  @override
  String get guideNext => 'Next';

  @override
  String get guideSkip => 'Skip this step';

  @override
  String get moreGuideSub =>
      'Try adding a product and making an invoice, step by step';

  @override
  String get moreSupport => 'Technical support';

  @override
  String get moreSupportSub =>
      'Send a complaint or a suggestion to the Hisbah team';

  @override
  String get supportType => 'Type of support';

  @override
  String get supportTypeTechnical => 'Technical problem';

  @override
  String get supportTypeAccount => 'Account and subscription';

  @override
  String get supportTypeSuggestion => 'Suggestion';

  @override
  String get supportTypeOther => 'Other';

  @override
  String get supportSubject => 'Subject';

  @override
  String get phSupportSubject =>
      'In a few words, e.g. the printer does not print';

  @override
  String get supportDetails => 'Details';

  @override
  String get phSupportDetails =>
      'What happened, where and when? The more you write, the faster we help';

  @override
  String get supportSend => 'Send';

  @override
  String get supportSent =>
      'Your complaint reached the Hisbah team; we will reply here.';

  @override
  String get supportTypeRequired => 'Choose the type of support.';

  @override
  String get supportSubjectRequired => 'Write the subject.';

  @override
  String get supportDetailsRequired => 'Write the details.';

  @override
  String get supportMine => 'My complaints';

  @override
  String get supportNone => 'You have not sent any complaint yet.';

  @override
  String get supportStatusOpen => 'New';

  @override
  String get supportStatusInProgress => 'In progress';

  @override
  String get supportStatusClosed => 'Closed';

  @override
  String get supportReply => 'Reply from the Hisbah team';

  @override
  String get supportLoadError =>
      'Could not load the complaints. Check the connection and try again.';

  @override
  String get phBarcode => 'The number under the barcode bars on the pack';

  @override
  String get phOpeningStock => 'How many you have on the shelf now';

  @override
  String get phPackSize => 'Pieces in one carton';

  @override
  String get phPackPrice => 'Price of a whole carton to the customer';

  @override
  String get phAddQty => 'How much of these goods arrived';

  @override
  String get phReason => 'Why the stock changes, e.g. goods received';

  @override
  String get phAdjustQty => 'The quantity for the change chosen above';

  @override
  String get phStoreName => 'The name printed on top of the receipt';

  @override
  String get phAddress => 'Street or nearest landmark, printed on the receipt';

  @override
  String get phArea => 'City or area, e.g. Nablus';

  @override
  String get phCurrentPw => 'The password you sign in with now';

  @override
  String get phConfirmPw => 'Type the new password again';

  @override
  String get phLoginPw => 'Your account password';

  @override
  String get phRegStoreName => 'Your shop\'s name as customers know it';

  @override
  String get phOwnerName => 'Your full name';

  @override
  String get phStreet => 'Street or nearest landmark';

  @override
  String get phPhone => 'Your mobile number, e.g. 0599123456';

  @override
  String get phEmail => 'The email you sign in with, e.g. name@store.ps';

  @override
  String get phCustomerName => 'The customer\'s name as you call them';

  @override
  String get phPaidNow => 'How much the customer paid now, in shekels';

  @override
  String get phPayAmount => 'The amount the customer paid, in shekels';

  @override
  String get phVoidReason => 'Why this invoice is voided';

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
  String get manualHint => 'The digits as shown under the barcode bars';

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

  @override
  String get cancel => 'Cancel';

  @override
  String get backWord => 'Back';

  @override
  String get searchByName => 'Search by name';

  @override
  String get scanShort => 'Scan';

  @override
  String get totalWord => 'Total';

  @override
  String get payButton => 'Checkout';

  @override
  String linesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String get scanLookingUp => 'Looking up the product…';

  @override
  String get barcodeWord => 'Barcode';

  @override
  String get scanAdded => 'Added to the cart';

  @override
  String scanIncremented(String name) {
    return '+1 · $name';
  }

  @override
  String scanQuantityNow(String quantity) {
    return 'Quantity now $quantity';
  }

  @override
  String get scanAddedWeighed => 'Added by weight';

  @override
  String get scanDuplicate => 'Repeat read, not added';

  @override
  String get scanDuplicateBody =>
      'Same barcode within 1.5 seconds. Scan again in a moment to add one.';

  @override
  String get scanUnknown => 'Unknown barcode';

  @override
  String get scanUnknownBody => 'No product in your store has this code:';

  @override
  String get scanLookupFailed => 'Couldn\'t look up the product';

  @override
  String get scanLookupFailedBody => 'Check the connection, then try again.';

  @override
  String get cartEmptyTitle => 'Scan a product to start';

  @override
  String get cartEmptyBody =>
      'Or search for it by name. Products sold by weight open the weight screen.';

  @override
  String get unitChipPiece => 'Piece';

  @override
  String get unitChipWeighed => 'By weight';

  @override
  String get pieceWord => 'piece';

  @override
  String get piecesWord => 'pieces';

  @override
  String get kgShort => 'kg';

  @override
  String get gramShort => 'g';

  @override
  String get justNew => 'New';

  @override
  String get justIncremented => '+1 now';

  @override
  String get justAddedWeighed => 'Just added';

  @override
  String editWeightOf(String name) {
    return 'Edit the weight of $name';
  }

  @override
  String removeItem(String name) {
    return 'Remove $name';
  }

  @override
  String decreaseItem(String name) {
    return 'One less $name';
  }

  @override
  String increaseItem(String name) {
    return 'One more $name';
  }

  @override
  String lineStockNote(String stock) {
    return 'Only $stock in recorded stock. The sale is allowed and flagged for review.';
  }

  @override
  String get stockWord => 'Stock';

  @override
  String get weightTitle => 'Enter the weight';

  @override
  String get weightTitleEdit => 'Edit the weight';

  @override
  String get perKg => 'per kg';

  @override
  String get unitKilogram => 'Kilograms';

  @override
  String get unitGram => 'Grams';

  @override
  String get priceWord => 'Price';

  @override
  String gramsEquals(String kg) {
    return '= $kg kg';
  }

  @override
  String get weightHintKg => 'Up to 3 decimals (1 g). Example: 0.750';

  @override
  String get weightHintGram => 'In grams, whole numbers only';

  @override
  String get weightErrorZero => 'Enter a weight above zero';

  @override
  String get weightErrorTooBig => 'The weight is above the allowed maximum';

  @override
  String get weightCtaEmpty => 'Enter the weight to add';

  @override
  String weightCtaAdd(String kg) {
    return 'Add $kg kg ·';
  }

  @override
  String weightCtaUpdate(String kg) {
    return 'Update · $kg kg ·';
  }

  @override
  String get removeFromCart => 'Remove from the cart';

  @override
  String get keyBackspace => 'Delete the last digit';

  @override
  String get keyDecimal => 'Decimal point';

  @override
  String get productSearchTitle => 'Find a product';

  @override
  String get productSearchHint => 'Search by product name or barcode';

  @override
  String get productSearchEmpty => 'No product with this name';

  @override
  String get productSearchEmptyBody =>
      'Check the spelling. Products are added from the web admin.';

  @override
  String get productSearchError => 'Couldn\'t load the products';

  @override
  String get listErrorBody =>
      'Check the connection. The current sale is kept as it is.';

  @override
  String get checkoutTitle => 'Checkout';

  @override
  String get checkoutNotCreatedYet => 'The invoice isn\'t created yet';

  @override
  String get backToCart => 'Back to the cart';

  @override
  String get showItems => 'Show items';

  @override
  String get hideItems => 'Hide items';

  @override
  String get editCart => 'Edit the cart';

  @override
  String get saleModeLabel => 'Sale type';

  @override
  String get modeCash => 'Full cash';

  @override
  String get modePartial => 'Partial';

  @override
  String get modeCredit => 'Credit';

  @override
  String get paidNowLabel => 'Amount paid now';

  @override
  String paidHint(String total) {
    return 'Above zero and below the total $total';
  }

  @override
  String get paidErrorInvalid =>
      'Enter an amount above zero, with at most 2 decimals.';

  @override
  String get paidErrorNotBelowTotal =>
      'The amount equals or exceeds the total. Choose «Full cash» instead of «Partial».';

  @override
  String get paymentMethodLabel => 'Payment method';

  @override
  String get methodCash => 'Cash';

  @override
  String get methodJawwalPay => 'Jawwal Pay';

  @override
  String get methodPalPay => 'PalPay';

  @override
  String get methodBankOfPalestine => 'Bank of Palestine';

  @override
  String get methodNone => 'Nothing';

  @override
  String get customerLabel => 'Customer';

  @override
  String get optionalWord => 'Optional';

  @override
  String get requiredWord => 'Required';

  @override
  String get balanceWord => 'Balance';

  @override
  String get limitWord => 'Limit';

  @override
  String get noLimitLong => 'No credit limit';

  @override
  String get noLimitShort => 'No limit';

  @override
  String get changeWord => 'Change';

  @override
  String get pickCustomer => 'Choose the customer';

  @override
  String get addCustomerToInvoice => 'Add a customer to the invoice';

  @override
  String get customerRequiredPartial =>
      'Choose the customer: a partial sale is recorded as their debt';

  @override
  String get customerRequiredCredit =>
      'Choose the customer: a credit sale is recorded in their name';

  @override
  String get dueLabel => 'Due date';

  @override
  String get optionalParen => '(optional)';

  @override
  String get dueNone => 'No date';

  @override
  String get dueWeek => 'In 7 days';

  @override
  String get dueMonth => 'In 30 days';

  @override
  String get dueOn => 'Due:';

  @override
  String get negativeStockTitle => 'Stock warning: you can continue';

  @override
  String negativeStockRow(String stock, String quantity) {
    return 'Recorded $stock · sold $quantity';
  }

  @override
  String get negativeStockBody =>
      'The quantity is above the recorded stock. The sale goes through, the stock turns negative and the owner sees it in the stock review list.';

  @override
  String get limitBlockedTitle =>
      'Over the credit limit: you can\'t complete the sale';

  @override
  String limitBalanceNowOf(String name) {
    return '$name\'s balance now';
  }

  @override
  String get limitThisSaleDebt => 'Debt from this sale';

  @override
  String get limitCeiling => 'Credit limit';

  @override
  String get limitOverBy => 'Over the limit by';

  @override
  String limitServerBody(String name) {
    return 'The server refused the sale: $name\'s balance changed since the list loaded and the new debt is now over the limit. No invoice was created.';
  }

  @override
  String get limitBlockedHelp =>
      'Increase the amount paid so the debt stays within the limit, or ask the owner or a manager to complete the sale from their account.';

  @override
  String limitWarnTitle(String name) {
    return '$name\'s balance will go over the credit limit';
  }

  @override
  String limitWarnBody(String after, String limit, String over) {
    return 'Balance after the sale $after, limit $limit (over by $over).';
  }

  @override
  String get limitWarnHelp =>
      'You may override it. You\'ll be asked to confirm, and the override is recorded in your name.';

  @override
  String get submitOfflineTitle => 'No connection: the sale wasn\'t sent';

  @override
  String get submitOfflineBody =>
      'The request didn\'t reach the server. Check the internet, then try again. The sale won\'t be recorded twice.';

  @override
  String get submitUncertainTitle =>
      'Connection lost while saving: the result is uncertain';

  @override
  String get submitUncertainBody =>
      'The sale may or may not be recorded. Try again to check: the same request is sent with the same key, so the sale is never doubled. Editing is locked until it\'s confirmed.';

  @override
  String get submitServerTitle => 'Server error: the sale wasn\'t recorded';

  @override
  String get submitServerBody =>
      'Try again shortly. If it happens again, give the reference code to support.';

  @override
  String get submitRejectedTitle => 'The sale wasn\'t recorded';

  @override
  String get paidWord => 'Paid';

  @override
  String get remainingWord => 'Remaining';

  @override
  String get statusPaidFull => 'Paid in full';

  @override
  String get statusPartialDebt => 'Partial: the rest is debt';

  @override
  String get statusFullDebt => 'Full debt';

  @override
  String get barLimitBlocked =>
      'Can\'t continue: the debt is over the customer\'s limit';

  @override
  String get barPaidFull => 'Paid in full: no debt';

  @override
  String barDebtOn(String amount, String name) {
    return 'A debt of $amount will be recorded on $name';
  }

  @override
  String barDebtNoCustomer(String amount) {
    return '$amount stays as debt: choose the customer';
  }

  @override
  String get confirmSale => 'Confirm sale ·';

  @override
  String get savingSale => 'Saving the sale…';

  @override
  String get savingShort => 'Saving…';

  @override
  String get verifyAndRetry => 'Check and try again';

  @override
  String get continueOverLimit => 'Continue over the limit…';

  @override
  String get retrySale => 'Try again ·';

  @override
  String get overrideTitle => 'Confirm the credit-limit override';

  @override
  String get overrideBalanceNow => 'Current balance';

  @override
  String get overrideBalanceAfter => 'Balance after the sale';

  @override
  String overrideNote(String name, String role) {
    return 'Confirming creates the sale and records the override in the audit log under $name ($role). Closing this sheet doesn\'t complete the sale.';
  }

  @override
  String get overrideForbidden =>
      'The server refused the override: your account no longer has this permission. The sale wasn\'t recorded.';

  @override
  String get overrideBack => 'Back without completing';

  @override
  String get overrideConfirm => 'Approve the override and confirm the sale';

  @override
  String get pickerTitle => 'Choose the customer';

  @override
  String get pickerCancel => 'Cancel';

  @override
  String get pickerSearchHint => 'Search by name or phone number';

  @override
  String get pickerNeedsCustomer =>
      'A partial or credit sale needs a customer to record the debt against.';

  @override
  String get pickerLoading => 'Loading customers';

  @override
  String get pickerEmpty => 'No customer with this name or number';

  @override
  String get pickerEmptyBody =>
      'Check the spelling, or add them as a new customer.';

  @override
  String pickerAddNamed(String name) {
    return 'Add «$name» as a new customer';
  }

  @override
  String get pickerNewCustomer => 'New customer';

  @override
  String get pickerError => 'Couldn\'t load the customers';

  @override
  String get pickerErrorBody =>
      'Check the connection. The current sale is kept as it is.';

  @override
  String get pickerSkip => 'Continue without a customer';

  @override
  String get owesWord => 'Owes';

  @override
  String get noDebtWord => 'No debt';

  @override
  String get newCustomerTitle => 'New customer';

  @override
  String get newCustomerName => 'Customer name';

  @override
  String get newCustomerPhone => 'Phone number';

  @override
  String get newCustomerPhoneHint => 'The customer\'s mobile, 10 digits';

  @override
  String get newCustomerNameRequired => 'Enter the customer\'s name';

  @override
  String get newCustomerPhoneInvalid =>
      'The phone number has 10 digits and starts with 0';

  @override
  String get newCustomerSave => 'Save and choose the customer';

  @override
  String get newCustomerBack => 'Back to search';

  @override
  String get receiptDoneTitle => 'Sale complete';

  @override
  String get receiptPaidWord => 'Paid';

  @override
  String get receiptPaidTail => 'in full';

  @override
  String get receiptDebtWord => 'Debt recorded:';

  @override
  String receiptDebtTail(String name) {
    return 'on $name';
  }

  @override
  String get receiptVoidedTitle => 'Invoice voided';

  @override
  String get receiptInvoiceWord => 'Invoice';

  @override
  String get receiptVoidedTail => 'is kept in the records as «voided»';

  @override
  String get receiptNumber => 'Invoice number';

  @override
  String get receiptDate => 'Date';

  @override
  String get receiptSeller => 'Seller';

  @override
  String get remainingAsDebt => 'Remaining as debt';

  @override
  String get voidedStamp => 'Voided';

  @override
  String receiptNegativeNote(String names) {
    return '«$names» went below zero stock and was added to the owner\'s stock review list.';
  }

  @override
  String receiptOverrideNote(String customer, String user) {
    return '$customer\'s credit limit was overridden with $user\'s approval. The override is in the audit log.';
  }

  @override
  String get receiptReplayNote =>
      'Checked with the server: the sale is recorded only once despite the lost connection.';

  @override
  String receiptVoidedBy(String name, String time) {
    return 'Voided by $name · $time';
  }

  @override
  String receiptVoidReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get receiptVoidEffect =>
      'The stock was returned and the linked debt cancelled. The invoice stays in the records as «voided».';

  @override
  String get newSale => 'New sale';

  @override
  String get voidInvoiceEllipsis => 'Void the invoice…';

  @override
  String voidTitle(int id) {
    return 'Void invoice #$id';
  }

  @override
  String get voidEffectsTitle => 'Voiding will:';

  @override
  String get voidEffectStock => 'Return the items\' quantities to stock.';

  @override
  String voidEffectDebt(String amount, String name) {
    return 'Cancel the linked debt of $amount on $name.';
  }

  @override
  String get voidEffectKept =>
      'Keep the invoice in the records as «voided»; it isn\'t deleted.';

  @override
  String get voidEffectFinal => 'A void can\'t be undone.';

  @override
  String get voidReasonLabel => 'Reason for the void (required)';

  @override
  String get voidReasonRequired =>
      'Write the reason: it\'s saved in the audit log';

  @override
  String get voidBlocked =>
      'This invoice can\'t be voided: it has later payments or returns. Use «Return» from sales management on the web.';

  @override
  String get voidForbidden =>
      'You can\'t void invoices. Only the owner or a manager can.';

  @override
  String get voidNetwork =>
      'No connection: the invoice wasn\'t voided. Try again.';

  @override
  String get voiding => 'Voiding…';

  @override
  String get voidConfirm => 'Void the invoice permanently';

  @override
  String get custSearchHint => 'Search by name or phone';

  @override
  String get custAdd => '+ Customer';

  @override
  String get custSearchMin => 'Type 2 or more characters to search.';

  @override
  String get custEmptyTitle => 'No customers yet';

  @override
  String get custEmptyBody =>
      'Add the customers who buy on credit. A cash sale needs no customer.';

  @override
  String custNoResults(String query) {
    return 'No customer named “$query”';
  }

  @override
  String get custNoResultsBody => 'Add them now with a name and phone.';

  @override
  String custAddNamed(String name) {
    return 'Add “$name”';
  }

  @override
  String get custLoadError =>
      'Couldn\'t load customers. Check the connection and try again.';

  @override
  String get custOverdue => 'Overdue';

  @override
  String get custInactive => 'Inactive';

  @override
  String get custRemaining => 'Still owed';

  @override
  String custOverdueAmount(String amount) {
    return 'Overdue $amount';
  }

  @override
  String custLimit(String amount) {
    return 'Credit limit $amount';
  }

  @override
  String get custNoLimit => 'No credit limit';

  @override
  String get custRecordPayment => 'Record payment';

  @override
  String custCall(String phone) {
    return 'Call $phone';
  }

  @override
  String get custOpenDebts => 'Open debts';

  @override
  String get custNoOpenDebts => 'This customer has no open debts.';

  @override
  String get custRecentPayments => 'Latest payments';

  @override
  String get custNoPayments => 'No payments yet.';

  @override
  String custDebtSale(int id) {
    return 'Invoice #$id';
  }

  @override
  String get custDebtOpening => 'Old debt';

  @override
  String custDue(String date) {
    return 'Due $date';
  }

  @override
  String get custNoDue => 'No due date';

  @override
  String get custStatusOpen => 'Open';

  @override
  String get custReversed => 'Reversed';

  @override
  String get custDetailError => 'Couldn\'t load this customer.';

  @override
  String get custInactiveNote =>
      'This customer is inactive: hidden from new sales, payments are still accepted.';

  @override
  String payTitle(String name) {
    return 'Payment from $name';
  }

  @override
  String get payAmount => 'Amount';

  @override
  String get payFull => 'Full balance';

  @override
  String get payOther => 'Other amount';

  @override
  String payRemainingNote(String amount) {
    return 'Owed $amount · up to 2 decimals';
  }

  @override
  String get payMethod => 'Payment method';

  @override
  String get payNow => 'Owed now';

  @override
  String get payThis => 'This payment';

  @override
  String get payAfter => 'After payment';

  @override
  String get payOldestFirst => 'Applied to the oldest due debts first.';

  @override
  String payConfirm(String amount) {
    return 'Confirm receiving $amount';
  }

  @override
  String get paySaving => 'Recording payment…';

  @override
  String get payRetry => 'Try again';

  @override
  String get payUncertain =>
      'The server didn\'t answer, so we don\'t know if the payment was saved. Tap “Try again”: it is sent with the same key and can\'t be recorded twice.';

  @override
  String get payInvalid => 'Enter a valid amount with at most 2 decimals.';

  @override
  String payTooMuch(String amount) {
    return 'That is more than is owed ($amount).';
  }

  @override
  String get payNothing => 'This customer owes nothing.';

  @override
  String payDone(String amount) {
    return 'Received $amount';
  }

  @override
  String payDoneRemaining(String name, String amount) {
    return '$name now owes $amount';
  }

  @override
  String get payDoneButton => 'Done';

  @override
  String get prodSearchHint => 'Search by name or barcode';

  @override
  String get prodAdd => '+ Product';

  @override
  String get prodFilterAll => 'All';

  @override
  String get prodFilterLow => 'Low';

  @override
  String get prodFilterNegative => 'Negative';

  @override
  String get prodEmptyTitle => 'No products yet';

  @override
  String get prodEmptyBody =>
      'Scan a product\'s code to add it quickly, or import your list on the web.';

  @override
  String get prodNoResults => 'No products match this search.';

  @override
  String get prodLoadError => 'Couldn\'t load products.';

  @override
  String get prodStockOk => 'In stock';

  @override
  String get prodStockLow => 'Low';

  @override
  String get prodStockOut => 'Out';

  @override
  String get prodStockNegative => 'Negative';

  @override
  String get prodPerPiece => 'piece';

  @override
  String get prodPerKg => 'kg';

  @override
  String get addTitle => 'Add product';

  @override
  String get addScan => 'Scan a QR code or barcode';

  @override
  String get addScanSub => 'We read what the code holds and fill the form';

  @override
  String get addManual => 'Enter manually';

  @override
  String get addManualSub => 'For products without a code, like weighed goods';

  @override
  String get addChecking => 'Checking the code…';

  @override
  String get addExistsTitle => 'Product already exists';

  @override
  String addExistsBody(String code) {
    return 'Barcode $code is already in your store. It won\'t be added twice.';
  }

  @override
  String get addScanAnother => 'Scan another code';

  @override
  String get addFromCode => 'From code';

  @override
  String get addBarcodeOnly =>
      'The code holds only the barcode. Add the name and price.';

  @override
  String addReadFields(String fields) {
    return 'Read from the code: $fields. Check them before saving.';
  }

  @override
  String get addFieldName => 'name';

  @override
  String get addFieldBarcode => 'barcode';

  @override
  String get addFieldPrice => 'price';

  @override
  String get addFieldUnit => 'unit';

  @override
  String get addUnreadable =>
      'This code holds no product data. Enter the product manually; its content won\'t be used.';

  @override
  String get addManualNote =>
      'Manual entry. Name and selling price are required.';

  @override
  String get addLookupFailed =>
      'Couldn\'t check for an existing product now; it is checked again on save.';

  @override
  String get addFromCatalog =>
      'Hisbah already knows this product, so its name and unit are filled in. Enter your store\'s selling price, cost and quantity.';

  @override
  String get formNewTitle => 'New product';

  @override
  String get formName => 'Product name';

  @override
  String get formNameHint => 'e.g. Medjool dates 1 kg';

  @override
  String get formBarcode => 'Barcode';

  @override
  String get formOptional => 'Optional';

  @override
  String get formSoldBy => 'Sold';

  @override
  String get formByPiece => 'By the piece';

  @override
  String get formByKg => 'By weight (kg)';

  @override
  String get formPrice => 'Price to the customer (selling price)';

  @override
  String get formCost => 'What it costs you (purchase price)';

  @override
  String get formStock => 'Stock now';

  @override
  String get formMin => 'Alert me when stock reaches';

  @override
  String get formNameRequired => 'Enter the product name.';

  @override
  String get formPriceInvalid => 'Enter a valid price.';

  @override
  String get formStockPiece => 'Whole number for a piece product.';

  @override
  String get formStockKg => 'Up to 3 decimals.';

  @override
  String get formSave => 'Save product';

  @override
  String get formSaving => 'Saving…';

  @override
  String get formNetwork =>
      'Couldn\'t save: no connection. Your entries are kept; try again.';

  @override
  String get formForbidden =>
      'Only an owner or manager can add products. Ask the owner to add it.';

  @override
  String get formFailed => 'Couldn\'t save. Please try again.';

  @override
  String savedTitle(String name) {
    return '“$name” added';
  }

  @override
  String get savedScanNext => 'Scan another product';

  @override
  String get savedBack => 'Back to products';

  @override
  String get homeAttention => 'Needs your attention';

  @override
  String homeOverdueAlert(int count) {
    return 'Overdue debts: $count';
  }

  @override
  String homeDueTodayAlert(int count) {
    return 'Due today: $count';
  }

  @override
  String homeLowStockAlert(int count) {
    return 'Products below minimum: $count';
  }

  @override
  String homeNegativeAlert(int count) {
    return 'Negative stock to review: $count';
  }

  @override
  String get homeAllClear => 'Nothing needs your attention right now.';

  @override
  String get homeCollections => 'Collections';

  @override
  String homeCollectionsSplit(String atSale, String repayments) {
    return 'At sale $atSale · debts $repayments';
  }

  @override
  String get loginNoAccount => 'No account yet?';

  @override
  String get loginCreateStore => 'Create a new store';

  @override
  String get storeSuspended =>
      'This store\'s account is suspended. Contact Hisbah to reactivate it.';

  @override
  String get registerTitle => 'Create a new store';

  @override
  String get registerHelper => 'Three steps, then a free 7-day trial.';

  @override
  String registerStepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get registerStepStore => 'Store';

  @override
  String get registerStepStoreSub =>
      'Start with your store\'s name and its owner.';

  @override
  String get registerStepContact => 'Location and contact';

  @override
  String get registerStepContactSub =>
      'The phone and address appear on the customer\'s receipt.';

  @override
  String get registerStepAccount => 'Sign-in details';

  @override
  String get registerStepAccountSub =>
      'Choose the email and password you sign in to Hisbah with.';

  @override
  String get storeNameLabel => 'Store name';

  @override
  String get ownerNameLabel => 'Owner\'s name';

  @override
  String get storePhoneLabel => 'Phone number';

  @override
  String get cityLabel => 'City';

  @override
  String get cityHint => 'Choose the city';

  @override
  String get streetLabel => 'Address (street and area)';

  @override
  String get passwordConfirmLabel => 'Confirm password';

  @override
  String get passwordMinHint => 'A sign-in password, at least 8 characters';

  @override
  String get storeNameRequired => 'Enter the store name.';

  @override
  String get ownerNameRequired => 'Enter the owner\'s name.';

  @override
  String get phoneRequired => 'Enter the phone number.';

  @override
  String get phoneInvalid =>
      'The phone number has 9 or 10 digits, e.g. 0599123456.';

  @override
  String get cityRequired => 'Choose the city.';

  @override
  String get streetRequired => 'Enter the store\'s address.';

  @override
  String get registerEmailRequired => 'Enter the email address.';

  @override
  String get registerEmailInvalid => 'The email address is not valid.';

  @override
  String get passwordTooShort => 'The password needs at least 8 characters.';

  @override
  String get passwordMismatch =>
      'The confirmation does not match the password.';

  @override
  String get emailTaken =>
      'This email is already registered. Sign in, or use another email.';

  @override
  String get registerFailedTaken =>
      'The store was not created: the email is in use.';

  @override
  String get registerFailedValidation =>
      'The store was not created. Check the marked fields.';

  @override
  String get registerNetworkError =>
      'Could not reach the server. Your details are still in the form; try again.';

  @override
  String get registerServerError =>
      'A server error stopped the store from being created. Try again shortly.';

  @override
  String get registerNext => 'Next';

  @override
  String get registerBack => 'Back';

  @override
  String get registerSubmit => 'Create the store';

  @override
  String get registerSubmitting => 'Creating the store…';

  @override
  String get registerHaveAccount => 'Already have an account?';

  @override
  String get registerSignIn => 'Sign in';

  @override
  String get subscriptionTrialEndedTitle => 'Your free trial has ended';

  @override
  String get subscriptionPaidEndedTitle =>
      'Your store\'s subscription has ended';

  @override
  String subscriptionEndedOn(String store, String date) {
    return '«$store», ended on $date';
  }

  @override
  String get subscriptionDataSafe =>
      'Your data is kept as it is: customers, debts, sales and products. Everything is back as soon as the subscription is activated.';

  @override
  String get subscriptionContactWhatsapp => 'Contact us on WhatsApp';

  @override
  String get subscriptionContactNoNumber =>
      'Contact Hisbah to activate the subscription.';

  @override
  String subscriptionWhatsappMessage(String store, String email) {
    return 'Hello, I would like to activate the subscription of «$store» on Hisbah.\nEmail: $email';
  }

  @override
  String subscriptionWhatsappFailed(String number) {
    return 'Could not open WhatsApp. Support number: $number';
  }

  @override
  String get subscriptionCheckAgain => 'Check again';

  @override
  String get subscriptionChecking => 'Checking…';

  @override
  String get subscriptionStillInactive =>
      'The subscription is not active yet. Once Hisbah confirms the payment, tap «Check again».';

  @override
  String get saleScanTitle => 'Scan products to sell';

  @override
  String get saleScanKeepGoing => 'Camera on: scan the next product';

  @override
  String get saleScanCloseA11y => 'Close the camera and go back to the cart';

  @override
  String get cartPanelTitle => 'Cart';

  @override
  String get saleScanEmptyBody =>
      'Point the camera at a product\'s barcode. It stays open so you can add products one after another.';

  @override
  String get completeSale => 'Complete sale';

  @override
  String methodRecordOnly(String method) {
    return 'This only records that the customer paid by $method. Hisbah is not connected to this service and does not check that the money arrived, so confirm it before completing the sale.';
  }

  @override
  String get invTitle => 'Add products by scanning';

  @override
  String get invInstruction =>
      'Scan a product\'s barcode to add it to your store. It never goes into the sale cart.';

  @override
  String get invWaiting => 'Finish or close the form to scan the next product';

  @override
  String get invCloseA11y => 'Close the camera and go back to products';

  @override
  String get invBackToScanning => 'Close and go back to scanning';

  @override
  String invStockNow(String stock) {
    return 'In stock now $stock';
  }

  @override
  String get invExistsNote =>
      'This product is already in your store, so it will not be added again. To record new goods for it, choose «Add quantity».';

  @override
  String get invAddStock => 'Add quantity';

  @override
  String invAddStockQty(String unit) {
    return 'Quantity received ($unit)';
  }

  @override
  String get invReason => 'Reason';

  @override
  String get invReasonDefault => 'Goods received';

  @override
  String get invReasonRequired => 'Write why the quantity is added.';

  @override
  String get invQtyPiece => 'Enter a whole number above zero.';

  @override
  String get invQtyKg => 'Enter a weight above zero, up to 3 decimals.';

  @override
  String get invAddStockSave => 'Add to stock';

  @override
  String invStockAdded(String name, String stock) {
    return 'Quantity added to «$name». In stock now $stock';
  }

  @override
  String get invStockForbidden =>
      'Only the owner or a manager can change stock.';

  @override
  String invOpeningStock(String unit) {
    return 'Quantity on hand now ($unit)';
  }

  @override
  String get invNetworkUncertain =>
      'The connection dropped before the server answered, so the save may have gone through. Your entries are kept; tap «Retry» and we will check without adding the product twice.';

  @override
  String get invFromCatalog =>
      'Known in Hisbah: name and unit are filled in. Add your store\'s prices and quantity.';

  @override
  String get packWord => 'carton';

  @override
  String unitChipPack(int size) {
    return 'Carton ×$size';
  }

  @override
  String packPer(int size) {
    return 'carton ($size pieces)';
  }

  @override
  String packEquals(String pieces) {
    return '= $pieces pieces';
  }

  @override
  String addPackLine(int size, String price) {
    return '+ carton ($size pieces) for $price';
  }

  @override
  String get packToggle => 'Also sold by the carton (wholesale)';

  @override
  String get packToggleSub =>
      'Stock stays in pieces; selling a carton takes all its pieces.';

  @override
  String get packSizeLabel => 'Pieces per carton';

  @override
  String get packPriceLabel => 'Price of a whole carton';

  @override
  String get packSizeInvalid => 'A whole number from 2 to 10000.';

  @override
  String get packPriceNotAbovePiece =>
      'The carton price must be higher than one piece. Did you type the piece price here?';

  @override
  String packPerPiece(String price) {
    return 'One piece inside the carton costs $price.';
  }

  @override
  String packPerPieceVs(String pack, String piece) {
    return 'One piece inside the carton costs $pack, against $piece on its own.';
  }

  @override
  String get invQtyPack => 'Enter a whole number of cartons above zero.';

  @override
  String get formPriceHelpPiece => 'What the customer pays for one piece.';

  @override
  String get formPriceHelpKg => 'What the customer pays for one kg.';

  @override
  String get formCostHelp =>
      'What you pay the supplier; customers never see it';

  @override
  String get formMinHelp => 'At this number or less it shows as low';

  @override
  String get formRequiredA11y => 'required';

  @override
  String get formFixErrors => 'Check the fields marked in red.';

  @override
  String get subscriptionHowTo =>
      'Once you pay, the Hisbah team activates your subscription; then tap Check again to return to your store.';

  @override
  String get subscriptionDetails =>
      'Mention these details when you get in touch:';

  @override
  String subscriptionStoreLine(String store) {
    return 'Store: $store';
  }

  @override
  String subscriptionEmailLine(String email) {
    return 'Email: $email';
  }

  @override
  String get subscriptionCopy => 'Copy details';

  @override
  String get subscriptionCopied => 'Details copied.';

  @override
  String get discardTitle => 'Discard what you typed?';

  @override
  String get discardBody =>
      'This product is not saved yet. Leaving now loses what you entered.';

  @override
  String get discardKeep => 'Keep editing';

  @override
  String get discardConfirm => 'Discard and leave';

  @override
  String get saleDetailError =>
      'Could not load the invoice. Check the connection and try again.';

  @override
  String saleReturnedNote(String amount) {
    return 'Goods worth $amount were returned from this invoice.';
  }

  @override
  String get moreSectionStore => 'Store';

  @override
  String get moreStaff => 'Staff';

  @override
  String get moreStaffSub => 'Invite, change roles, deactivate';

  @override
  String get moreStoreInfo => 'Store details';

  @override
  String get moreStoreInfoSub => 'Name, phone and address on receipts';

  @override
  String get moreSectionStock => 'Stock';

  @override
  String get moreLowStock => 'Running low';

  @override
  String get moreLowStockSub => 'At or below their alert level';

  @override
  String get moreNegative => 'Negative stock to review';

  @override
  String get moreNegativeSub => 'Sold beyond the recorded quantity';

  @override
  String get moreSectionSales => 'Sales';

  @override
  String get moreSalesHistory => 'Sales history';

  @override
  String get moreSalesHistorySub => 'Every invoice, each one in full';

  @override
  String get moreSectionSettings => 'Settings';

  @override
  String get morePassword => 'Change password';

  @override
  String get morePasswordSub => 'Other devices are signed out';

  @override
  String get moreSubscription => 'Subscription';

  @override
  String moreSubTrialUntil(String date) {
    return 'Free trial until $date';
  }

  @override
  String moreSubActiveUntil(String date) {
    return 'Active until $date';
  }

  @override
  String get moreSubActive => 'Active';

  @override
  String get moreSubContact => 'Contact the Hisbah team on WhatsApp';

  @override
  String moreSubWhatsappText(String store) {
    return 'Hello, about the Hisbah subscription of «$store».';
  }

  @override
  String get staffTitle => 'Staff';

  @override
  String get staffInvite => 'Invite staff';

  @override
  String get staffEmpty =>
      'No staff yet. Invite the first one with a link they open on their phone.';

  @override
  String get staffYou => 'You';

  @override
  String get staffInactive => 'Deactivated';

  @override
  String get staffMakeManager => 'Make manager';

  @override
  String get staffMakeEmployee => 'Make employee';

  @override
  String get staffDeactivate => 'Deactivate';

  @override
  String staffDeactivateTitle(String name) {
    return 'Deactivate $name?';
  }

  @override
  String get staffDeactivateBody =>
      'They are signed out everywhere at once and cannot sign in. Their sales and payments stay in their name.';

  @override
  String get staffRolesNote =>
      'Manager: everything except staff and store details. Employee: sales, customers and payments; no returns, voids, stock changes or credit-limit overrides.';

  @override
  String get staffLoadError =>
      'Could not load the staff. Check the connection and try again.';

  @override
  String get staffActionError =>
      'That did not go through. Check the connection and try again.';

  @override
  String get staffOwnerOnly => 'Only the owner manages staff.';

  @override
  String staffRoleChanged(String name, String role) {
    return '$name is now $role.';
  }

  @override
  String staffDeactivated(String name) {
    return '$name was deactivated.';
  }

  @override
  String get inviteRole => 'Role';

  @override
  String get inviteValid => 'Link valid for';

  @override
  String get invite24h => '24 hours';

  @override
  String get invite3d => '3 days';

  @override
  String get invite7d => '7 days';

  @override
  String get inviteEmail => 'Their email';

  @override
  String get inviteEmailHint => 'If typed, the link only works with this email';

  @override
  String get inviteCreate => 'Create invite link';

  @override
  String get inviteCreating => 'Creating…';

  @override
  String get inviteReady =>
      'The invite is ready. Send the link to your staff member; it is shown here only once.';

  @override
  String inviteExpires(String date) {
    return 'Expires $date';
  }

  @override
  String get inviteHowTo =>
      'They open the link, enter their name, email and a password, then sign in to the Hisbah app.';

  @override
  String get inviteCopy => 'Copy link';

  @override
  String get inviteCopied => 'Link copied.';

  @override
  String get inviteWhatsapp => 'Send on WhatsApp';

  @override
  String inviteWhatsappText(String store, String role, String link) {
    return 'You are invited to join «$store» on Hisbah as $role. Open the link to create your account:\n$link';
  }

  @override
  String get inviteWhatsappFailed =>
      'Could not open WhatsApp. Copy the link and send it any way you like.';

  @override
  String get inviteDone => 'Done';

  @override
  String get storeTitle => 'Store details';

  @override
  String get storeName => 'Store name';

  @override
  String get storePhone => 'Store phone';

  @override
  String get storePhoneHint => 'Shop phone on the receipt, e.g. 0599123456';

  @override
  String get storeAddress => 'Address';

  @override
  String get storeArea => 'Area or city';

  @override
  String get storeReceiptNote =>
      'These details are printed at the top of every receipt.';

  @override
  String get storeSave => 'Save changes';

  @override
  String get storeSaved => 'Store details saved.';

  @override
  String get storeOwnerOnly => 'Only the owner edits the store details.';

  @override
  String get storeLoadError =>
      'Could not load the store details. Check the connection and try again.';

  @override
  String get pwTitle => 'Change password';

  @override
  String get pwCurrent => 'Current password';

  @override
  String get pwNew => 'New password';

  @override
  String get pwConfirm => 'Confirm the new password';

  @override
  String get pwHelp => 'At least 8 characters; other devices are signed out';

  @override
  String get pwSave => 'Change password';

  @override
  String get pwDone => 'Password changed; other devices were signed out.';

  @override
  String get pwCurrentRequired => 'Enter your current password.';

  @override
  String get pwShort => 'At least 8 characters.';

  @override
  String get pwMismatch => 'The confirmation does not match.';

  @override
  String get salesTitle => 'Sales history';

  @override
  String get salesToday => 'Today';

  @override
  String get sales7 => 'Last 7 days';

  @override
  String get sales30 => 'Last 30 days';

  @override
  String get salesAll => 'All';

  @override
  String get salesEmpty => 'No sales in this period.';

  @override
  String get salesLoadError =>
      'Could not load the sales. Check the connection and try again.';

  @override
  String get salesMore => 'Show more';

  @override
  String get salesMoreError => 'Could not load more. Tap to try again.';

  @override
  String get salesWalkIn => 'Walk-in';

  @override
  String salesItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get saleStatusPaid => 'Paid';

  @override
  String get saleStatusCredit => 'On credit';

  @override
  String get saleStatusPartial => 'Part paid';

  @override
  String get prodDetailError =>
      'Could not load the product. Check the connection and try again.';

  @override
  String get prodStockNowLabel => 'In stock';

  @override
  String prodMinimumLabel(String qty) {
    return 'Alert at $qty';
  }

  @override
  String prodCostLabel(String price) {
    return 'Cost $price';
  }

  @override
  String prodPackLabel(int size, String price) {
    return 'Carton of $size for $price';
  }

  @override
  String get prodEdit => 'Edit product';

  @override
  String get prodAdjust => 'Count or adjust stock';

  @override
  String get prodMovements => 'Stock movements';

  @override
  String get prodNoMovements => 'No movements yet.';

  @override
  String get prodDeactivate => 'Deactivate product';

  @override
  String prodDeactivateTitle(String name) {
    return 'Deactivate «$name»?';
  }

  @override
  String get prodDeactivateBody =>
      'It leaves the till and the product list. Its movements and past sales stay on record, and you can bring it back any time from «Stopped».';

  @override
  String prodDeactivated(String name) {
    return '«$name» was deactivated.';
  }

  @override
  String get prodInactiveNote =>
      'This product is deactivated: it is not sold and not listed.';

  @override
  String get prodFilterInactive => 'Stopped';

  @override
  String get prodReactivate => 'Bring the product back';

  @override
  String get prodReactivated =>
      'The product is back on sale and in the list, as it was.';

  @override
  String get invOpenProduct => 'Edit price and details';

  @override
  String get prodSaved => 'Changes saved.';

  @override
  String get prodViewOnly =>
      'Only the owner or a manager edits products and stock.';

  @override
  String get moveOpening => 'Opening stock';

  @override
  String get moveSale => 'Sale';

  @override
  String get moveVoid => 'Voided sale';

  @override
  String get moveReturn => 'Return';

  @override
  String get moveIn => 'Adjustment in';

  @override
  String get moveOut => 'Adjustment out';

  @override
  String moveAfter(String qty) {
    return 'then $qty';
  }

  @override
  String adjTitle(String name) {
    return 'Adjust «$name»';
  }

  @override
  String get adjCount => 'Shelf count';

  @override
  String get adjDelta => 'Add or remove';

  @override
  String get adjCartons => 'Receive cartons';

  @override
  String adjCountLabel(String unit) {
    return 'How many are there now? ($unit)';
  }

  @override
  String adjDeltaLabel(String unit) {
    return 'Quantity ($unit); negative to remove';
  }

  @override
  String adjCartonsLabel(int size) {
    return 'Cartons received ($size pieces each)';
  }

  @override
  String get adjReason => 'Reason';

  @override
  String get adjReasonCount => 'Shelf count';

  @override
  String get adjReasonDamaged => 'Damaged or expired';

  @override
  String get adjReasonReceived => 'Goods received';

  @override
  String get adjReasonFix => 'Fixing an entry mistake';

  @override
  String adjPreview(String from, String to) {
    return 'Recorded $from → after $to';
  }

  @override
  String get adjNoChange => 'That matches the record; nothing to change.';

  @override
  String get adjNegative => 'An adjustment cannot make the stock negative.';

  @override
  String get adjInvalidPiece => 'A whole number for a piece product.';

  @override
  String get adjInvalidKg => 'Up to 3 decimal places.';

  @override
  String get adjSave => 'Save adjustment';

  @override
  String adjDone(String stock) {
    return 'Stock adjusted. Now $stock';
  }

  @override
  String get lowTitle => 'Running low';

  @override
  String get lowEmpty => 'Every product is above its alert level.';

  @override
  String lowRow(String stock, String min) {
    return 'Stock $stock · alert at $min';
  }

  @override
  String get negTitle => 'Negative stock to review';

  @override
  String get negEmpty => 'No products below zero.';

  @override
  String get negHelp =>
      'These were sold beyond the recorded stock. Count the shelf, then correct the stock on the product page.';

  @override
  String negSale(int id, String qty) {
    return 'Invoice #$id · $qty';
  }

  @override
  String get listLoadError =>
      'Could not load. Check the connection and try again.';

  @override
  String get legacyAction => 'Record an old debt';

  @override
  String get legacyActionSub =>
      'A customer\'s debt from before Hisbah, from your old notebook';

  @override
  String get legacyTitle => 'Record an old debt';

  @override
  String get legacyIntro =>
      'Recorded as a debt on the customer only: not a sale, no stock change, no cash.';

  @override
  String get legacyCustomer => 'Customer';

  @override
  String get legacyPickCustomer => 'Choose the customer';

  @override
  String get legacyChange => 'Change';

  @override
  String get legacyAmount => 'Amount owed';

  @override
  String get legacyAmountHint => 'e.g. 150';

  @override
  String get legacyAmountInvalid =>
      'Enter an amount above zero with at most two decimals.';

  @override
  String get legacyAmountTooBig => 'The amount is above the limit.';

  @override
  String get legacyPartlyPaid =>
      'If the customer already paid part of it, enter only what is left.';

  @override
  String get legacyOrigin => 'Debt date';

  @override
  String get legacyOriginNone => 'Not set';

  @override
  String get legacyDue => 'Due date (optional)';

  @override
  String get legacyDueNone => 'No due date';

  @override
  String get legacyNote => 'Note (optional)';

  @override
  String get legacyNoteHint => 'e.g. from the old debt notebook';

  @override
  String get legacyClear => 'Clear';

  @override
  String get legacySave => 'Record the debt';

  @override
  String get legacySaving => 'Recording…';

  @override
  String get legacyRetry => 'Try again';

  @override
  String get legacyUncertain =>
      'The connection dropped before the server answered; the debt may be recorded. Tap «Try again»: it will not be recorded twice.';

  @override
  String get legacyConfirmTitle => 'Confirm the old debt';

  @override
  String legacyConfirmBody(String name, String amount) {
    return 'An old debt of $amount will be recorded on $name. You can edit or delete it later on the web.';
  }

  @override
  String get legacyConfirmOk => 'Yes, record it';

  @override
  String get legacyBack => 'Back';

  @override
  String get legacyDone => 'Old debt recorded';

  @override
  String legacyDoneBody(String name, String amount) {
    return '$name now has an old debt of $amount.';
  }

  @override
  String get legacyDoneButton => 'Done';

  @override
  String get legacyForbidden =>
      'Only the owner or a manager can record old debts.';

  @override
  String legacySince(String date) {
    return 'Since $date';
  }
}
