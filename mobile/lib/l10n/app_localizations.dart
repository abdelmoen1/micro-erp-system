import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'حسبة'**
  String get appTitle;

  /// No description provided for @loading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحميل…'**
  String get loading;

  /// No description provided for @splashTagline.
  ///
  /// In ar, this message translates to:
  /// **'دفتر متجرك، في جيبك'**
  String get splashTagline;

  /// No description provided for @splashSubline.
  ///
  /// In ar, this message translates to:
  /// **'المبيعات والديون والمخزون في مكان واحد'**
  String get splashSubline;

  /// No description provided for @splashChecking.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحقق من الجلسة'**
  String get splashChecking;

  /// No description provided for @loginTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get loginTitle;

  /// No description provided for @loginHelper.
  ///
  /// In ar, this message translates to:
  /// **'أدخل بيانات حسابك في المتجر'**
  String get loginHelper;

  /// No description provided for @emailLabel.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get passwordLabel;

  /// No description provided for @showPassword.
  ///
  /// In ar, this message translates to:
  /// **'إظهار'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء'**
  String get hidePassword;

  /// No description provided for @showPasswordA11y.
  ///
  /// In ar, this message translates to:
  /// **'إظهار كلمة المرور'**
  String get showPasswordA11y;

  /// No description provided for @hidePasswordA11y.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء كلمة المرور'**
  String get hidePasswordA11y;

  /// No description provided for @loginButton.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get loginButton;

  /// No description provided for @loginSubmitting.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تسجيل الدخول…'**
  String get loginSubmitting;

  /// No description provided for @emailRequired.
  ///
  /// In ar, this message translates to:
  /// **'أدخل البريد الإلكتروني'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In ar, this message translates to:
  /// **'صيغة البريد الإلكتروني غير صحيحة'**
  String get emailInvalid;

  /// No description provided for @passwordRequired.
  ///
  /// In ar, this message translates to:
  /// **'أدخل كلمة المرور'**
  String get passwordRequired;

  /// No description provided for @invalidCredentials.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني أو كلمة المرور غير صحيحة.'**
  String get invalidCredentials;

  /// No description provided for @tooManyAttempts.
  ///
  /// In ar, this message translates to:
  /// **'محاولات كثيرة. يمكنك المحاولة بعد'**
  String get tooManyAttempts;

  /// No description provided for @loginButtonWait.
  ///
  /// In ar, this message translates to:
  /// **'انتظر {time}'**
  String loginButtonWait(String time);

  /// No description provided for @networkError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال بالخادم. تحقق من الإنترنت ثم أعد المحاولة.'**
  String get networkError;

  /// No description provided for @serverError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ في الخادم. أعد المحاولة بعد قليل.'**
  String get serverError;

  /// No description provided for @serverReference.
  ///
  /// In ar, this message translates to:
  /// **'رمز المرجع: {reference}'**
  String serverReference(String reference);

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @sessionExpired.
  ///
  /// In ar, this message translates to:
  /// **'انتهت الجلسة. سجّل الدخول للمتابعة.'**
  String get sessionExpired;

  /// No description provided for @accountInactive.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحساب موقوف. تواصل مع مالك المتجر لإعادة تفعيله.'**
  String get accountInactive;

  /// No description provided for @storeRequired.
  ///
  /// In ar, this message translates to:
  /// **'الحساب غير مرتبط بمتجر. تواصل مع الدعم لربط حسابك بمتجر.'**
  String get storeRequired;

  /// No description provided for @forbidden.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك صلاحية لهذا الإجراء.'**
  String get forbidden;

  /// No description provided for @tabHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get tabHome;

  /// No description provided for @tabPos.
  ///
  /// In ar, this message translates to:
  /// **'بيع'**
  String get tabPos;

  /// No description provided for @tabCustomers.
  ///
  /// In ar, this message translates to:
  /// **'الزبائن'**
  String get tabCustomers;

  /// No description provided for @tabProducts.
  ///
  /// In ar, this message translates to:
  /// **'المنتجات'**
  String get tabProducts;

  /// No description provided for @tabMore.
  ///
  /// In ar, this message translates to:
  /// **'المزيد'**
  String get tabMore;

  /// No description provided for @sellA11y.
  ///
  /// In ar, this message translates to:
  /// **'بيع'**
  String get sellA11y;

  /// No description provided for @sellCurrentA11y.
  ///
  /// In ar, this message translates to:
  /// **'بيع — أنت في شاشة البيع'**
  String get sellCurrentA11y;

  /// No description provided for @online.
  ///
  /// In ar, this message translates to:
  /// **'متصل'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In ar, this message translates to:
  /// **'غير متصل'**
  String get offline;

  /// No description provided for @offlineBanner.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال — البيع يحتاج إلى الإنترنت'**
  String get offlineBanner;

  /// No description provided for @placeholderHome.
  ///
  /// In ar, this message translates to:
  /// **'لوحة اليوم — شاشة هبوط المالك والمدير'**
  String get placeholderHome;

  /// No description provided for @placeholderCustomers.
  ///
  /// In ar, this message translates to:
  /// **'قائمة الزبائن'**
  String get placeholderCustomers;

  /// No description provided for @placeholderProducts.
  ///
  /// In ar, this message translates to:
  /// **'المنتجات والمخزون المنخفض'**
  String get placeholderProducts;

  /// No description provided for @placeholderPos.
  ///
  /// In ar, this message translates to:
  /// **'سلة البيع — شاشة هبوط الموظف'**
  String get placeholderPos;

  /// No description provided for @placeholderBody.
  ///
  /// In ar, this message translates to:
  /// **'محتوى هذه الشاشة يُصمَّم في S4 (US-1508). هنا يظهر فقط إطار التطبيق: الرأس، حالة الاتصال، وشريط التنقل.'**
  String get placeholderBody;

  /// No description provided for @placeholderPosBody.
  ///
  /// In ar, this message translates to:
  /// **'المسح والسلة والدفع تُبنى في مرحلة لاحقة (S5). هنا يظهر فقط إطار التطبيق.'**
  String get placeholderPosBody;

  /// No description provided for @roleOwner.
  ///
  /// In ar, this message translates to:
  /// **'مالك'**
  String get roleOwner;

  /// No description provided for @roleManager.
  ///
  /// In ar, this message translates to:
  /// **'مدير'**
  String get roleManager;

  /// No description provided for @roleEmployee.
  ///
  /// In ar, this message translates to:
  /// **'موظف'**
  String get roleEmployee;

  /// No description provided for @moreNote.
  ///
  /// In ar, this message translates to:
  /// **'«المزيد» يحتوي الملف الشخصي وتسجيل الخروج فقط في R1. إدارة الموظفين على الويب.'**
  String get moreNote;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج؟'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'ستحتاج إلى البريد الإلكتروني وكلمة المرور للدخول مجدداً.'**
  String get logoutConfirmBody;

  /// No description provided for @stay.
  ///
  /// In ar, this message translates to:
  /// **'البقاء'**
  String get stay;

  /// No description provided for @homeGreeting.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً، {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeTodaySales.
  ///
  /// In ar, this message translates to:
  /// **'مبيعات اليوم'**
  String get homeTodaySales;

  /// No description provided for @homeInvoicesCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا فواتير بعد} =1{فاتورة واحدة} =2{فاتورتان} few{{count} فواتير} other{{count} فاتورة}}'**
  String homeInvoicesCount(int count);

  /// No description provided for @homeCash.
  ///
  /// In ar, this message translates to:
  /// **'نقدي'**
  String get homeCash;

  /// No description provided for @homeCredit.
  ///
  /// In ar, this message translates to:
  /// **'آجل (دين)'**
  String get homeCredit;

  /// No description provided for @homeCollectedToday.
  ///
  /// In ar, this message translates to:
  /// **'تحصيل اليوم'**
  String get homeCollectedToday;

  /// No description provided for @homeOutstandingDebts.
  ///
  /// In ar, this message translates to:
  /// **'ديون مستحقة'**
  String get homeOutstandingDebts;

  /// No description provided for @homeCustomersWithDebt.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا زبائن مدينون} =1{زبون واحد مدين} =2{زبونان مدينان} few{{count} زبائن مدينون} other{{count} زبون مدين}}'**
  String homeCustomersWithDebt(int count);

  /// No description provided for @homeShortcuts.
  ///
  /// In ar, this message translates to:
  /// **'اختصارات'**
  String get homeShortcuts;

  /// No description provided for @homeNewSale.
  ///
  /// In ar, this message translates to:
  /// **'بيع جديد'**
  String get homeNewSale;

  /// No description provided for @homeRecentInvoices.
  ///
  /// In ar, this message translates to:
  /// **'آخر فواتير اليوم'**
  String get homeRecentInvoices;

  /// No description provided for @homeNoInvoices.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد فواتير اليوم بعد'**
  String get homeNoInvoices;

  /// No description provided for @homeNoInvoicesBody.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ أول عملية بيع من زر «بيع» في الأسفل.'**
  String get homeNoInvoicesBody;

  /// No description provided for @homeWalkIn.
  ///
  /// In ar, this message translates to:
  /// **'زبون نقدي'**
  String get homeWalkIn;

  /// No description provided for @homeLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل لوحة اليوم.'**
  String get homeLoadError;

  /// No description provided for @currencySymbol.
  ///
  /// In ar, this message translates to:
  /// **'₪'**
  String get currencySymbol;

  /// No description provided for @scanEntryTitle.
  ///
  /// In ar, this message translates to:
  /// **'عرض بيانات منتج'**
  String get scanEntryTitle;

  /// No description provided for @scanEntryBody.
  ///
  /// In ar, this message translates to:
  /// **'الاسم والسعر والمخزون. للعرض فقط، لا يُضاف إلى بيع.'**
  String get scanEntryBody;

  /// No description provided for @scanBarcode.
  ///
  /// In ar, this message translates to:
  /// **'مسح باركود'**
  String get scanBarcode;

  /// No description provided for @scanCloseA11y.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق الماسح والرجوع إلى البيع'**
  String get scanCloseA11y;

  /// No description provided for @scanTorchOnA11y.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل الإضاءة'**
  String get scanTorchOnA11y;

  /// No description provided for @scanTorchOffA11y.
  ///
  /// In ar, this message translates to:
  /// **'إطفاء الإضاءة'**
  String get scanTorchOffA11y;

  /// No description provided for @scanInstruction.
  ///
  /// In ar, this message translates to:
  /// **'وجّه الباركود داخل الإطار'**
  String get scanInstruction;

  /// No description provided for @scanRead.
  ///
  /// In ar, this message translates to:
  /// **'تمت القراءة'**
  String get scanRead;

  /// No description provided for @scanPaused.
  ///
  /// In ar, this message translates to:
  /// **'المسح متوقف'**
  String get scanPaused;

  /// No description provided for @scanSearchingCode.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ البحث عن باركود…'**
  String get scanSearchingCode;

  /// No description provided for @scanSearchingProduct.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ البحث عن المنتج…'**
  String get scanSearchingProduct;

  /// No description provided for @scanHintTitle.
  ///
  /// In ar, this message translates to:
  /// **'صعب القراءة؟'**
  String get scanHintTitle;

  /// No description provided for @scanHintBody.
  ///
  /// In ar, this message translates to:
  /// **'قرّب الباركود ببطء، أمِل المنتج لتجنب اللمعان، وشغّل الإضاءة. أو أدخله يدويًا.'**
  String get scanHintBody;

  /// No description provided for @scanManual.
  ///
  /// In ar, this message translates to:
  /// **'إدخال الباركود يدويًا'**
  String get scanManual;

  /// No description provided for @scanFound.
  ///
  /// In ar, this message translates to:
  /// **'تم العثور على المنتج'**
  String get scanFound;

  /// No description provided for @scanPrice.
  ///
  /// In ar, this message translates to:
  /// **'سعر البيع'**
  String get scanPrice;

  /// No description provided for @scanStock.
  ///
  /// In ar, this message translates to:
  /// **'المخزون الحالي'**
  String get scanStock;

  /// No description provided for @scanBarcodeLabel.
  ///
  /// In ar, this message translates to:
  /// **'الباركود'**
  String get scanBarcodeLabel;

  /// No description provided for @scanAnother.
  ///
  /// In ar, this message translates to:
  /// **'مسح منتج آخر'**
  String get scanAnother;

  /// No description provided for @scanBackToSale.
  ///
  /// In ar, this message translates to:
  /// **'الرجوع إلى البيع'**
  String get scanBackToSale;

  /// No description provided for @scanNotFoundTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد منتج بهذا الباركود'**
  String get scanNotFoundTitle;

  /// No description provided for @scanNotFoundBody.
  ///
  /// In ar, this message translates to:
  /// **'تأكد من الرقم أو امسحه مرة أخرى.'**
  String get scanNotFoundBody;

  /// No description provided for @scanAgain.
  ///
  /// In ar, this message translates to:
  /// **'مسح مرة أخرى'**
  String get scanAgain;

  /// No description provided for @scanDeniedTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن المسح بدون الكاميرا'**
  String get scanDeniedTitle;

  /// No description provided for @scanDeniedBody.
  ///
  /// In ar, this message translates to:
  /// **'تحتاج حِسبة إلى الكاميرا لقراءة الباركود فقط أثناء المسح. يمكنك السماح الآن أو إدخال الرقم يدويًا.'**
  String get scanDeniedBody;

  /// No description provided for @scanAllowCamera.
  ///
  /// In ar, this message translates to:
  /// **'السماح بالكاميرا'**
  String get scanAllowCamera;

  /// No description provided for @scanBlockedBody.
  ///
  /// In ar, this message translates to:
  /// **'إذن الكاميرا مرفوض. فعّله من إعدادات الهاتف لقراءة الباركود، أو أدخل الرقم يدويًا.'**
  String get scanBlockedBody;

  /// No description provided for @scanBlockedPath.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات ← التطبيقات ← حِسبة ← الأذونات ←'**
  String get scanBlockedPath;

  /// No description provided for @scanBlockedPathCamera.
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا'**
  String get scanBlockedPathCamera;

  /// No description provided for @scanBlockedPathAllow.
  ///
  /// In ar, this message translates to:
  /// **'← السماح أثناء استخدام التطبيق'**
  String get scanBlockedPathAllow;

  /// No description provided for @scanOpenSettings.
  ///
  /// In ar, this message translates to:
  /// **'فتح الإعدادات'**
  String get scanOpenSettings;

  /// No description provided for @manualLabel.
  ///
  /// In ar, this message translates to:
  /// **'رقم الباركود'**
  String get manualLabel;

  /// No description provided for @manualHint.
  ///
  /// In ar, this message translates to:
  /// **'الأرقام أسفل الخطوط'**
  String get manualHint;

  /// No description provided for @manualHelper.
  ///
  /// In ar, this message translates to:
  /// **'اكتب الأرقام كما تظهر تحت خطوط الباركود.'**
  String get manualHelper;

  /// No description provided for @manualEmpty.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم الباركود'**
  String get manualEmpty;

  /// No description provided for @manualSubmit.
  ///
  /// In ar, this message translates to:
  /// **'عرض المنتج'**
  String get manualSubmit;

  /// No description provided for @manualCancelA11y.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الإدخال اليدوي'**
  String get manualCancelA11y;

  /// No description provided for @lookupFailedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر عرض المنتج'**
  String get lookupFailedTitle;

  /// No description provided for @lookupSavedForRetry.
  ///
  /// In ar, this message translates to:
  /// **'محفوظ لإعادة المحاولة.'**
  String get lookupSavedForRetry;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
