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
}
