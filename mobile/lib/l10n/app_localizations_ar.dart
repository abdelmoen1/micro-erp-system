// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'حسبة';

  @override
  String get loading => 'جارٍ التحميل…';

  @override
  String get splashTagline => 'دفتر متجرك، في جيبك';

  @override
  String get splashSubline => 'المبيعات والديون والمخزون في مكان واحد';

  @override
  String get splashChecking => 'جارٍ التحقق من الجلسة';

  @override
  String get loginTitle => 'تسجيل الدخول';

  @override
  String get loginHelper => 'أدخل بيانات حسابك في المتجر';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get showPassword => 'إظهار';

  @override
  String get hidePassword => 'إخفاء';

  @override
  String get showPasswordA11y => 'إظهار كلمة المرور';

  @override
  String get hidePasswordA11y => 'إخفاء كلمة المرور';

  @override
  String get loginButton => 'تسجيل الدخول';

  @override
  String get loginSubmitting => 'جارٍ تسجيل الدخول…';

  @override
  String get emailRequired => 'أدخل البريد الإلكتروني';

  @override
  String get emailInvalid => 'صيغة البريد الإلكتروني غير صحيحة';

  @override
  String get passwordRequired => 'أدخل كلمة المرور';

  @override
  String get invalidCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get tooManyAttempts => 'محاولات كثيرة. يمكنك المحاولة بعد';

  @override
  String loginButtonWait(String time) {
    return 'انتظر $time';
  }

  @override
  String get networkError =>
      'تعذّر الاتصال بالخادم. تحقق من الإنترنت ثم أعد المحاولة.';

  @override
  String get serverError => 'حدث خطأ في الخادم. أعد المحاولة بعد قليل.';

  @override
  String serverReference(String reference) {
    return 'رمز المرجع: $reference';
  }

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get sessionExpired => 'انتهت الجلسة. سجّل الدخول للمتابعة.';

  @override
  String get accountInactive =>
      'هذا الحساب موقوف. تواصل مع مالك المتجر لإعادة تفعيله.';

  @override
  String get storeRequired =>
      'الحساب غير مرتبط بمتجر. تواصل مع الدعم لربط حسابك بمتجر.';

  @override
  String get forbidden => 'ليس لديك صلاحية لهذا الإجراء.';

  @override
  String get tabHome => 'الرئيسية';

  @override
  String get tabPos => 'بيع';

  @override
  String get tabCustomers => 'الزبائن';

  @override
  String get tabProducts => 'المنتجات';

  @override
  String get tabMore => 'المزيد';

  @override
  String get sellA11y => 'بيع';

  @override
  String get sellCurrentA11y => 'بيع — أنت في شاشة البيع';

  @override
  String get online => 'متصل';

  @override
  String get offline => 'غير متصل';

  @override
  String get offlineBanner => 'لا يوجد اتصال — البيع يحتاج إلى الإنترنت';

  @override
  String get placeholderHome => 'لوحة اليوم — شاشة هبوط المالك والمدير';

  @override
  String get placeholderCustomers => 'قائمة الزبائن';

  @override
  String get placeholderProducts => 'المنتجات والمخزون المنخفض';

  @override
  String get placeholderPos => 'سلة البيع — شاشة هبوط الموظف';

  @override
  String get placeholderBody =>
      'محتوى هذه الشاشة يُصمَّم في S4 (US-1508). هنا يظهر فقط إطار التطبيق: الرأس، حالة الاتصال، وشريط التنقل.';

  @override
  String get placeholderPosBody =>
      'المسح والسلة والدفع تُبنى في مرحلة لاحقة (S5). هنا يظهر فقط إطار التطبيق.';

  @override
  String get roleOwner => 'مالك';

  @override
  String get roleManager => 'مدير';

  @override
  String get roleEmployee => 'موظف';

  @override
  String get moreNote =>
      '«المزيد» يحتوي الملف الشخصي وتسجيل الخروج فقط في R1. إدارة الموظفين على الويب.';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get logoutConfirmTitle => 'تسجيل الخروج؟';

  @override
  String get logoutConfirmBody =>
      'ستحتاج إلى البريد الإلكتروني وكلمة المرور للدخول مجدداً.';

  @override
  String get stay => 'البقاء';

  @override
  String homeGreeting(String name) {
    return 'أهلاً، $name';
  }

  @override
  String get homeTodaySales => 'مبيعات اليوم';

  @override
  String homeInvoicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فاتورة',
      few: '$count فواتير',
      two: 'فاتورتان',
      one: 'فاتورة واحدة',
      zero: 'لا فواتير بعد',
    );
    return '$_temp0';
  }

  @override
  String get homeCash => 'نقدي';

  @override
  String get homeCredit => 'آجل (دين)';

  @override
  String get homeCollectedToday => 'تحصيل اليوم';

  @override
  String get homeOutstandingDebts => 'ديون مستحقة';

  @override
  String homeCustomersWithDebt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count زبون مدين',
      few: '$count زبائن مدينون',
      two: 'زبونان مدينان',
      one: 'زبون واحد مدين',
      zero: 'لا زبائن مدينون',
    );
    return '$_temp0';
  }

  @override
  String get homeShortcuts => 'اختصارات';

  @override
  String get homeNewSale => 'بيع جديد';

  @override
  String get homeRecentInvoices => 'آخر فواتير اليوم';

  @override
  String get homeNoInvoices => 'لا توجد فواتير اليوم بعد';

  @override
  String get homeNoInvoicesBody => 'ابدأ أول عملية بيع من زر «بيع» في الأسفل.';

  @override
  String get homeWalkIn => 'زبون نقدي';

  @override
  String get homeLoadError => 'تعذّر تحميل لوحة اليوم.';

  @override
  String get currencySymbol => '₪';

  @override
  String get scanEntryTitle => 'عرض بيانات منتج';

  @override
  String get scanEntryBody =>
      'الاسم والسعر والمخزون. للعرض فقط، لا يُضاف إلى بيع.';

  @override
  String get scanBarcode => 'مسح باركود';

  @override
  String get scanCloseA11y => 'إغلاق الماسح والرجوع إلى البيع';

  @override
  String get scanTorchOnA11y => 'تشغيل الإضاءة';

  @override
  String get scanTorchOffA11y => 'إطفاء الإضاءة';

  @override
  String get scanInstruction => 'وجّه الباركود داخل الإطار';

  @override
  String get scanRead => 'تمت القراءة';

  @override
  String get scanPaused => 'المسح متوقف';

  @override
  String get scanSearchingCode => 'جارٍ البحث عن باركود…';

  @override
  String get scanSearchingProduct => 'جارٍ البحث عن المنتج…';

  @override
  String get scanHintTitle => 'صعب القراءة؟';

  @override
  String get scanHintBody =>
      'قرّب الباركود ببطء، أمِل المنتج لتجنب اللمعان، وشغّل الإضاءة. أو أدخله يدويًا.';

  @override
  String get scanManual => 'إدخال الباركود يدويًا';

  @override
  String get scanFound => 'تم العثور على المنتج';

  @override
  String get scanPrice => 'سعر البيع';

  @override
  String get scanStock => 'المخزون الحالي';

  @override
  String get scanBarcodeLabel => 'الباركود';

  @override
  String get scanAnother => 'مسح منتج آخر';

  @override
  String get scanBackToSale => 'الرجوع إلى البيع';

  @override
  String get scanNotFoundTitle => 'لا يوجد منتج بهذا الباركود';

  @override
  String get scanNotFoundBody => 'تأكد من الرقم أو امسحه مرة أخرى.';

  @override
  String get scanAgain => 'مسح مرة أخرى';

  @override
  String get scanDeniedTitle => 'لا يمكن المسح بدون الكاميرا';

  @override
  String get scanDeniedBody =>
      'تحتاج حِسبة إلى الكاميرا لقراءة الباركود فقط أثناء المسح. يمكنك السماح الآن أو إدخال الرقم يدويًا.';

  @override
  String get scanAllowCamera => 'السماح بالكاميرا';

  @override
  String get scanBlockedBody =>
      'إذن الكاميرا مرفوض. فعّله من إعدادات الهاتف لقراءة الباركود، أو أدخل الرقم يدويًا.';

  @override
  String get scanBlockedPath => 'الإعدادات ← التطبيقات ← حِسبة ← الأذونات ←';

  @override
  String get scanBlockedPathCamera => 'الكاميرا';

  @override
  String get scanBlockedPathAllow => '← السماح أثناء استخدام التطبيق';

  @override
  String get scanOpenSettings => 'فتح الإعدادات';

  @override
  String get manualLabel => 'رقم الباركود';

  @override
  String get manualHint => 'الأرقام أسفل الخطوط';

  @override
  String get manualHelper => 'اكتب الأرقام كما تظهر تحت خطوط الباركود.';

  @override
  String get manualEmpty => 'أدخل رقم الباركود';

  @override
  String get manualSubmit => 'عرض المنتج';

  @override
  String get manualCancelA11y => 'إلغاء الإدخال اليدوي';

  @override
  String get lookupFailedTitle => 'تعذّر عرض المنتج';

  @override
  String get lookupSavedForRetry => 'محفوظ لإعادة المحاولة.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get backWord => 'رجوع';

  @override
  String get searchByName => 'بحث بالاسم';

  @override
  String get scanShort => 'مسح';

  @override
  String get totalWord => 'الإجمالي';

  @override
  String get payButton => 'الدفع';

  @override
  String linesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صنف',
      many: '$count صنفاً',
      few: '$count أصناف',
      two: 'صنفان',
      one: 'صنف واحد',
      zero: 'لا أصناف',
    );
    return '$_temp0';
  }

  @override
  String get scanLookingUp => 'جارٍ البحث عن المنتج…';

  @override
  String get barcodeWord => 'الباركود';

  @override
  String get scanAdded => 'أُضيف إلى السلة';

  @override
  String scanIncremented(String name) {
    return '+1 · $name';
  }

  @override
  String scanQuantityNow(String quantity) {
    return 'الكمية الآن $quantity';
  }

  @override
  String get scanAddedWeighed => 'أُضيف بالوزن';

  @override
  String get scanDuplicate => 'قراءة مكررة — لم تُضف';

  @override
  String get scanDuplicateBody =>
      'الباركود نفسه خلال 1.5 ثانية. امسح مجدداً بعد لحظة لإضافة قطعة.';

  @override
  String get scanUnknown => 'باركود غير معروف';

  @override
  String get scanUnknownBody => 'لا يوجد منتج بهذا الرقم في متجرك:';

  @override
  String get scanLookupFailed => 'تعذّر البحث عن المنتج';

  @override
  String get scanLookupFailedBody => 'تحقق من الاتصال ثم أعد المحاولة.';

  @override
  String get cartEmptyTitle => 'امسح منتجاً للبدء';

  @override
  String get cartEmptyBody =>
      'أو ابحث عنه بالاسم. المنتجات بالوزن تفتح شاشة إدخال الوزن.';

  @override
  String get unitChipPiece => 'قطعة';

  @override
  String get unitChipWeighed => 'بالوزن';

  @override
  String get pieceWord => 'قطعة';

  @override
  String get piecesWord => 'قطع';

  @override
  String get kgShort => 'كغ';

  @override
  String get gramShort => 'غ';

  @override
  String get justNew => 'جديد';

  @override
  String get justIncremented => '+1 الآن';

  @override
  String get justAddedWeighed => 'أُضيف الآن';

  @override
  String editWeightOf(String name) {
    return 'تعديل وزن $name';
  }

  @override
  String removeItem(String name) {
    return 'حذف $name';
  }

  @override
  String decreaseItem(String name) {
    return 'إنقاص $name';
  }

  @override
  String increaseItem(String name) {
    return 'زيادة $name';
  }

  @override
  String lineStockNote(String stock) {
    return 'المخزون المسجّل $stock فقط — البيع مسموح ويُسجَّل للمراجعة';
  }

  @override
  String get stockWord => 'المخزون';

  @override
  String get weightTitle => 'أدخل الوزن';

  @override
  String get weightTitleEdit => 'تعديل الوزن';

  @override
  String get perKg => 'لكل كغ';

  @override
  String get unitKilogram => 'كيلوغرام';

  @override
  String get unitGram => 'غرام';

  @override
  String get priceWord => 'السعر';

  @override
  String gramsEquals(String kg) {
    return '= $kg كغ';
  }

  @override
  String get weightHintKg => 'حتى 3 منازل عشرية (1 غ). مثال: 0.750';

  @override
  String get weightHintGram => 'بالغرام، أرقام صحيحة فقط';

  @override
  String get weightErrorZero => 'أدخل وزناً أكبر من صفر';

  @override
  String get weightErrorTooBig => 'الوزن أكبر من المسموح';

  @override
  String get weightCtaEmpty => 'أدخل الوزن للإضافة';

  @override
  String weightCtaAdd(String kg) {
    return 'إضافة $kg كغ ·';
  }

  @override
  String weightCtaUpdate(String kg) {
    return 'تحديث · $kg كغ ·';
  }

  @override
  String get removeFromCart => 'حذف من السلة';

  @override
  String get keyBackspace => 'حذف آخر رقم';

  @override
  String get keyDecimal => 'فاصلة عشرية';

  @override
  String get productSearchTitle => 'بحث عن منتج';

  @override
  String get productSearchHint => 'ابحث باسم المنتج أو الباركود';

  @override
  String get productSearchEmpty => 'لا يوجد منتج بهذا الاسم';

  @override
  String get productSearchEmptyBody =>
      'تحقق من الكتابة. المنتجات تُضاف من لوحة الإدارة على الويب.';

  @override
  String get productSearchError => 'تعذّر تحميل المنتجات';

  @override
  String get listErrorBody => 'تحقق من الاتصال. البيع الحالي محفوظ كما هو.';

  @override
  String get checkoutTitle => 'الدفع';

  @override
  String get checkoutNotCreatedYet => 'لم تُنشأ الفاتورة بعد';

  @override
  String get backToCart => 'العودة إلى السلة';

  @override
  String get showItems => 'عرض الأصناف';

  @override
  String get hideItems => 'إخفاء الأصناف';

  @override
  String get editCart => 'تعديل السلة';

  @override
  String get saleModeLabel => 'طريقة البيع';

  @override
  String get modeCash => 'كاش كامل';

  @override
  String get modePartial => 'جزئي';

  @override
  String get modeCredit => 'دين';

  @override
  String get paidNowLabel => 'المبلغ المدفوع الآن';

  @override
  String paidHint(String total) {
    return 'أكبر من صفر وأقل من الإجمالي $total';
  }

  @override
  String get paidErrorInvalid =>
      'أدخل مبلغاً أكبر من صفر، بخانتين عشريتين كحد أقصى.';

  @override
  String get paidErrorNotBelowTotal =>
      'المدفوع يساوي الإجمالي أو يزيد عليه. اختر «كاش كامل» بدلاً من «جزئي».';

  @override
  String get paymentMethodLabel => 'وسيلة الدفع';

  @override
  String get methodCash => 'نقداً';

  @override
  String get methodJawwalPay => 'جوال باي';

  @override
  String get methodPalPay => 'بال باي';

  @override
  String get methodBankOfPalestine => 'بنك فلسطين';

  @override
  String get methodNone => 'لا شيء';

  @override
  String get customerLabel => 'الزبون';

  @override
  String get optionalWord => 'اختياري';

  @override
  String get requiredWord => 'مطلوب';

  @override
  String get balanceWord => 'الرصيد';

  @override
  String get limitWord => 'السقف';

  @override
  String get noLimitLong => 'بلا سقف دين';

  @override
  String get noLimitShort => 'بلا سقف';

  @override
  String get changeWord => 'تغيير';

  @override
  String get pickCustomer => 'اختيار الزبون';

  @override
  String get addCustomerToInvoice => 'إضافة زبون إلى الفاتورة';

  @override
  String get customerRequiredPartial =>
      'اختر الزبون — البيع الجزئي يُسجَّل ديناً باسمه';

  @override
  String get customerRequiredCredit =>
      'اختر الزبون — البيع بالدين يُسجَّل باسمه';

  @override
  String get dueLabel => 'موعد السداد';

  @override
  String get optionalParen => '(اختياري)';

  @override
  String get dueNone => 'بدون موعد';

  @override
  String get dueWeek => 'بعد 7 أيام';

  @override
  String get dueMonth => 'بعد 30 يوماً';

  @override
  String get dueOn => 'الاستحقاق:';

  @override
  String get negativeStockTitle => 'تنبيه مخزون — يمكنك المتابعة';

  @override
  String negativeStockRow(String stock, String quantity) {
    return 'المسجّل $stock · المطلوب $quantity';
  }

  @override
  String get negativeStockBody =>
      'الكمية أكبر من المخزون المسجّل في النظام. سيتم البيع، وسيصبح المخزون سالباً ويظهر للمالك في قائمة مراجعة المخزون.';

  @override
  String get limitBlockedTitle => 'تجاوز سقف الدين — لا يمكنك إتمام البيع';

  @override
  String limitBalanceNowOf(String name) {
    return 'رصيد $name الآن';
  }

  @override
  String get limitThisSaleDebt => 'دين هذا البيع';

  @override
  String get limitCeiling => 'سقف الدين';

  @override
  String get limitOverBy => 'الزيادة على السقف';

  @override
  String limitServerBody(String name) {
    return 'رفض الخادم البيع: رصيد $name تغيّر منذ تحميل القائمة، والدين الجديد يتجاوز سقفه الآن. لم تُنشأ فاتورة.';
  }

  @override
  String get limitBlockedHelp =>
      'زِد المبلغ المدفوع حتى لا يتجاوز الدين السقف، أو اطلب من المالك أو المدير إتمام البيع من حسابه.';

  @override
  String limitWarnTitle(String name) {
    return 'سيتجاوز رصيد $name سقف الدين';
  }

  @override
  String limitWarnBody(String after, String limit, String over) {
    return 'الرصيد بعد البيع $after والسقف $limit (زيادة $over).';
  }

  @override
  String get limitWarnHelp =>
      'لديك صلاحية التجاوز. ستُطلب منك موافقة صريحة، ويُسجَّل التجاوز باسمك.';

  @override
  String get submitOfflineTitle => 'لا يوجد اتصال — لم يُرسَل البيع';

  @override
  String get submitOfflineBody =>
      'لم يصل الطلب إلى الخادم. تحقق من الإنترنت ثم أعد المحاولة. البيع لن يُسجَّل مرتين.';

  @override
  String get submitUncertainTitle =>
      'انقطع الاتصال أثناء الحفظ — النتيجة غير مؤكدة';

  @override
  String get submitUncertainBody =>
      'قد يكون البيع سُجّل أو لا. أعد المحاولة للتحقق: يُرسَل الطلب نفسه بالمفتاح نفسه، فلا يتكرر البيع. التعديل مقفل حتى يتأكد.';

  @override
  String get submitServerTitle => 'حدث خطأ في الخادم — لم يُسجَّل البيع';

  @override
  String get submitServerBody =>
      'أعد المحاولة بعد قليل. إن تكرر الخطأ، أعطِ رمز المرجع للدعم.';

  @override
  String get submitRejectedTitle => 'لم يُسجَّل البيع';

  @override
  String get paidWord => 'المدفوع';

  @override
  String get remainingWord => 'المتبقي';

  @override
  String get statusPaidFull => 'مدفوع بالكامل';

  @override
  String get statusPartialDebt => 'جزئي — يبقى ديناً';

  @override
  String get statusFullDebt => 'دين كامل';

  @override
  String get barLimitBlocked => 'لا يمكن المتابعة: الدين يتجاوز سقف الزبون';

  @override
  String get barPaidFull => 'مدفوع بالكامل — لا دين';

  @override
  String barDebtOn(String amount, String name) {
    return 'سيُسجَّل دين $amount على $name';
  }

  @override
  String barDebtNoCustomer(String amount) {
    return 'سيبقى $amount ديناً — اختر الزبون';
  }

  @override
  String get confirmSale => 'تأكيد البيع ·';

  @override
  String get savingSale => 'جارٍ حفظ البيع…';

  @override
  String get savingShort => 'جارٍ الحفظ…';

  @override
  String get verifyAndRetry => 'التحقق وإعادة المحاولة';

  @override
  String get continueOverLimit => 'متابعة رغم تجاوز السقف…';

  @override
  String get retrySale => 'إعادة المحاولة ·';

  @override
  String get overrideTitle => 'تأكيد تجاوز سقف الدين';

  @override
  String get overrideBalanceNow => 'الرصيد الحالي';

  @override
  String get overrideBalanceAfter => 'الرصيد بعد البيع';

  @override
  String overrideNote(String name, String role) {
    return 'بالموافقة يُنشأ البيع ويُسجَّل التجاوز في سجل التدقيق باسم $name ($role). إغلاق هذه النافذة لا يُتم البيع.';
  }

  @override
  String get overrideForbidden =>
      'رفض الخادم التجاوز: حسابك لا يملك هذه الصلاحية الآن. لم يُسجَّل البيع.';

  @override
  String get overrideBack => 'رجوع دون إتمام';

  @override
  String get overrideConfirm => 'أوافق على التجاوز وأؤكد البيع';

  @override
  String get pickerTitle => 'اختيار الزبون';

  @override
  String get pickerCancel => 'إلغاء الاختيار';

  @override
  String get pickerSearchHint => 'ابحث بالاسم أو رقم الهاتف';

  @override
  String get pickerNeedsCustomer =>
      'البيع الجزئي أو بالدين يحتاج زبوناً لتسجيل الدين باسمه.';

  @override
  String get pickerLoading => 'جارٍ تحميل الزبائن';

  @override
  String get pickerEmpty => 'لا يوجد زبون بهذا الاسم أو الرقم';

  @override
  String get pickerEmptyBody => 'تحقق من الكتابة، أو أضفه زبوناً جديداً.';

  @override
  String pickerAddNamed(String name) {
    return 'إضافة «$name» زبوناً جديداً';
  }

  @override
  String get pickerNewCustomer => 'زبون جديد';

  @override
  String get pickerError => 'تعذّر تحميل الزبائن';

  @override
  String get pickerErrorBody => 'تحقق من الاتصال. البيع الحالي محفوظ كما هو.';

  @override
  String get pickerSkip => 'متابعة بدون زبون';

  @override
  String get owesWord => 'عليه';

  @override
  String get noDebtWord => 'لا دين';

  @override
  String get newCustomerTitle => 'زبون جديد';

  @override
  String get newCustomerName => 'اسم الزبون';

  @override
  String get newCustomerPhone => 'رقم الهاتف';

  @override
  String get newCustomerPhoneHint =>
      '10 أرقام. سقف الدين يحدده المالك أو المدير لاحقاً.';

  @override
  String get newCustomerNameRequired => 'اكتب اسم الزبون';

  @override
  String get newCustomerPhoneInvalid => 'رقم الهاتف 10 أرقام ويبدأ بـ 0';

  @override
  String get newCustomerSave => 'حفظ واختيار الزبون';

  @override
  String get newCustomerBack => 'رجوع إلى البحث';

  @override
  String get receiptDoneTitle => 'تم البيع';

  @override
  String get receiptPaidWord => 'دُفع';

  @override
  String get receiptPaidTail => 'بالكامل';

  @override
  String get receiptDebtWord => 'سُجّل دين';

  @override
  String receiptDebtTail(String name) {
    return 'على $name';
  }

  @override
  String get receiptVoidedTitle => 'أُلغيت الفاتورة';

  @override
  String get receiptInvoiceWord => 'الفاتورة';

  @override
  String get receiptVoidedTail => 'محفوظة في السجل بحالة «ملغاة»';

  @override
  String get receiptNumber => 'رقم الفاتورة';

  @override
  String get receiptDate => 'التاريخ';

  @override
  String get receiptSeller => 'البائع';

  @override
  String get remainingAsDebt => 'المتبقي ديناً';

  @override
  String get voidedStamp => 'ملغاة';

  @override
  String receiptNegativeNote(String names) {
    return 'سُجّل «$names» بمخزون سالب، وأُضيف إلى قائمة مراجعة المخزون لدى المالك.';
  }

  @override
  String receiptOverrideNote(String customer, String user) {
    return 'تم تجاوز سقف دين $customer بموافقة $user. التجاوز مسجّل في سجل التدقيق.';
  }

  @override
  String get receiptReplayNote =>
      'تحققنا من الخادم: البيع مسجّل مرة واحدة فقط رغم انقطاع الاتصال.';

  @override
  String receiptVoidedBy(String name, String time) {
    return 'أُلغيت بواسطة $name · $time';
  }

  @override
  String receiptVoidReason(String reason) {
    return 'السبب: $reason';
  }

  @override
  String get receiptVoidEffect =>
      'أُعيد المخزون وأُلغي الدين المرتبط. الفاتورة باقية في السجل بحالة «ملغاة».';

  @override
  String get newSale => 'بيع جديد';

  @override
  String get voidInvoiceEllipsis => 'إلغاء الفاتورة…';

  @override
  String voidTitle(int id) {
    return 'إلغاء الفاتورة #$id';
  }

  @override
  String get voidEffectsTitle => 'عند الإلغاء:';

  @override
  String get voidEffectStock => 'تُعاد كميات الأصناف إلى المخزون.';

  @override
  String voidEffectDebt(String amount, String name) {
    return 'يُلغى الدين المرتبط $amount على $name.';
  }

  @override
  String get voidEffectKept =>
      'تبقى الفاتورة في السجل بحالة «ملغاة» ولا تُحذف.';

  @override
  String get voidEffectFinal => 'لا يمكن التراجع عن الإلغاء.';

  @override
  String get voidReasonLabel => 'سبب الإلغاء (مطلوب)';

  @override
  String get voidReasonRequired => 'اكتب سبب الإلغاء — يُحفظ في سجل التدقيق';

  @override
  String get voidBlocked =>
      'لا يمكن إلغاء هذه الفاتورة: عليها دفعات لاحقة أو مرتجعات. استخدم «مرتجع» من إدارة المبيعات على الويب.';

  @override
  String get voidForbidden =>
      'ليست لديك صلاحية إلغاء الفواتير. الإلغاء للمالك أو المدير.';

  @override
  String get voidNetwork => 'تعذّر الاتصال — لم تُلغَ الفاتورة. أعد المحاولة.';

  @override
  String get voiding => 'جارٍ الإلغاء…';

  @override
  String get voidConfirm => 'إلغاء الفاتورة نهائياً';

  @override
  String get custSearchHint => 'بحث بالاسم أو الهاتف';

  @override
  String get custAdd => '+ زبون';

  @override
  String get custSearchMin => 'اكتب حرفين أو أكثر للبحث.';

  @override
  String get custEmptyTitle => 'لا زبائن بعد';

  @override
  String get custEmptyBody => 'أضف زبائن الدين. البيع النقدي لا يحتاج زبوناً.';

  @override
  String custNoResults(String query) {
    return 'لا زبون باسم «$query»';
  }

  @override
  String get custNoResultsBody => 'أضفه الآن بالاسم والهاتف.';

  @override
  String custAddNamed(String name) {
    return 'إضافة «$name»';
  }

  @override
  String get custLoadError =>
      'تعذّر تحميل الزبائن. تحقق من الاتصال ثم أعد المحاولة.';

  @override
  String get custOverdue => 'متأخر';

  @override
  String get custInactive => 'موقوف';

  @override
  String get custRemaining => 'المتبقي عليه';

  @override
  String custOverdueAmount(String amount) {
    return 'متأخر $amount';
  }

  @override
  String custLimit(String amount) {
    return 'حد الدين $amount';
  }

  @override
  String get custNoLimit => 'بلا حد للدين';

  @override
  String get custRecordPayment => 'تسجيل دفعة';

  @override
  String custCall(String phone) {
    return 'اتصال بـ $phone';
  }

  @override
  String get custOpenDebts => 'ديون مفتوحة';

  @override
  String get custNoOpenDebts => 'لا ديون مفتوحة على هذا الزبون.';

  @override
  String get custRecentPayments => 'آخر الدفعات';

  @override
  String get custNoPayments => 'لا دفعات بعد.';

  @override
  String custDebtSale(int id) {
    return 'فاتورة #$id';
  }

  @override
  String get custDebtOpening => 'دين افتتاحي';

  @override
  String custDue(String date) {
    return 'استحقاق $date';
  }

  @override
  String get custNoDue => 'بلا تاريخ استحقاق';

  @override
  String get custStatusOpen => 'مفتوح';

  @override
  String get custReversed => 'معكوسة';

  @override
  String get custDetailError => 'تعذّر تحميل ملف الزبون.';

  @override
  String get custInactiveNote =>
      'هذا الزبون موقوف: لا يظهر في البيع الجديد، ودفعاته مقبولة.';

  @override
  String payTitle(String name) {
    return 'دفعة من $name';
  }

  @override
  String get payAmount => 'المبلغ';

  @override
  String get payFull => 'كامل المتبقي';

  @override
  String get payOther => 'مبلغ آخر';

  @override
  String payRemainingNote(String amount) {
    return 'المتبقي $amount · حتى خانتين عشريتين';
  }

  @override
  String get payMethod => 'طريقة الدفع';

  @override
  String get payNow => 'المتبقي الآن';

  @override
  String get payThis => 'الدفعة';

  @override
  String get payAfter => 'بعد الدفعة';

  @override
  String get payOldestFirst => 'تُوزَّع على الديون من الأقدم استحقاقاً.';

  @override
  String payConfirm(String amount) {
    return 'تأكيد استلام $amount';
  }

  @override
  String get paySaving => 'جارٍ تسجيل الدفعة…';

  @override
  String get payRetry => 'إعادة المحاولة';

  @override
  String get payUncertain =>
      'لم يصل رد الخادم، فلا نعرف إن سُجّلت الدفعة. اضغط «إعادة المحاولة»: تُرسل بنفس المفتاح فلن تُسجَّل مرتين.';

  @override
  String get payInvalid => 'أدخل مبلغاً صحيحاً بخانتين عشريتين على الأكثر.';

  @override
  String payTooMuch(String amount) {
    return 'المبلغ أكبر من المتبقي ($amount).';
  }

  @override
  String get payNothing => 'لا يوجد على هذا الزبون مبلغ متبقٍّ.';

  @override
  String payDone(String amount) {
    return 'استُلمت $amount';
  }

  @override
  String payDoneRemaining(String name, String amount) {
    return 'المتبقي على $name الآن $amount';
  }

  @override
  String get payDoneButton => 'تم';

  @override
  String get prodSearchHint => 'بحث بالاسم أو الباركود';

  @override
  String get prodAdd => '+ منتج';

  @override
  String get prodFilterAll => 'الكل';

  @override
  String get prodFilterLow => 'منخفض';

  @override
  String get prodFilterNegative => 'سالب';

  @override
  String get prodEmptyTitle => 'لا منتجات بعد';

  @override
  String get prodEmptyBody =>
      'امسح رمز المنتج أو الباركود لإضافته بسرعة، أو استورد قائمتك من الويب.';

  @override
  String get prodNoResults => 'لا منتجات تطابق هذا البحث.';

  @override
  String get prodLoadError => 'تعذّر تحميل المنتجات.';

  @override
  String get prodStockOk => 'متوفر';

  @override
  String get prodStockLow => 'منخفض';

  @override
  String get prodStockOut => 'نفد';

  @override
  String get prodStockNegative => 'سالب';

  @override
  String get prodPerPiece => 'قطعة';

  @override
  String get prodPerKg => 'كغ';

  @override
  String get addTitle => 'إضافة منتج';

  @override
  String get addScan => 'مسح رمز QR أو الباركود';

  @override
  String get addScanSub => 'نقرأ ما في الرمز ونعبّئ الحقول';

  @override
  String get addManual => 'إدخال يدوي';

  @override
  String get addManualSub => 'للمنتجات بلا رمز، مثل الموزون';

  @override
  String get addChecking => 'جارٍ التحقق من الرمز…';

  @override
  String get addExistsTitle => 'المنتج موجود';

  @override
  String addExistsBody(String code) {
    return 'الباركود $code مسجّل في متجرك. لن نضيفه مرة ثانية.';
  }

  @override
  String get addScanAnother => 'مسح رمز آخر';

  @override
  String get addFromCode => 'من الرمز';

  @override
  String get addBarcodeOnly => 'الرمز يحتوي الباركود فقط. أكمل الاسم والسعر.';

  @override
  String addReadFields(String fields) {
    return 'قرأنا من الرمز: $fields. راجعها قبل الحفظ.';
  }

  @override
  String get addFieldName => 'الاسم';

  @override
  String get addFieldBarcode => 'الباركود';

  @override
  String get addFieldPrice => 'السعر';

  @override
  String get addFieldUnit => 'الوحدة';

  @override
  String get addUnreadable =>
      'هذا الرمز لا يحتوي بيانات منتج. أدخل المنتج يدوياً؛ لن نستخدم محتواه.';

  @override
  String get addManualNote => 'إدخال يدوي. الاسم وسعر البيع مطلوبان.';

  @override
  String get addLookupFailed =>
      'تعذّر التحقق من وجود المنتج الآن؛ سنتحقق عند الحفظ.';

  @override
  String get addFromCatalog =>
      'هذا المنتج معروف في حسبة، فملأنا اسمه ووحدته. أدخل سعر البيع والتكلفة والكمية لمتجرك.';

  @override
  String get formNewTitle => 'منتج جديد';

  @override
  String get formName => 'اسم المنتج';

  @override
  String get formNameHint => 'مثال: تمر مجهول 1 كغ';

  @override
  String get formBarcode => 'الباركود';

  @override
  String get formOptional => 'اختياري';

  @override
  String get formSoldBy => 'يُباع';

  @override
  String get formByPiece => 'بالقطعة';

  @override
  String get formByKg => 'بالوزن (كغ)';

  @override
  String get formPrice => 'سعر البيع';

  @override
  String get formCost => 'سعر الشراء';

  @override
  String get formStock => 'المخزون الآن';

  @override
  String get formMin => 'تنبيه عند';

  @override
  String get formNameRequired => 'اكتب اسم المنتج.';

  @override
  String get formPriceInvalid => 'أدخل سعراً صحيحاً.';

  @override
  String get formStockPiece => 'عدد صحيح للمنتج بالقطعة.';

  @override
  String get formStockKg => 'حتى 3 خانات عشرية.';

  @override
  String get formSave => 'حفظ المنتج';

  @override
  String get formSaving => 'جارٍ الحفظ…';

  @override
  String get formNetwork =>
      'تعذّر الحفظ: لا اتصال بالخادم. بياناتك باقية في النموذج؛ أعد المحاولة.';

  @override
  String get formForbidden =>
      'إضافة المنتجات للمالك أو المدير. اطلب من المالك إضافته.';

  @override
  String get formFailed => 'تعذّر الحفظ. حاول مرة أخرى.';

  @override
  String savedTitle(String name) {
    return 'أُضيف «$name»';
  }

  @override
  String get savedScanNext => 'مسح منتج آخر';

  @override
  String get savedBack => 'العودة إلى المنتجات';

  @override
  String get homeAttention => 'يحتاج انتباهك';

  @override
  String homeOverdueAlert(int count) {
    return 'ديون متأخرة: $count';
  }

  @override
  String homeDueTodayAlert(int count) {
    return 'مستحق اليوم: $count';
  }

  @override
  String homeLowStockAlert(int count) {
    return 'منتجات تحت الحد: $count';
  }

  @override
  String homeNegativeAlert(int count) {
    return 'مخزون سالب للمراجعة: $count';
  }

  @override
  String get homeAllClear => 'لا شيء يحتاج انتباهك الآن.';

  @override
  String get homeCollections => 'التحصيلات';

  @override
  String homeCollectionsSplit(String atSale, String repayments) {
    return 'عند البيع $atSale · ديون $repayments';
  }

  @override
  String get loginNoAccount => 'ليس لديك حساب؟';

  @override
  String get loginCreateStore => 'إنشاء متجر جديد';

  @override
  String get storeSuspended =>
      'حساب هذا المتجر موقوف. تواصل مع إدارة حسبة لإعادة تفعيله.';

  @override
  String get registerTitle => 'إنشاء متجر جديد';

  @override
  String get registerHelper => 'ثلاث خطوات، وتبدأ بفترة تجريبية مجانية 7 أيام.';

  @override
  String registerStepOf(int current, int total) {
    return 'الخطوة $current من $total';
  }

  @override
  String get registerStepStore => 'المتجر';

  @override
  String get registerStepStoreSub => 'لنبدأ باسم متجرك واسم صاحبه المسؤول عنه.';

  @override
  String get registerStepContact => 'الموقع والتواصل';

  @override
  String get registerStepContactSub =>
      'الهاتف والعنوان يظهران على إيصال الزبون.';

  @override
  String get registerStepAccount => 'بيانات الدخول';

  @override
  String get registerStepAccountSub =>
      'اختر البريد وكلمة المرور التي تدخل بها إلى حسبة.';

  @override
  String get storeNameLabel => 'اسم المتجر';

  @override
  String get ownerNameLabel => 'اسم صاحب المتجر';

  @override
  String get storePhoneLabel => 'رقم الهاتف';

  @override
  String get cityLabel => 'المدينة';

  @override
  String get cityHint => 'اختر المدينة';

  @override
  String get streetLabel => 'العنوان (الشارع والمنطقة)';

  @override
  String get passwordConfirmLabel => 'تأكيد كلمة المرور';

  @override
  String get passwordMinHint => '8 أحرف على الأقل';

  @override
  String get storeNameRequired => 'يرجى إدخال اسم المتجر.';

  @override
  String get ownerNameRequired => 'يرجى إدخال اسم صاحب المتجر.';

  @override
  String get phoneRequired => 'يرجى إدخال رقم الهاتف.';

  @override
  String get phoneInvalid => 'رقم الهاتف 9 أو 10 أرقام، مثل 0599123456.';

  @override
  String get cityRequired => 'يرجى اختيار المدينة.';

  @override
  String get streetRequired => 'يرجى إدخال عنوان المتجر.';

  @override
  String get registerEmailRequired => 'يرجى إدخال البريد الإلكتروني.';

  @override
  String get registerEmailInvalid => 'صيغة البريد الإلكتروني غير صحيحة.';

  @override
  String get passwordTooShort => 'كلمة المرور 8 أحرف على الأقل.';

  @override
  String get passwordMismatch => 'التأكيد لا يطابق كلمة المرور.';

  @override
  String get emailTaken =>
      'هذا البريد مسجّل مسبقاً. سجّل الدخول، أو استخدم بريداً آخر.';

  @override
  String get registerFailedTaken =>
      'لم يُنشأ المتجر: البريد الإلكتروني مستخدم.';

  @override
  String get registerFailedValidation =>
      'لم يُنشأ المتجر. راجع الحقول المعلّمة.';

  @override
  String get registerNetworkError =>
      'تعذّر الاتصال بالخادم. بياناتك باقية في النموذج، أعد المحاولة.';

  @override
  String get registerServerError =>
      'حدث خطأ في الخادم ولم يُنشأ المتجر. أعد المحاولة بعد قليل.';

  @override
  String get registerNext => 'التالي';

  @override
  String get registerBack => 'رجوع';

  @override
  String get registerSubmit => 'إنشاء المتجر';

  @override
  String get registerSubmitting => 'جارٍ إنشاء المتجر…';

  @override
  String get registerHaveAccount => 'لديك حساب؟';

  @override
  String get registerSignIn => 'تسجيل الدخول';

  @override
  String get subscriptionTrialEndedTitle => 'انتهت الفترة التجريبية';

  @override
  String get subscriptionPaidEndedTitle => 'انتهى اشتراك متجرك';

  @override
  String subscriptionEndedOn(String store, String date) {
    return 'متجر «$store»، انتهت في $date';
  }

  @override
  String get subscriptionDataSafe =>
      'بياناتك محفوظة كما هي: الزبائن والديون والمبيعات والمنتجات. يعود كل شيء فور تفعيل الاشتراك.';

  @override
  String get subscriptionContactWhatsapp => 'تواصل معنا عبر واتساب';

  @override
  String get subscriptionContactNoNumber =>
      'تواصل مع إدارة حسبة لتفعيل الاشتراك.';

  @override
  String subscriptionWhatsappMessage(String store, String email) {
    return 'مرحباً، أريد تفعيل اشتراك متجر «$store» على حسبة.\nالبريد: $email';
  }

  @override
  String subscriptionWhatsappFailed(String number) {
    return 'تعذّر فتح واتساب. رقم الدعم: $number';
  }

  @override
  String get subscriptionCheckAgain => 'تحقق من جديد';

  @override
  String get subscriptionChecking => 'جارٍ التحقق…';

  @override
  String get subscriptionStillInactive =>
      'لم يُفعَّل الاشتراك بعد. بعد تأكيد الدفع من إدارة حسبة اضغط «تحقق من جديد».';

  @override
  String get saleScanTitle => 'مسح منتجات البيع';

  @override
  String get saleScanKeepGoing => 'الكاميرا شغّالة: امسح المنتج التالي';

  @override
  String get saleScanCloseA11y => 'إغلاق الكاميرا والعودة إلى السلة';

  @override
  String get cartPanelTitle => 'السلة';

  @override
  String get saleScanEmptyBody =>
      'وجّه الكاميرا إلى باركود المنتج. تبقى الكاميرا مفتوحة لتضيف المنتجات واحداً تلو الآخر.';

  @override
  String get completeSale => 'إتمام البيع';

  @override
  String methodRecordOnly(String method) {
    return 'يُسجَّل فقط أن الزبون دفع عبر $method. حسبة لا تتصل بهذه الخدمة ولا تتحقق من وصول المبلغ، فتأكد منه قبل تأكيد البيع.';
  }

  @override
  String get invTitle => 'إضافة منتجات بالمسح';

  @override
  String get invInstruction =>
      'امسح باركود المنتج لإضافته إلى متجرك. لا يدخل سلة البيع.';

  @override
  String get invWaiting => 'أكمل النموذج أو أغلقه لمسح المنتج التالي';

  @override
  String get invCloseA11y => 'إغلاق الكاميرا والعودة إلى المنتجات';

  @override
  String get invBackToScanning => 'إغلاق والعودة إلى المسح';

  @override
  String invStockNow(String stock) {
    return 'المخزون الآن $stock';
  }

  @override
  String get invExistsNote =>
      'هذا المنتج في متجرك، فلن يُضاف مرة ثانية. لإدخال بضاعة جديدة منه اختر «إضافة كمية».';

  @override
  String get invAddStock => 'إضافة كمية';

  @override
  String invAddStockQty(String unit) {
    return 'الكمية المستلمة ($unit)';
  }

  @override
  String get invReason => 'السبب';

  @override
  String get invReasonDefault => 'بضاعة واردة';

  @override
  String get invReasonRequired => 'اكتب سبب إضافة الكمية.';

  @override
  String get invQtyPiece => 'أدخل عدداً صحيحاً أكبر من صفر.';

  @override
  String get invQtyKg => 'أدخل وزناً أكبر من صفر، حتى 3 خانات عشرية.';

  @override
  String get invAddStockSave => 'إضافة إلى المخزون';

  @override
  String invStockAdded(String name, String stock) {
    return 'أُضيفت الكمية إلى «$name». المخزون الآن $stock';
  }

  @override
  String get invStockForbidden => 'تعديل المخزون للمالك أو المدير.';

  @override
  String invOpeningStock(String unit) {
    return 'الكمية الموجودة الآن ($unit)';
  }

  @override
  String get invNetworkUncertain =>
      'انقطع الاتصال قبل أن يصل رد الخادم، فقد يكون الحفظ تمّ. بياناتك باقية؛ اضغط «إعادة المحاولة» وسنتحقق دون تكرار المنتج.';

  @override
  String get invFromCatalog =>
      'معروف في حسبة: الاسم والوحدة جاهزان. أكمل أسعار متجرك والكمية.';

  @override
  String get packWord => 'كرتونة';

  @override
  String unitChipPack(int size) {
    return 'كرتونة ×$size';
  }

  @override
  String packPer(int size) {
    return 'كرتونة ($size قطعة)';
  }

  @override
  String packEquals(String pieces) {
    return '= $pieces قطعة';
  }

  @override
  String addPackLine(int size, String price) {
    return '+ كرتونة ($size قطعة) بـ $price';
  }

  @override
  String get packToggle => 'يُباع بالكرتونة أيضاً (جملة)';

  @override
  String get packToggleSub => 'المخزون يبقى بالقطعة؛ بيع كرتونة يخصم كل قطعها.';

  @override
  String get packSizeLabel => 'عدد القطع في الكرتونة';

  @override
  String get packPriceLabel => 'سعر الكرتونة كاملة';

  @override
  String get packSizeInvalid => 'عدد صحيح من 2 إلى 10000.';

  @override
  String get packPriceNotAbovePiece =>
      'سعر الكرتونة يجب أن يكون أعلى من سعر القطعة. هل أدخلت سعر القطعة هنا؟';

  @override
  String packPerPiece(String price) {
    return 'القطعة داخل الكرتونة بـ $price.';
  }

  @override
  String packPerPieceVs(String pack, String piece) {
    return 'القطعة داخل الكرتونة بـ $pack مقابل $piece بالمفرد.';
  }

  @override
  String get invQtyPack => 'أدخل عدداً صحيحاً من الكراتين أكبر من صفر.';
}
