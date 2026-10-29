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
  String get guideTitle => 'دليل الاستخدام';

  @override
  String get guideCardTitle => 'جديد على حسبة؟';

  @override
  String get guideCardBody =>
      'جرّب في دقيقتين: أضف صنفاً بالباركود، ثم بِعه في فاتورة.';

  @override
  String get guideStart => 'ابدأ الدليل';

  @override
  String get guideLater => 'لاحقاً';

  @override
  String guideStep(int n, int total) {
    return 'الخطوة $n من $total';
  }

  @override
  String get guideWelcomeTitle => 'أهلاً بك في حسبة';

  @override
  String get guideWelcomeBody =>
      'سنجرب معاً أهم شيئين في المحل: إضافة صنف بالباركود، وعمل فاتورة بالباركود. كل ما تفعله هنا حقيقي ويُحفظ في متجرك.';

  @override
  String get guideAddTitle => 'أضف صنفك الأول بالباركود';

  @override
  String get guideAdd1 =>
      'اضغط «امسح صنفاً الآن» ووجّه الكاميرا إلى باركود أي صنف في محلك.';

  @override
  String get guideAdd2 =>
      'إن كان الصنف معروفاً نملأ اسمه، وأنت تكتب السعر والكمية الموجودة.';

  @override
  String get guideAdd3 => 'اضغط «حفظ»، ثم ارجع لتكمل الدليل.';

  @override
  String get guideAddAction => 'امسح صنفاً الآن';

  @override
  String get guideAddDone => 'أضفت صنفك الأول. أحسنت!';

  @override
  String get guideSaleTitle => 'اعمل فاتورتك الأولى بالباركود';

  @override
  String get guideSale1 =>
      'اضغط «افتح شاشة البيع» ثم امسح الصنف؛ يدخل السلة فوراً.';

  @override
  String get guideSale2 =>
      'امسح الصنف مرة ثانية لزيادة الكمية، أو امسح أصناف أخرى.';

  @override
  String get guideSale3 =>
      'اضغط «إتمام البيع»، اختر نقداً أو ديناً على زبون، ثم احفظ الفاتورة.';

  @override
  String get guideSaleAction => 'افتح شاشة البيع';

  @override
  String get guideDoneTitle => 'جاهز للعمل!';

  @override
  String get guideDoneBody =>
      'الفواتير في «المبيعات»، والديون في «الزبائن»، والمخزون في «البضاعة». الإعدادات والدعم الفني في «المزيد»، ومنها تفتح هذا الدليل متى شئت.';

  @override
  String get guideFinish => 'ابدأ العمل';

  @override
  String get guideNext => 'التالي';

  @override
  String get guideSkip => 'تخطَّ هذه الخطوة';

  @override
  String get moreGuideSub => 'جرّب إضافة صنف وعمل فاتورة خطوة بخطوة';

  @override
  String get moreSupport => 'الدعم الفني';

  @override
  String get moreSupportSub => 'أرسل شكوى أو اقتراحاً لفريق حسبة';

  @override
  String get supportType => 'نوع الدعم';

  @override
  String get supportTypeTechnical => 'مشكلة تقنية';

  @override
  String get supportTypeAccount => 'الحساب والاشتراك';

  @override
  String get supportTypeSuggestion => 'اقتراح';

  @override
  String get supportTypeOther => 'أخرى';

  @override
  String get supportSubject => 'موضوع المشكلة';

  @override
  String get phSupportSubject => 'بكلمات قليلة، مثل: الطابعة لا تطبع الإيصال';

  @override
  String get supportDetails => 'تفاصيل المشكلة';

  @override
  String get phSupportDetails =>
      'ماذا حدث، وأين، ومتى؟ كلما كتبت أكثر ساعدناك أسرع';

  @override
  String get supportSend => 'إرسال الشكوى';

  @override
  String get supportSent => 'وصلت شكواك إلى فريق حسبة، وسنرد عليك هنا.';

  @override
  String get supportTypeRequired => 'اختر نوع الدعم.';

  @override
  String get supportSubjectRequired => 'اكتب موضوع المشكلة.';

  @override
  String get supportDetailsRequired => 'اكتب تفاصيل المشكلة.';

  @override
  String get supportMine => 'شكاواي';

  @override
  String get supportNone => 'لم ترسل أي شكوى بعد.';

  @override
  String get supportStatusOpen => 'جديدة';

  @override
  String get supportStatusInProgress => 'قيد المعالجة';

  @override
  String get supportStatusClosed => 'مغلقة';

  @override
  String get supportReply => 'رد فريق حسبة';

  @override
  String get supportLoadError =>
      'تعذّر تحميل الشكاوى. تحقق من الاتصال ثم أعد المحاولة.';

  @override
  String get phBarcode => 'الرقم تحت خطوط الباركود على العبوة';

  @override
  String get phOpeningStock => 'كم عندك منه على الرف الآن';

  @override
  String get phPackSize => 'كم قطعة في الكرتونة';

  @override
  String get phPackPrice => 'سعر الكرتونة كاملة للزبون';

  @override
  String get phAddQty => 'كم وصلك من هذه البضاعة';

  @override
  String get phReason => 'سبب تغيير المخزون، مثل: بضاعة واردة';

  @override
  String get phAdjustQty => 'الكمية حسب نوع التعديل المختار أعلاه';

  @override
  String get phStoreName => 'الاسم الذي يظهر أعلى الإيصال';

  @override
  String get phAddress => 'الشارع أو أقرب معلم، يظهر على الإيصال';

  @override
  String get phArea => 'المدينة أو المنطقة، مثل: نابلس';

  @override
  String get phCurrentPw => 'كلمة المرور التي تدخل بها الآن';

  @override
  String get phConfirmPw => 'اكتب كلمة المرور الجديدة مرة ثانية';

  @override
  String get phLoginPw => 'كلمة مرور حسابك';

  @override
  String get phRegStoreName => 'اسم المحل كما يعرفه الزبائن';

  @override
  String get phOwnerName => 'اسمك الكامل';

  @override
  String get phStreet => 'الشارع أو أقرب معلم';

  @override
  String get phPhone => 'رقم جوالك، مثل 0599123456';

  @override
  String get phCustomerName => 'اسم الزبون كما تناديه';

  @override
  String get phPaidNow => 'كم دفع الزبون الآن بالشيكل';

  @override
  String get phPayAmount => 'المبلغ الذي دفعه الزبون بالشيكل';

  @override
  String get phVoidReason => 'لماذا تُلغى هذه الفاتورة';

  @override
  String get splashTagline => 'دفتر متجرك، في جيبك';

  @override
  String get splashSubline => 'المبيعات والديون والبضاعة في مكان واحد';

  @override
  String get splashChecking => 'جارٍ التحقق من الجلسة';

  @override
  String get loginTitle => 'تسجيل الدخول';

  @override
  String get loginHelper => 'أدخل بيانات حسابك في المتجر';

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
  String get passwordRequired => 'أدخل كلمة المرور';

  @override
  String get invalidCredentials => 'رقم الجوال أو كلمة المرور غير صحيحة.';

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
  String get tabProducts => 'البضاعة';

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
  String get placeholderProducts => 'البضاعة والأصناف اللي قرّبت تخلص';

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
  String get logout => 'تسجيل الخروج';

  @override
  String get logoutConfirmTitle => 'تسجيل الخروج؟';

  @override
  String get logoutConfirmBody =>
      'ستحتاج إلى رقم الجوال وكلمة المرور للدخول مجدداً.';

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
  String get scanEntryTitle => 'عرض بيانات صنف';

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
  String get scanSearchingProduct => 'جارٍ البحث عن الصنف…';

  @override
  String get scanHintTitle => 'صعب القراءة؟';

  @override
  String get scanHintBody =>
      'قرّب الباركود ببطء، أمِل الصنف لتجنب اللمعان، وشغّل الإضاءة. أو أدخله يدويًا.';

  @override
  String get scanManual => 'إدخال الباركود يدويًا';

  @override
  String get scanFound => 'لقينا الصنف';

  @override
  String get scanPrice => 'سعر البيع';

  @override
  String get scanStock => 'الكمية الموجودة';

  @override
  String get scanBarcodeLabel => 'الباركود';

  @override
  String get scanAnother => 'امسح صنف ثاني';

  @override
  String get scanBackToSale => 'الرجوع إلى البيع';

  @override
  String get scanNotFoundTitle => 'ما في صنف بهذا الباركود';

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
  String get manualHint => 'الأرقام كما تظهر تحت خطوط الباركود';

  @override
  String get manualHelper => 'اكتب الأرقام كما تظهر تحت خطوط الباركود.';

  @override
  String get manualEmpty => 'أدخل رقم الباركود';

  @override
  String get manualSubmit => 'عرض الصنف';

  @override
  String get manualCancelA11y => 'إلغاء الإدخال اليدوي';

  @override
  String get lookupFailedTitle => 'تعذّر عرض الصنف';

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
  String get scanLookingUp => 'جارٍ البحث عن الصنف…';

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
  String get scanUnknownBody => 'لا يوجد صنف بهذا الرقم في متجرك:';

  @override
  String get scanLookupFailed => 'تعذّر البحث عن الصنف';

  @override
  String get scanLookupFailedBody => 'تحقق من الاتصال ثم أعد المحاولة.';

  @override
  String get cartEmptyTitle => 'امسح أول صنف لتبدأ';

  @override
  String get cartEmptyBody =>
      'أو ابحث عنه بالاسم. البضاعة بالوزن تفتح شاشة إدخال الوزن.';

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
  String get stockWord => 'الكمية';

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
  String get productSearchTitle => 'بحث عن صنف';

  @override
  String get productSearchHint => 'ابحث باسم الصنف أو الباركود';

  @override
  String get productSearchEmpty => 'ما في صنف بهذا الاسم';

  @override
  String get productSearchEmptyBody =>
      'تحقق من الكتابة. البضاعة تُضاف من لوحة الإدارة على الويب.';

  @override
  String get productSearchError => 'تعذّر تحميل البضاعة';

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
  String get newCustomerPhoneHint => 'رقم جوال الزبون، 10 أرقام';

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
  String get custEmptyTitle => 'ما في زبائن لسّا';

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
  String get custRemaining => 'الباقي عليه';

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
  String get custRecordPayment => 'قبض دفعة';

  @override
  String custCall(String phone) {
    return 'اتصال بـ $phone';
  }

  @override
  String get custOpenDebts => 'ديون مفتوحة';

  @override
  String get custNoOpenDebts => 'ما عليه ديون مفتوحة.';

  @override
  String get custRecentPayments => 'آخر الدفعات';

  @override
  String get custNoPayments => 'ما في دفعات لسّا.';

  @override
  String custDebtSale(int id) {
    return 'فاتورة #$id';
  }

  @override
  String get custDebtOpening => 'دين قديم';

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
  String get payFull => 'كل الباقي';

  @override
  String get payOther => 'مبلغ آخر';

  @override
  String payRemainingNote(String amount) {
    return 'المتبقي $amount · حتى خانتين عشريتين';
  }

  @override
  String get payMethod => 'طريقة الدفع';

  @override
  String get payNow => 'الباقي هلّأ';

  @override
  String get payThis => 'الدفعة';

  @override
  String get payAfter => 'الباقي بعد الدفعة';

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
  String get prodAdd => '+ صنف';

  @override
  String get prodFilterAll => 'الكل';

  @override
  String get prodFilterLow => 'منخفض';

  @override
  String get prodFilterNegative => 'سالب';

  @override
  String get prodEmptyTitle => 'ما في بضاعة لسّا';

  @override
  String get prodEmptyBody =>
      'امسح رمز الصنف أو الباركود لإضافته بسرعة، أو استورد قائمتك من الويب.';

  @override
  String get prodNoResults => 'ما في بضاعة بهذا الاسم.';

  @override
  String get prodLoadError => 'تعذّر تحميل البضاعة.';

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
  String get addTitle => 'إضافة صنف';

  @override
  String get addScan => 'مسح رمز QR أو الباركود';

  @override
  String get addScanSub => 'نقرأ ما في الرمز ونعبّئ الحقول';

  @override
  String get addManual => 'إدخال يدوي';

  @override
  String get addManualSub => 'للأصناف بلا رمز، مثل الموزون';

  @override
  String get addChecking => 'جارٍ التحقق من الرمز…';

  @override
  String get addExistsTitle => 'الصنف موجود';

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
      'هذا الرمز لا يحتوي بيانات صنف. أدخل الصنف يدوياً؛ لن نستخدم محتواه.';

  @override
  String get addManualNote => 'إدخال يدوي. الاسم وسعر البيع مطلوبان.';

  @override
  String get addLookupFailed =>
      'تعذّر التحقق من وجود الصنف الآن؛ سنتحقق عند الحفظ.';

  @override
  String get addFromCatalog =>
      'هذا الصنف معروف في حسبة، فملأنا اسمه ووحدته. أدخل سعر البيع والتكلفة والكمية لمتجرك.';

  @override
  String get formNewTitle => 'صنف جديد';

  @override
  String get formName => 'اسم الصنف';

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
  String get formPrice => 'السعر للزبون (سعر البيع)';

  @override
  String get formCost => 'تكلفة الصنف عليك (سعر الشراء)';

  @override
  String get formStock => 'الكمية الموجودة الآن';

  @override
  String get formMin => 'نبّهني لمّا توصل الكمية إلى';

  @override
  String get formNameRequired => 'اكتب اسم الصنف.';

  @override
  String get formPriceInvalid => 'أدخل سعراً صحيحاً.';

  @override
  String get formStockPiece => 'عدد صحيح للصنف بالقطعة.';

  @override
  String get formStockKg => 'حتى 3 خانات عشرية.';

  @override
  String get formSave => 'حفظ الصنف';

  @override
  String get formSaving => 'جارٍ الحفظ…';

  @override
  String get formNetwork =>
      'تعذّر الحفظ: لا اتصال بالخادم. بياناتك باقية في النموذج؛ أعد المحاولة.';

  @override
  String get formForbidden =>
      'إضافة البضاعة للمالك أو المدير. اطلب من المالك إضافته.';

  @override
  String get formFailed => 'تعذّر الحفظ. حاول مرة أخرى.';

  @override
  String savedTitle(String name) {
    return 'أُضيف «$name»';
  }

  @override
  String get savedScanNext => 'امسح صنف ثاني';

  @override
  String get savedBack => 'الرجوع للبضاعة';

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
    return 'بضاعة تحت الحد: $count';
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
      'اختر كلمة المرور التي تدخل بها إلى حسبة مع رقم جوالك.';

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
  String get passwordMinHint => 'كلمة مرور للدخول، 8 أحرف على الأقل';

  @override
  String get storeNameRequired => 'يرجى إدخال اسم المتجر.';

  @override
  String get ownerNameRequired => 'يرجى إدخال اسم صاحب المتجر.';

  @override
  String get phoneRequired => 'اكتب رقم جوالك.';

  @override
  String get phoneInvalid => 'رقم الجوال 10 أرقام يبدأ بـ 05، مثل 0599123456.';

  @override
  String get cityRequired => 'يرجى اختيار المدينة.';

  @override
  String get streetRequired => 'يرجى إدخال عنوان المتجر.';

  @override
  String get passwordTooShort => 'كلمة المرور 8 أحرف على الأقل.';

  @override
  String get passwordMismatch => 'التأكيد لا يطابق كلمة المرور.';

  @override
  String get phoneTaken =>
      'هذا الرقم مسجّل مسبقاً. سجّل الدخول، أو استخدم رقماً آخر.';

  @override
  String get registerFailedTaken => 'لم يُنشأ المتجر: رقم الجوال مستخدم.';

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
      'بياناتك محفوظة كما هي: الزبائن والديون والمبيعات والبضاعة. يعود كل شيء فور تفعيل الاشتراك.';

  @override
  String get subscriptionContactWhatsapp => 'تواصل معنا عبر واتساب';

  @override
  String get subscriptionContactNoNumber =>
      'تواصل مع إدارة حسبة لتفعيل الاشتراك.';

  @override
  String subscriptionWhatsappMessage(String store, String phone) {
    return 'مرحباً، أريد تفعيل اشتراك متجر «$store» على حسبة.\nالجوال: $phone';
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
  String get saleScanTitle => 'مسح أصناف البيع';

  @override
  String get saleScanKeepGoing => 'الكاميرا شغّالة: امسح الصنف اللي بعده';

  @override
  String get saleScanCloseA11y => 'إغلاق الكاميرا والعودة إلى السلة';

  @override
  String get cartPanelTitle => 'السلة';

  @override
  String get saleScanEmptyBody =>
      'وجّه الكاميرا إلى باركود الصنف. تبقى الكاميرا مفتوحة لتضيف البضاعة واحداً تلو الآخر.';

  @override
  String get completeSale => 'إتمام البيع';

  @override
  String methodRecordOnly(String method) {
    return 'يُسجَّل فقط أن الزبون دفع عبر $method. حسبة لا تتصل بهذه الخدمة ولا تتحقق من وصول المبلغ، فتأكد منه قبل تأكيد البيع.';
  }

  @override
  String get invTitle => 'إضافة بضاعة بالمسح';

  @override
  String get invInstruction =>
      'امسح باركود الصنف لإضافته إلى متجرك. لا يدخل سلة البيع.';

  @override
  String get invWaiting => 'أكمل النموذج أو أغلقه لمسح الصنف التالي';

  @override
  String get invCloseA11y => 'إغلاق الكاميرا والرجوع للبضاعة';

  @override
  String get invBackToScanning => 'إغلاق والعودة إلى المسح';

  @override
  String invStockNow(String stock) {
    return 'الكمية الآن $stock';
  }

  @override
  String get invExistsNote =>
      'هذا الصنف في متجرك، فلن يُضاف مرة ثانية. لإدخال بضاعة جديدة منه اختر «إضافة كمية».';

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
  String get invAddStockSave => 'إضافة للكمية';

  @override
  String invStockAdded(String name, String stock) {
    return 'أُضيفت الكمية إلى «$name». الكمية الآن $stock';
  }

  @override
  String get invStockForbidden => 'تعديل المخزون للمالك أو المدير.';

  @override
  String invOpeningStock(String unit) {
    return 'الكمية الموجودة الآن ($unit)';
  }

  @override
  String get invNetworkUncertain =>
      'انقطع الاتصال قبل أن يصل رد الخادم، فقد يكون الحفظ تمّ. بياناتك باقية؛ اضغط «إعادة المحاولة» وسنتحقق دون تكرار الصنف.';

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

  @override
  String get formPriceHelpPiece => 'ما يدفعه الزبون مقابل قطعة واحدة.';

  @override
  String get formPriceHelpKg => 'ما يدفعه الزبون مقابل كيلو واحد.';

  @override
  String get formCostHelp => 'ما تدفعه للمورّد، لا يراه الزبون';

  @override
  String get formMinHelp => 'عند هذا العدد أو أقل يظهر في «منخفض»';

  @override
  String get formRequiredA11y => 'مطلوب';

  @override
  String get formFixErrors => 'راجع الحقول المعلَّمة باللون الأحمر.';

  @override
  String get subscriptionHowTo =>
      'بعد الدفع تفعّل إدارة حسبة اشتراكك، ثم اضغط «تحقق من جديد» لتعود إلى متجرك.';

  @override
  String get subscriptionDetails => 'اذكر هذه البيانات عند التواصل:';

  @override
  String subscriptionStoreLine(String store) {
    return 'المتجر: $store';
  }

  @override
  String subscriptionPhoneLine(String phone) {
    return 'الجوال: $phone';
  }

  @override
  String get subscriptionCopy => 'نسخ البيانات';

  @override
  String get subscriptionCopied => 'نُسخت البيانات.';

  @override
  String get discardTitle => 'تجاهل ما كتبته؟';

  @override
  String get discardBody =>
      'لم يُحفظ هذا الصنف بعد. إذا خرجت الآن ستضيع البيانات التي أدخلتها.';

  @override
  String get discardKeep => 'متابعة الإدخال';

  @override
  String get discardConfirm => 'تجاهل وخروج';

  @override
  String get saleDetailError =>
      'تعذّر تحميل الفاتورة. تحقق من الاتصال ثم أعد المحاولة.';

  @override
  String saleReturnedNote(String amount) {
    return 'أُرجعت بضاعة من هذه الفاتورة بقيمة $amount.';
  }

  @override
  String get moreSectionStore => 'المحل';

  @override
  String get moreStaff => 'الموظفون';

  @override
  String get moreStaffSub => 'دعوة موظف، تغيير الدور، الإيقاف';

  @override
  String get moreStoreInfo => 'بيانات المحل';

  @override
  String get moreStoreInfoSub => 'الاسم والهاتف والعنوان على الإيصال';

  @override
  String get moreSectionStock => 'البضاعة والكميات';

  @override
  String get moreLowStock => 'بضاعة قرّبت تخلص';

  @override
  String get moreLowStockSub => 'عند الحد الأدنى أو أقل';

  @override
  String get moreNegative => 'مخزون سالب للمراجعة';

  @override
  String get moreNegativeSub => 'بيعت بأكثر من الكمية المسجّلة';

  @override
  String get moreSectionSales => 'المبيعات';

  @override
  String get moreSalesHistory => 'سجل المبيعات';

  @override
  String get moreSalesHistorySub => 'كل الفواتير، وفتح أي فاتورة كاملة';

  @override
  String get moreSectionSettings => 'الإعدادات';

  @override
  String get morePassword => 'تغيير كلمة المرور';

  @override
  String get morePasswordSub => 'ويُسجَّل الخروج من الأجهزة الأخرى';

  @override
  String get moreSubscription => 'الاشتراك';

  @override
  String moreSubTrialUntil(String date) {
    return 'تجربة مجانية حتى $date';
  }

  @override
  String moreSubActiveUntil(String date) {
    return 'مفعّل حتى $date';
  }

  @override
  String get moreSubActive => 'مفعّل';

  @override
  String get moreSubContact => 'تواصل مع إدارة حسبة عبر واتساب';

  @override
  String moreSubWhatsappText(String store) {
    return 'مرحباً، بخصوص اشتراك متجر «$store» على حسبة.';
  }

  @override
  String get staffTitle => 'الموظفون';

  @override
  String get staffInvite => 'دعوة موظف';

  @override
  String get staffEmpty => 'لا موظفين بعد. ادعُ أول موظف برابط يفتحه من جواله.';

  @override
  String get staffYou => 'أنت';

  @override
  String get staffInactive => 'موقوف';

  @override
  String get staffMakeManager => 'جعله مديراً';

  @override
  String get staffMakeEmployee => 'جعله موظفاً';

  @override
  String get staffDeactivate => 'إيقاف الموظف';

  @override
  String staffDeactivateTitle(String name) {
    return 'إيقاف $name؟';
  }

  @override
  String get staffDeactivateBody =>
      'يُسجَّل خروجه من كل الأجهزة فوراً ولن يستطيع الدخول. فواتيره ودفعاته تبقى باسمه في السجل.';

  @override
  String get staffRolesNote =>
      'المدير: كل شيء عدا الموظفين وبيانات المحل. الموظف: البيع والزبائن وتسجيل الدفعات، بلا مرتجع أو إلغاء فاتورة أو تعديل مخزون أو تجاوز حد الدين.';

  @override
  String get staffLoadError =>
      'تعذّر تحميل الموظفين. تحقق من الاتصال ثم أعد المحاولة.';

  @override
  String get staffActionError =>
      'تعذّر تنفيذ الإجراء. تحقق من الاتصال ثم حاول مرة أخرى.';

  @override
  String get staffOwnerOnly => 'إدارة الموظفين للمالك فقط.';

  @override
  String staffRoleChanged(String name, String role) {
    return 'أصبح $name $role.';
  }

  @override
  String staffDeactivated(String name) {
    return 'أُوقف $name.';
  }

  @override
  String get inviteRole => 'الدور';

  @override
  String get inviteValid => 'صلاحية الرابط';

  @override
  String get invite24h => '24 ساعة';

  @override
  String get invite3d => '3 أيام';

  @override
  String get invite7d => '7 أيام';

  @override
  String get inviteCreate => 'إنشاء رابط الدعوة';

  @override
  String get inviteCreating => 'جارٍ الإنشاء…';

  @override
  String get inviteReady =>
      'الدعوة جاهزة. أرسل الرابط إلى الموظف؛ يظهر هنا مرة واحدة فقط.';

  @override
  String inviteExpires(String date) {
    return 'ينتهي في $date';
  }

  @override
  String get inviteHowTo =>
      'يفتح الموظف الرابط، يكتب اسمه وبريده وكلمة مرور، ثم يدخل من تطبيق حسبة.';

  @override
  String get inviteCopy => 'نسخ الرابط';

  @override
  String get inviteCopied => 'نُسخ الرابط.';

  @override
  String get inviteWhatsapp => 'إرسال عبر واتساب';

  @override
  String inviteWhatsappText(String store, String role, String link) {
    return 'دعوة للانضمام إلى متجر «$store» على حسبة كـ$role. افتح الرابط وأنشئ حسابك:\n$link';
  }

  @override
  String get inviteWhatsappFailed =>
      'تعذّر فتح واتساب. انسخ الرابط وأرسله بأي طريقة.';

  @override
  String get inviteDone => 'تم';

  @override
  String get storeTitle => 'بيانات المحل';

  @override
  String get storeName => 'اسم المحل';

  @override
  String get storePhone => 'هاتف المحل';

  @override
  String get storePhoneHint => 'هاتف المحل على الإيصال، مثل 0599123456';

  @override
  String get storeAddress => 'العنوان';

  @override
  String get storeArea => 'المنطقة أو المدينة';

  @override
  String get storeReceiptNote => 'تظهر هذه البيانات أعلى كل إيصال.';

  @override
  String get storeSave => 'حفظ التغييرات';

  @override
  String get storeSaved => 'حُفظت بيانات المحل.';

  @override
  String get storeOwnerOnly => 'تعديل بيانات المحل للمالك فقط.';

  @override
  String get storeLoadError =>
      'تعذّر تحميل بيانات المحل. تحقق من الاتصال ثم أعد المحاولة.';

  @override
  String get pwTitle => 'تغيير كلمة المرور';

  @override
  String get pwCurrent => 'كلمة المرور الحالية';

  @override
  String get pwNew => 'كلمة المرور الجديدة';

  @override
  String get pwConfirm => 'تأكيد كلمة المرور الجديدة';

  @override
  String get pwHelp => '8 أحرف على الأقل، والأجهزة الأخرى تُسجَّل خارجاً';

  @override
  String get pwSave => 'تغيير كلمة المرور';

  @override
  String get pwDone => 'تم تغيير كلمة المرور، وسُجّل الخروج من الأجهزة الأخرى.';

  @override
  String get pwCurrentRequired => 'اكتب كلمة المرور الحالية.';

  @override
  String get pwShort => 'كلمة المرور 8 أحرف على الأقل.';

  @override
  String get pwMismatch => 'تأكيد كلمة المرور لا يطابقها.';

  @override
  String get salesTitle => 'سجل المبيعات';

  @override
  String get salesToday => 'اليوم';

  @override
  String get sales7 => 'آخر 7 أيام';

  @override
  String get sales30 => 'آخر 30 يوماً';

  @override
  String get salesAll => 'الكل';

  @override
  String get salesEmpty => 'لا مبيعات في هذه الفترة.';

  @override
  String get salesLoadError =>
      'تعذّر تحميل المبيعات. تحقق من الاتصال ثم أعد المحاولة.';

  @override
  String get salesMore => 'عرض المزيد';

  @override
  String get salesMoreError => 'تعذّر تحميل المزيد. اضغط للمحاولة مرة أخرى.';

  @override
  String get salesWalkIn => 'بلا زبون';

  @override
  String salesItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صنف',
      many: '$count صنفاً',
      few: '$count أصناف',
      two: 'صنفان',
      one: 'صنف واحد',
    );
    return '$_temp0';
  }

  @override
  String get saleStatusPaid => 'مدفوعة';

  @override
  String get saleStatusCredit => 'دين';

  @override
  String get saleStatusPartial => 'دفع جزئي';

  @override
  String get prodDetailError =>
      'تعذّر تحميل الصنف. تحقق من الاتصال ثم أعد المحاولة.';

  @override
  String get prodStockNowLabel => 'الكمية الموجودة الآن';

  @override
  String prodMinimumLabel(String qty) {
    return 'تنبيه عند $qty';
  }

  @override
  String prodCostLabel(String price) {
    return 'التكلفة $price';
  }

  @override
  String prodPackLabel(int size, String price) {
    return 'كرتونة $size قطعة بـ $price';
  }

  @override
  String get prodEdit => 'تعديل الصنف';

  @override
  String get prodAdjust => 'جرد أو تعديل الكمية';

  @override
  String get prodMovements => 'حركات البضاعة';

  @override
  String get prodNoMovements => 'لا حركات بعد.';

  @override
  String get prodDeactivate => 'إيقاف الصنف';

  @override
  String prodDeactivateTitle(String name) {
    return 'إيقاف «$name»؟';
  }

  @override
  String get prodDeactivateBody =>
      'لن يظهر في البيع ولا في قائمة البضاعة. حركاته وفواتيره السابقة تبقى في السجل، وتستطيع إعادته متى شئت من «موقوفة».';

  @override
  String prodDeactivated(String name) {
    return 'أُوقف «$name».';
  }

  @override
  String get prodInactiveNote =>
      'هذا الصنف موقوف: لا يُباع ولا يظهر في القائمة.';

  @override
  String get prodFilterInactive => 'موقوفة';

  @override
  String get prodReactivate => 'إعادة تفعيل الصنف';

  @override
  String get prodReactivated => 'رجع الصنف إلى البيع والقائمة كما كان.';

  @override
  String get invOpenProduct => 'تعديل السعر والتفاصيل';

  @override
  String get prodSaved => 'حُفظت التعديلات.';

  @override
  String get prodViewOnly => 'تعديل البضاعة والكمية للمالك أو المدير.';

  @override
  String get moveOpening => 'رصيد افتتاحي';

  @override
  String get moveSale => 'بيع';

  @override
  String get moveVoid => 'إلغاء فاتورة';

  @override
  String get moveReturn => 'مرتجع';

  @override
  String get moveIn => 'تعديل: زيادة';

  @override
  String get moveOut => 'تعديل: خصم';

  @override
  String moveAfter(String qty) {
    return 'بعدها $qty';
  }

  @override
  String adjTitle(String name) {
    return 'تعديل كمية «$name»';
  }

  @override
  String get adjCount => 'جرد الرف';

  @override
  String get adjDelta => 'إضافة أو خصم';

  @override
  String get adjCartons => 'استلام كراتين';

  @override
  String adjCountLabel(String unit) {
    return 'كم يوجد الآن فعلياً؟ ($unit)';
  }

  @override
  String adjDeltaLabel(String unit) {
    return 'الكمية ($unit)، بإشارة سالبة للخصم';
  }

  @override
  String adjCartonsLabel(int size) {
    return 'عدد الكراتين المستلمة ($size قطعة لكل كرتونة)';
  }

  @override
  String get adjReason => 'السبب';

  @override
  String get adjReasonCount => 'جرد الرف';

  @override
  String get adjReasonDamaged => 'تالف أو منتهي الصلاحية';

  @override
  String get adjReasonReceived => 'استلام بضاعة';

  @override
  String get adjReasonFix => 'تصحيح خطأ إدخال';

  @override
  String adjPreview(String from, String to) {
    return 'المسجّل $from ← بعد التعديل $to';
  }

  @override
  String get adjNoChange => 'العدد مطابق للمسجّل؛ لا شيء لتعديله.';

  @override
  String get adjNegative => 'المخزون لا يصبح سالباً بالتعديل.';

  @override
  String get adjInvalidPiece => 'عدد صحيح للصنف بالقطعة.';

  @override
  String get adjInvalidKg => 'حتى 3 خانات عشرية.';

  @override
  String get adjSave => 'حفظ التعديل';

  @override
  String adjDone(String stock) {
    return 'تعدّلت الكمية. صارت $stock';
  }

  @override
  String get lowTitle => 'بضاعة قرّبت تخلص';

  @override
  String get lowEmpty => 'كل البضاعة فوق حد التنبيه.';

  @override
  String lowRow(String stock, String min) {
    return 'الكمية $stock · التنبيه عند $min';
  }

  @override
  String get negTitle => 'مخزون سالب للمراجعة';

  @override
  String get negEmpty => 'لا أصناف بمخزون سالب.';

  @override
  String get negHelp =>
      'بيعت هذه البضاعة بأكثر مما هو مسجّل. عُدّ الرف ثم صحّح المخزون من صفحة الصنف.';

  @override
  String negSale(int id, String qty) {
    return 'فاتورة #$id · $qty';
  }

  @override
  String get listLoadError => 'تعذّر التحميل. تحقق من الاتصال ثم أعد المحاولة.';

  @override
  String get legacyAction => 'تسجيل دين قديم';

  @override
  String get legacyActionSub =>
      'دين على زبون من قبل ما تستعمل حسبة، من دفترك القديم';

  @override
  String get legacyTitle => 'تسجيل دين قديم';

  @override
  String get legacyIntro =>
      'بيتسجّل كدين على الزبون بس: ما بينحسب بيع، وما بينقص من البضاعة، وما بيدخل الصندوق.';

  @override
  String get legacyCustomer => 'الزبون';

  @override
  String get legacyPickCustomer => 'اختر الزبون';

  @override
  String get legacyChange => 'تغيير';

  @override
  String get legacyAmount => 'المبلغ اللي عليه';

  @override
  String get legacyAmountHint => 'مثلاً 150';

  @override
  String get legacyAmountInvalid =>
      'اكتب مبلغ صحيح أكبر من صفر، وبحد أقصى رقمين بعد الفاصلة.';

  @override
  String get legacyAmountTooBig => 'المبلغ أكبر من المسموح.';

  @override
  String get legacyPartlyPaid =>
      'إذا الزبون دفع جزء منه قبل، اكتب الباقي عليه بس.';

  @override
  String get legacyOrigin => 'تاريخ الدين';

  @override
  String get legacyOriginNone => 'مش محدد';

  @override
  String get legacyDue => 'موعد السداد (اختياري)';

  @override
  String get legacyDueNone => 'بدون موعد';

  @override
  String get legacyNote => 'ملاحظة (اختياري)';

  @override
  String get legacyNoteHint => 'مثلاً: من دفتر الديون القديم';

  @override
  String get legacyClear => 'مسح';

  @override
  String get legacySave => 'تسجيل الدين';

  @override
  String get legacySaving => 'جارٍ التسجيل…';

  @override
  String get legacyRetry => 'أعد المحاولة';

  @override
  String get legacyUncertain =>
      'انقطع الاتصال قبل ما يوصل رد الخادم، ويمكن يكون الدين تسجّل. اضغط «أعد المحاولة» وما رح يتسجّل مرتين.';

  @override
  String get legacyConfirmTitle => 'تأكيد الدين القديم';

  @override
  String legacyConfirmBody(String name, String amount) {
    return 'رح يتسجّل على $name دين قديم بقيمة $amount. بتقدر تعدّله أو تحذفه لاحقاً من لوحة الويب.';
  }

  @override
  String get legacyConfirmOk => 'نعم، سجّل';

  @override
  String get legacyBack => 'رجوع';

  @override
  String get legacyDone => 'تسجّل الدين القديم';

  @override
  String legacyDoneBody(String name, String amount) {
    return 'صار على $name دين قديم بقيمة $amount.';
  }

  @override
  String get legacyDoneButton => 'تمام';

  @override
  String get legacyForbidden => 'تسجيل الديون القديمة للمالك أو المدير.';

  @override
  String legacySince(String date) {
    return 'من $date';
  }

  @override
  String get offlineSavedBanner =>
      'لا يوجد اتصال — البيع والدفعات تُحفظ على الهاتف وتُرسل عند عودة الإنترنت';

  @override
  String offlineSavedBannerCount(int count) {
    return 'لا يوجد اتصال — $count عملية محفوظة على الهاتف بانتظار الإرسال';
  }

  @override
  String get syncSynced => 'متزامن';

  @override
  String get syncSyncing => 'جارٍ المزامنة…';

  @override
  String syncPending(int count) {
    return 'بانتظار المزامنة ($count)';
  }

  @override
  String syncOfflinePending(int count) {
    return 'غير متصل · $count';
  }

  @override
  String syncNeedsReview(int count) {
    return 'يحتاج مراجعة ($count)';
  }

  @override
  String get syncNow => 'مزامنة الآن';

  @override
  String get syncTitle => 'المزامنة';

  @override
  String syncOfflineTitle(int count) {
    return 'لا يوجد اتصال · $count عملية بانتظار الإرسال';
  }

  @override
  String get syncAllSent => 'كل العمليات وصلت إلى الخادم';

  @override
  String syncStuck(int count) {
    return '$count عملية تعذّر إرسالها عدة مرات. تواصل مع الدعم إن استمر ذلك.';
  }

  @override
  String syncHeldTitle(int count) {
    return 'أوقفها الخادم للمراجعة ($count)';
  }

  @override
  String get syncHeldHelp =>
      'لم تُحذف. يراجعها المالك أو المدير من موقع حسبة على الويب.';

  @override
  String get syncHeldPayment => 'الدفعة أكبر من رصيد العميل الآن على الخادم.';

  @override
  String get syncHeldClock =>
      'وقت العملية خارج المدة المسموحة. راجع ساعة الهاتف.';

  @override
  String get syncPendingTitle => 'بانتظار الإرسال';

  @override
  String get syncNothingPending => 'لا شيء بانتظار الإرسال.';

  @override
  String get syncItemSale => 'بيع';

  @override
  String get syncItemCreditSale => 'بيع بالدين';

  @override
  String get syncItemPayment => 'دفعة';

  @override
  String syncItemStuck(int count) {
    return 'تعذّر الإرسال $count مرة';
  }

  @override
  String queueWarnBody(int count, int limit) {
    return '$count عملية بانتظار المزامنة من أصل $limit. اتصل بالإنترنت وزامن الآن.';
  }

  @override
  String get queueFullTitle =>
      'امتلأت قائمة الانتظار — لا يمكن حفظ بيع أو دفعة جديدة دون اتصال';

  @override
  String get queueFullBody =>
      'على الهاتف 1000 عملية لم تُرسل بعد. اتصل بالإنترنت لإرسالها، ثم تابع. البحث والعرض يعملان.';

  @override
  String get receiptPendingNote =>
      'محفوظ على الهاتف بانتظار الإرسال. يُرسل تلقائيًا عند عودة الإنترنت.';

  @override
  String get receiptLocalRef => 'رقم مؤقت';

  @override
  String payPendingNote(String ref) {
    return 'محفوظة على الهاتف ($ref) وتُرسل عند عودة الإنترنت.';
  }

  @override
  String logoutPendingTitle(int count) {
    return '$count عملية لم تُرسل بعد';
  }

  @override
  String get logoutPendingBody =>
      'لا يمكن تسجيل الخروج قبل إرسالها، حتى لا تضيع ولا تُنسب لحساب آخر.';

  @override
  String get formByCarton => 'بالكرتونة';

  @override
  String get cartonsLabel => 'عدد الكراتين عندك';

  @override
  String get cartonsHint => 'كم كرتونة على الرف';

  @override
  String get looseLabel => 'قطع زيادة';

  @override
  String get looseHint => 'من كرتونة مفتوحة';

  @override
  String get cartonPriceLabel => 'سعر الكرتونة (جملة)';

  @override
  String get piecePriceLabel => 'سعر القطعة الواحدة';

  @override
  String cartonTotal(int total) {
    return 'المجموع: $total قطعة';
  }

  @override
  String get cartonsInvalid => 'أدخل عدداً صحيحاً، 0 أو أكثر.';

  @override
  String looseTooMany(int size) {
    return 'القطع الزيادة أقل من $size؛ وإلا فهي كرتونة كاملة.';
  }

  @override
  String get prodColName => 'المنتج';

  @override
  String get prodColCartons => 'الكراتين';

  @override
  String get prodColPieces => 'عدد القطع';

  @override
  String get prodColPrice => 'سعر القطعة';

  @override
  String cartonsCell(int count) {
    return '$count كرتونة';
  }

  @override
  String cartonsCellLoose(int count, int pieces) {
    return '$count كرتونة + $pieces قطعة';
  }

  @override
  String get loginPhoneLabel => 'رقم الجوال';

  @override
  String get phLoginPhone => 'مثل 0599123456';

  @override
  String get loginForgot => 'نسيت كلمة المرور؟';

  @override
  String get ownerPhoneLabel => 'رقم جوالك (تسجّل الدخول به)';

  @override
  String get otpTitle => 'رمز التأكيد';

  @override
  String otpSentTo(String phone) {
    return 'أرسلنا رمزاً من 6 أرقام برسالة إلى $phone.';
  }

  @override
  String get otpCodeLabel => 'الرمز';

  @override
  String get phOtpCode => '6 أرقام';

  @override
  String get otpCodeInvalid => 'الرمز 6 أرقام.';

  @override
  String get otpResend => 'أرسل رمزاً جديداً';

  @override
  String otpResendIn(int seconds) {
    return 'رمز جديد بعد $seconds ث';
  }

  @override
  String get otpChangeNumber => 'تعديل الرقم';

  @override
  String get otpSend => 'أرسل الرمز';

  @override
  String get otpDailyLimit =>
      'توقّفت رسائل الرمز لليوم. حاول غداً أو تواصل مع الدعم.';

  @override
  String get otpSendFailed => 'تعذّر إرسال الرسالة الآن. حاول بعد قليل.';

  @override
  String get otpUnavailable => 'رسائل الرمز غير متاحة الآن.';

  @override
  String get registerConfirmCode => 'تأكيد الرمز وإنشاء المتجر';

  @override
  String get resetTitle => 'استعادة كلمة المرور';

  @override
  String get resetHelper =>
      'اكتب رقم جوالك، ونرسل لك رمزاً برسالة لتختار كلمة مرور جديدة.';

  @override
  String get resetSave => 'حفظ كلمة المرور الجديدة';

  @override
  String get resetDone =>
      'تم تغيير كلمة المرور. سجّل الدخول برقم جوالك وكلمة المرور الجديدة.';

  @override
  String get morePhone => 'رقم الجوال للدخول';

  @override
  String get morePhoneAdd => 'أضف رقم جوالك لتدخل به';

  @override
  String get phoneTitle => 'رقم الجوال للدخول';

  @override
  String get phoneHelper => 'تسجّل الدخول بهذا الرقم وكلمة مرورك.';

  @override
  String get phoneNewLabel => 'رقم الجوال';

  @override
  String get phoneSave => 'حفظ الرقم';

  @override
  String get phoneDone => 'تم حفظ الرقم. سجّل الدخول به من الآن.';
}
