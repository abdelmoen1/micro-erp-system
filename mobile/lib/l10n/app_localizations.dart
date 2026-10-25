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

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @backWord.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get backWord;

  /// No description provided for @searchByName.
  ///
  /// In ar, this message translates to:
  /// **'بحث بالاسم'**
  String get searchByName;

  /// No description provided for @scanShort.
  ///
  /// In ar, this message translates to:
  /// **'مسح'**
  String get scanShort;

  /// No description provided for @totalWord.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get totalWord;

  /// No description provided for @payButton.
  ///
  /// In ar, this message translates to:
  /// **'الدفع'**
  String get payButton;

  /// No description provided for @linesCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا أصناف} =1{صنف واحد} =2{صنفان} few{{count} أصناف} many{{count} صنفاً} other{{count} صنف}}'**
  String linesCount(int count);

  /// No description provided for @scanLookingUp.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ البحث عن المنتج…'**
  String get scanLookingUp;

  /// No description provided for @barcodeWord.
  ///
  /// In ar, this message translates to:
  /// **'الباركود'**
  String get barcodeWord;

  /// No description provided for @scanAdded.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف إلى السلة'**
  String get scanAdded;

  /// No description provided for @scanIncremented.
  ///
  /// In ar, this message translates to:
  /// **'+1 · {name}'**
  String scanIncremented(String name);

  /// No description provided for @scanQuantityNow.
  ///
  /// In ar, this message translates to:
  /// **'الكمية الآن {quantity}'**
  String scanQuantityNow(String quantity);

  /// No description provided for @scanAddedWeighed.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف بالوزن'**
  String get scanAddedWeighed;

  /// No description provided for @scanDuplicate.
  ///
  /// In ar, this message translates to:
  /// **'قراءة مكررة — لم تُضف'**
  String get scanDuplicate;

  /// No description provided for @scanDuplicateBody.
  ///
  /// In ar, this message translates to:
  /// **'الباركود نفسه خلال 1.5 ثانية. امسح مجدداً بعد لحظة لإضافة قطعة.'**
  String get scanDuplicateBody;

  /// No description provided for @scanUnknown.
  ///
  /// In ar, this message translates to:
  /// **'باركود غير معروف'**
  String get scanUnknown;

  /// No description provided for @scanUnknownBody.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد منتج بهذا الرقم في متجرك:'**
  String get scanUnknownBody;

  /// No description provided for @scanLookupFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر البحث عن المنتج'**
  String get scanLookupFailed;

  /// No description provided for @scanLookupFailedBody.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من الاتصال ثم أعد المحاولة.'**
  String get scanLookupFailedBody;

  /// No description provided for @cartEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'امسح منتجاً للبدء'**
  String get cartEmptyTitle;

  /// No description provided for @cartEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'أو ابحث عنه بالاسم. المنتجات بالوزن تفتح شاشة إدخال الوزن.'**
  String get cartEmptyBody;

  /// No description provided for @unitChipPiece.
  ///
  /// In ar, this message translates to:
  /// **'قطعة'**
  String get unitChipPiece;

  /// No description provided for @unitChipWeighed.
  ///
  /// In ar, this message translates to:
  /// **'بالوزن'**
  String get unitChipWeighed;

  /// No description provided for @pieceWord.
  ///
  /// In ar, this message translates to:
  /// **'قطعة'**
  String get pieceWord;

  /// No description provided for @piecesWord.
  ///
  /// In ar, this message translates to:
  /// **'قطع'**
  String get piecesWord;

  /// No description provided for @kgShort.
  ///
  /// In ar, this message translates to:
  /// **'كغ'**
  String get kgShort;

  /// No description provided for @gramShort.
  ///
  /// In ar, this message translates to:
  /// **'غ'**
  String get gramShort;

  /// No description provided for @justNew.
  ///
  /// In ar, this message translates to:
  /// **'جديد'**
  String get justNew;

  /// No description provided for @justIncremented.
  ///
  /// In ar, this message translates to:
  /// **'+1 الآن'**
  String get justIncremented;

  /// No description provided for @justAddedWeighed.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف الآن'**
  String get justAddedWeighed;

  /// No description provided for @editWeightOf.
  ///
  /// In ar, this message translates to:
  /// **'تعديل وزن {name}'**
  String editWeightOf(String name);

  /// No description provided for @removeItem.
  ///
  /// In ar, this message translates to:
  /// **'حذف {name}'**
  String removeItem(String name);

  /// No description provided for @decreaseItem.
  ///
  /// In ar, this message translates to:
  /// **'إنقاص {name}'**
  String decreaseItem(String name);

  /// No description provided for @increaseItem.
  ///
  /// In ar, this message translates to:
  /// **'زيادة {name}'**
  String increaseItem(String name);

  /// No description provided for @lineStockNote.
  ///
  /// In ar, this message translates to:
  /// **'المخزون المسجّل {stock} فقط — البيع مسموح ويُسجَّل للمراجعة'**
  String lineStockNote(String stock);

  /// No description provided for @stockWord.
  ///
  /// In ar, this message translates to:
  /// **'المخزون'**
  String get stockWord;

  /// No description provided for @weightTitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الوزن'**
  String get weightTitle;

  /// No description provided for @weightTitleEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الوزن'**
  String get weightTitleEdit;

  /// No description provided for @perKg.
  ///
  /// In ar, this message translates to:
  /// **'لكل كغ'**
  String get perKg;

  /// No description provided for @unitKilogram.
  ///
  /// In ar, this message translates to:
  /// **'كيلوغرام'**
  String get unitKilogram;

  /// No description provided for @unitGram.
  ///
  /// In ar, this message translates to:
  /// **'غرام'**
  String get unitGram;

  /// No description provided for @priceWord.
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get priceWord;

  /// No description provided for @gramsEquals.
  ///
  /// In ar, this message translates to:
  /// **'= {kg} كغ'**
  String gramsEquals(String kg);

  /// No description provided for @weightHintKg.
  ///
  /// In ar, this message translates to:
  /// **'حتى 3 منازل عشرية (1 غ). مثال: 0.750'**
  String get weightHintKg;

  /// No description provided for @weightHintGram.
  ///
  /// In ar, this message translates to:
  /// **'بالغرام، أرقام صحيحة فقط'**
  String get weightHintGram;

  /// No description provided for @weightErrorZero.
  ///
  /// In ar, this message translates to:
  /// **'أدخل وزناً أكبر من صفر'**
  String get weightErrorZero;

  /// No description provided for @weightErrorTooBig.
  ///
  /// In ar, this message translates to:
  /// **'الوزن أكبر من المسموح'**
  String get weightErrorTooBig;

  /// No description provided for @weightCtaEmpty.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الوزن للإضافة'**
  String get weightCtaEmpty;

  /// No description provided for @weightCtaAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة {kg} كغ ·'**
  String weightCtaAdd(String kg);

  /// No description provided for @weightCtaUpdate.
  ///
  /// In ar, this message translates to:
  /// **'تحديث · {kg} كغ ·'**
  String weightCtaUpdate(String kg);

  /// No description provided for @removeFromCart.
  ///
  /// In ar, this message translates to:
  /// **'حذف من السلة'**
  String get removeFromCart;

  /// No description provided for @keyBackspace.
  ///
  /// In ar, this message translates to:
  /// **'حذف آخر رقم'**
  String get keyBackspace;

  /// No description provided for @keyDecimal.
  ///
  /// In ar, this message translates to:
  /// **'فاصلة عشرية'**
  String get keyDecimal;

  /// No description provided for @productSearchTitle.
  ///
  /// In ar, this message translates to:
  /// **'بحث عن منتج'**
  String get productSearchTitle;

  /// No description provided for @productSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث باسم المنتج أو الباركود'**
  String get productSearchHint;

  /// No description provided for @productSearchEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد منتج بهذا الاسم'**
  String get productSearchEmpty;

  /// No description provided for @productSearchEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من الكتابة. المنتجات تُضاف من لوحة الإدارة على الويب.'**
  String get productSearchEmptyBody;

  /// No description provided for @productSearchError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل المنتجات'**
  String get productSearchError;

  /// No description provided for @listErrorBody.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من الاتصال. البيع الحالي محفوظ كما هو.'**
  String get listErrorBody;

  /// No description provided for @checkoutTitle.
  ///
  /// In ar, this message translates to:
  /// **'الدفع'**
  String get checkoutTitle;

  /// No description provided for @checkoutNotCreatedYet.
  ///
  /// In ar, this message translates to:
  /// **'لم تُنشأ الفاتورة بعد'**
  String get checkoutNotCreatedYet;

  /// No description provided for @backToCart.
  ///
  /// In ar, this message translates to:
  /// **'العودة إلى السلة'**
  String get backToCart;

  /// No description provided for @showItems.
  ///
  /// In ar, this message translates to:
  /// **'عرض الأصناف'**
  String get showItems;

  /// No description provided for @hideItems.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء الأصناف'**
  String get hideItems;

  /// No description provided for @editCart.
  ///
  /// In ar, this message translates to:
  /// **'تعديل السلة'**
  String get editCart;

  /// No description provided for @saleModeLabel.
  ///
  /// In ar, this message translates to:
  /// **'طريقة البيع'**
  String get saleModeLabel;

  /// No description provided for @modeCash.
  ///
  /// In ar, this message translates to:
  /// **'كاش كامل'**
  String get modeCash;

  /// No description provided for @modePartial.
  ///
  /// In ar, this message translates to:
  /// **'جزئي'**
  String get modePartial;

  /// No description provided for @modeCredit.
  ///
  /// In ar, this message translates to:
  /// **'دين'**
  String get modeCredit;

  /// No description provided for @paidNowLabel.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المدفوع الآن'**
  String get paidNowLabel;

  /// No description provided for @paidHint.
  ///
  /// In ar, this message translates to:
  /// **'أكبر من صفر وأقل من الإجمالي {total}'**
  String paidHint(String total);

  /// No description provided for @paidErrorInvalid.
  ///
  /// In ar, this message translates to:
  /// **'أدخل مبلغاً أكبر من صفر، بخانتين عشريتين كحد أقصى.'**
  String get paidErrorInvalid;

  /// No description provided for @paidErrorNotBelowTotal.
  ///
  /// In ar, this message translates to:
  /// **'المدفوع يساوي الإجمالي أو يزيد عليه. اختر «كاش كامل» بدلاً من «جزئي».'**
  String get paidErrorNotBelowTotal;

  /// No description provided for @paymentMethodLabel.
  ///
  /// In ar, this message translates to:
  /// **'وسيلة الدفع'**
  String get paymentMethodLabel;

  /// No description provided for @methodCash.
  ///
  /// In ar, this message translates to:
  /// **'نقداً'**
  String get methodCash;

  /// No description provided for @methodJawwalPay.
  ///
  /// In ar, this message translates to:
  /// **'جوال باي'**
  String get methodJawwalPay;

  /// No description provided for @methodPalPay.
  ///
  /// In ar, this message translates to:
  /// **'بال باي'**
  String get methodPalPay;

  /// No description provided for @methodBankOfPalestine.
  ///
  /// In ar, this message translates to:
  /// **'بنك فلسطين'**
  String get methodBankOfPalestine;

  /// No description provided for @methodNone.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء'**
  String get methodNone;

  /// No description provided for @customerLabel.
  ///
  /// In ar, this message translates to:
  /// **'الزبون'**
  String get customerLabel;

  /// No description provided for @optionalWord.
  ///
  /// In ar, this message translates to:
  /// **'اختياري'**
  String get optionalWord;

  /// No description provided for @requiredWord.
  ///
  /// In ar, this message translates to:
  /// **'مطلوب'**
  String get requiredWord;

  /// No description provided for @balanceWord.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد'**
  String get balanceWord;

  /// No description provided for @limitWord.
  ///
  /// In ar, this message translates to:
  /// **'السقف'**
  String get limitWord;

  /// No description provided for @noLimitLong.
  ///
  /// In ar, this message translates to:
  /// **'بلا سقف دين'**
  String get noLimitLong;

  /// No description provided for @noLimitShort.
  ///
  /// In ar, this message translates to:
  /// **'بلا سقف'**
  String get noLimitShort;

  /// No description provided for @changeWord.
  ///
  /// In ar, this message translates to:
  /// **'تغيير'**
  String get changeWord;

  /// No description provided for @pickCustomer.
  ///
  /// In ar, this message translates to:
  /// **'اختيار الزبون'**
  String get pickCustomer;

  /// No description provided for @addCustomerToInvoice.
  ///
  /// In ar, this message translates to:
  /// **'إضافة زبون إلى الفاتورة'**
  String get addCustomerToInvoice;

  /// No description provided for @customerRequiredPartial.
  ///
  /// In ar, this message translates to:
  /// **'اختر الزبون — البيع الجزئي يُسجَّل ديناً باسمه'**
  String get customerRequiredPartial;

  /// No description provided for @customerRequiredCredit.
  ///
  /// In ar, this message translates to:
  /// **'اختر الزبون — البيع بالدين يُسجَّل باسمه'**
  String get customerRequiredCredit;

  /// No description provided for @dueLabel.
  ///
  /// In ar, this message translates to:
  /// **'موعد السداد'**
  String get dueLabel;

  /// No description provided for @optionalParen.
  ///
  /// In ar, this message translates to:
  /// **'(اختياري)'**
  String get optionalParen;

  /// No description provided for @dueNone.
  ///
  /// In ar, this message translates to:
  /// **'بدون موعد'**
  String get dueNone;

  /// No description provided for @dueWeek.
  ///
  /// In ar, this message translates to:
  /// **'بعد 7 أيام'**
  String get dueWeek;

  /// No description provided for @dueMonth.
  ///
  /// In ar, this message translates to:
  /// **'بعد 30 يوماً'**
  String get dueMonth;

  /// No description provided for @dueOn.
  ///
  /// In ar, this message translates to:
  /// **'الاستحقاق:'**
  String get dueOn;

  /// No description provided for @negativeStockTitle.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه مخزون — يمكنك المتابعة'**
  String get negativeStockTitle;

  /// No description provided for @negativeStockRow.
  ///
  /// In ar, this message translates to:
  /// **'المسجّل {stock} · المطلوب {quantity}'**
  String negativeStockRow(String stock, String quantity);

  /// No description provided for @negativeStockBody.
  ///
  /// In ar, this message translates to:
  /// **'الكمية أكبر من المخزون المسجّل في النظام. سيتم البيع، وسيصبح المخزون سالباً ويظهر للمالك في قائمة مراجعة المخزون.'**
  String get negativeStockBody;

  /// No description provided for @limitBlockedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تجاوز سقف الدين — لا يمكنك إتمام البيع'**
  String get limitBlockedTitle;

  /// No description provided for @limitBalanceNowOf.
  ///
  /// In ar, this message translates to:
  /// **'رصيد {name} الآن'**
  String limitBalanceNowOf(String name);

  /// No description provided for @limitThisSaleDebt.
  ///
  /// In ar, this message translates to:
  /// **'دين هذا البيع'**
  String get limitThisSaleDebt;

  /// No description provided for @limitCeiling.
  ///
  /// In ar, this message translates to:
  /// **'سقف الدين'**
  String get limitCeiling;

  /// No description provided for @limitOverBy.
  ///
  /// In ar, this message translates to:
  /// **'الزيادة على السقف'**
  String get limitOverBy;

  /// No description provided for @limitServerBody.
  ///
  /// In ar, this message translates to:
  /// **'رفض الخادم البيع: رصيد {name} تغيّر منذ تحميل القائمة، والدين الجديد يتجاوز سقفه الآن. لم تُنشأ فاتورة.'**
  String limitServerBody(String name);

  /// No description provided for @limitBlockedHelp.
  ///
  /// In ar, this message translates to:
  /// **'زِد المبلغ المدفوع حتى لا يتجاوز الدين السقف، أو اطلب من المالك أو المدير إتمام البيع من حسابه.'**
  String get limitBlockedHelp;

  /// No description provided for @limitWarnTitle.
  ///
  /// In ar, this message translates to:
  /// **'سيتجاوز رصيد {name} سقف الدين'**
  String limitWarnTitle(String name);

  /// No description provided for @limitWarnBody.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد بعد البيع {after} والسقف {limit} (زيادة {over}).'**
  String limitWarnBody(String after, String limit, String over);

  /// No description provided for @limitWarnHelp.
  ///
  /// In ar, this message translates to:
  /// **'لديك صلاحية التجاوز. ستُطلب منك موافقة صريحة، ويُسجَّل التجاوز باسمك.'**
  String get limitWarnHelp;

  /// No description provided for @submitOfflineTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال — لم يُرسَل البيع'**
  String get submitOfflineTitle;

  /// No description provided for @submitOfflineBody.
  ///
  /// In ar, this message translates to:
  /// **'لم يصل الطلب إلى الخادم. تحقق من الإنترنت ثم أعد المحاولة. البيع لن يُسجَّل مرتين.'**
  String get submitOfflineBody;

  /// No description provided for @submitUncertainTitle.
  ///
  /// In ar, this message translates to:
  /// **'انقطع الاتصال أثناء الحفظ — النتيجة غير مؤكدة'**
  String get submitUncertainTitle;

  /// No description provided for @submitUncertainBody.
  ///
  /// In ar, this message translates to:
  /// **'قد يكون البيع سُجّل أو لا. أعد المحاولة للتحقق: يُرسَل الطلب نفسه بالمفتاح نفسه، فلا يتكرر البيع. التعديل مقفل حتى يتأكد.'**
  String get submitUncertainBody;

  /// No description provided for @submitServerTitle.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ في الخادم — لم يُسجَّل البيع'**
  String get submitServerTitle;

  /// No description provided for @submitServerBody.
  ///
  /// In ar, this message translates to:
  /// **'أعد المحاولة بعد قليل. إن تكرر الخطأ، أعطِ رمز المرجع للدعم.'**
  String get submitServerBody;

  /// No description provided for @submitRejectedTitle.
  ///
  /// In ar, this message translates to:
  /// **'لم يُسجَّل البيع'**
  String get submitRejectedTitle;

  /// No description provided for @paidWord.
  ///
  /// In ar, this message translates to:
  /// **'المدفوع'**
  String get paidWord;

  /// No description provided for @remainingWord.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي'**
  String get remainingWord;

  /// No description provided for @statusPaidFull.
  ///
  /// In ar, this message translates to:
  /// **'مدفوع بالكامل'**
  String get statusPaidFull;

  /// No description provided for @statusPartialDebt.
  ///
  /// In ar, this message translates to:
  /// **'جزئي — يبقى ديناً'**
  String get statusPartialDebt;

  /// No description provided for @statusFullDebt.
  ///
  /// In ar, this message translates to:
  /// **'دين كامل'**
  String get statusFullDebt;

  /// No description provided for @barLimitBlocked.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن المتابعة: الدين يتجاوز سقف الزبون'**
  String get barLimitBlocked;

  /// No description provided for @barPaidFull.
  ///
  /// In ar, this message translates to:
  /// **'مدفوع بالكامل — لا دين'**
  String get barPaidFull;

  /// No description provided for @barDebtOn.
  ///
  /// In ar, this message translates to:
  /// **'سيُسجَّل دين {amount} على {name}'**
  String barDebtOn(String amount, String name);

  /// No description provided for @barDebtNoCustomer.
  ///
  /// In ar, this message translates to:
  /// **'سيبقى {amount} ديناً — اختر الزبون'**
  String barDebtNoCustomer(String amount);

  /// No description provided for @confirmSale.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد البيع ·'**
  String get confirmSale;

  /// No description provided for @savingSale.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ حفظ البيع…'**
  String get savingSale;

  /// No description provided for @savingShort.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الحفظ…'**
  String get savingShort;

  /// No description provided for @verifyAndRetry.
  ///
  /// In ar, this message translates to:
  /// **'التحقق وإعادة المحاولة'**
  String get verifyAndRetry;

  /// No description provided for @continueOverLimit.
  ///
  /// In ar, this message translates to:
  /// **'متابعة رغم تجاوز السقف…'**
  String get continueOverLimit;

  /// No description provided for @retrySale.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة ·'**
  String get retrySale;

  /// No description provided for @overrideTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد تجاوز سقف الدين'**
  String get overrideTitle;

  /// No description provided for @overrideBalanceNow.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد الحالي'**
  String get overrideBalanceNow;

  /// No description provided for @overrideBalanceAfter.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد بعد البيع'**
  String get overrideBalanceAfter;

  /// No description provided for @overrideNote.
  ///
  /// In ar, this message translates to:
  /// **'بالموافقة يُنشأ البيع ويُسجَّل التجاوز في سجل التدقيق باسم {name} ({role}). إغلاق هذه النافذة لا يُتم البيع.'**
  String overrideNote(String name, String role);

  /// No description provided for @overrideForbidden.
  ///
  /// In ar, this message translates to:
  /// **'رفض الخادم التجاوز: حسابك لا يملك هذه الصلاحية الآن. لم يُسجَّل البيع.'**
  String get overrideForbidden;

  /// No description provided for @overrideBack.
  ///
  /// In ar, this message translates to:
  /// **'رجوع دون إتمام'**
  String get overrideBack;

  /// No description provided for @overrideConfirm.
  ///
  /// In ar, this message translates to:
  /// **'أوافق على التجاوز وأؤكد البيع'**
  String get overrideConfirm;

  /// No description provided for @pickerTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختيار الزبون'**
  String get pickerTitle;

  /// No description provided for @pickerCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الاختيار'**
  String get pickerCancel;

  /// No description provided for @pickerSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث بالاسم أو رقم الهاتف'**
  String get pickerSearchHint;

  /// No description provided for @pickerNeedsCustomer.
  ///
  /// In ar, this message translates to:
  /// **'البيع الجزئي أو بالدين يحتاج زبوناً لتسجيل الدين باسمه.'**
  String get pickerNeedsCustomer;

  /// No description provided for @pickerLoading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحميل الزبائن'**
  String get pickerLoading;

  /// No description provided for @pickerEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد زبون بهذا الاسم أو الرقم'**
  String get pickerEmpty;

  /// No description provided for @pickerEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من الكتابة، أو أضفه زبوناً جديداً.'**
  String get pickerEmptyBody;

  /// No description provided for @pickerAddNamed.
  ///
  /// In ar, this message translates to:
  /// **'إضافة «{name}» زبوناً جديداً'**
  String pickerAddNamed(String name);

  /// No description provided for @pickerNewCustomer.
  ///
  /// In ar, this message translates to:
  /// **'زبون جديد'**
  String get pickerNewCustomer;

  /// No description provided for @pickerError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الزبائن'**
  String get pickerError;

  /// No description provided for @pickerErrorBody.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من الاتصال. البيع الحالي محفوظ كما هو.'**
  String get pickerErrorBody;

  /// No description provided for @pickerSkip.
  ///
  /// In ar, this message translates to:
  /// **'متابعة بدون زبون'**
  String get pickerSkip;

  /// No description provided for @owesWord.
  ///
  /// In ar, this message translates to:
  /// **'عليه'**
  String get owesWord;

  /// No description provided for @noDebtWord.
  ///
  /// In ar, this message translates to:
  /// **'لا دين'**
  String get noDebtWord;

  /// No description provided for @newCustomerTitle.
  ///
  /// In ar, this message translates to:
  /// **'زبون جديد'**
  String get newCustomerTitle;

  /// No description provided for @newCustomerName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الزبون'**
  String get newCustomerName;

  /// No description provided for @newCustomerPhone.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get newCustomerPhone;

  /// No description provided for @newCustomerPhoneHint.
  ///
  /// In ar, this message translates to:
  /// **'10 أرقام. سقف الدين يحدده المالك أو المدير لاحقاً.'**
  String get newCustomerPhoneHint;

  /// No description provided for @newCustomerNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسم الزبون'**
  String get newCustomerNameRequired;

  /// No description provided for @newCustomerPhoneInvalid.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف 10 أرقام ويبدأ بـ 0'**
  String get newCustomerPhoneInvalid;

  /// No description provided for @newCustomerSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ واختيار الزبون'**
  String get newCustomerSave;

  /// No description provided for @newCustomerBack.
  ///
  /// In ar, this message translates to:
  /// **'رجوع إلى البحث'**
  String get newCustomerBack;

  /// No description provided for @receiptDoneTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم البيع'**
  String get receiptDoneTitle;

  /// No description provided for @receiptPaidWord.
  ///
  /// In ar, this message translates to:
  /// **'دُفع'**
  String get receiptPaidWord;

  /// No description provided for @receiptPaidTail.
  ///
  /// In ar, this message translates to:
  /// **'بالكامل'**
  String get receiptPaidTail;

  /// No description provided for @receiptDebtWord.
  ///
  /// In ar, this message translates to:
  /// **'سُجّل دين'**
  String get receiptDebtWord;

  /// No description provided for @receiptDebtTail.
  ///
  /// In ar, this message translates to:
  /// **'على {name}'**
  String receiptDebtTail(String name);

  /// No description provided for @receiptVoidedTitle.
  ///
  /// In ar, this message translates to:
  /// **'أُلغيت الفاتورة'**
  String get receiptVoidedTitle;

  /// No description provided for @receiptInvoiceWord.
  ///
  /// In ar, this message translates to:
  /// **'الفاتورة'**
  String get receiptInvoiceWord;

  /// No description provided for @receiptVoidedTail.
  ///
  /// In ar, this message translates to:
  /// **'محفوظة في السجل بحالة «ملغاة»'**
  String get receiptVoidedTail;

  /// No description provided for @receiptNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الفاتورة'**
  String get receiptNumber;

  /// No description provided for @receiptDate.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get receiptDate;

  /// No description provided for @receiptSeller.
  ///
  /// In ar, this message translates to:
  /// **'البائع'**
  String get receiptSeller;

  /// No description provided for @remainingAsDebt.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي ديناً'**
  String get remainingAsDebt;

  /// No description provided for @voidedStamp.
  ///
  /// In ar, this message translates to:
  /// **'ملغاة'**
  String get voidedStamp;

  /// No description provided for @receiptNegativeNote.
  ///
  /// In ar, this message translates to:
  /// **'سُجّل «{names}» بمخزون سالب، وأُضيف إلى قائمة مراجعة المخزون لدى المالك.'**
  String receiptNegativeNote(String names);

  /// No description provided for @receiptOverrideNote.
  ///
  /// In ar, this message translates to:
  /// **'تم تجاوز سقف دين {customer} بموافقة {user}. التجاوز مسجّل في سجل التدقيق.'**
  String receiptOverrideNote(String customer, String user);

  /// No description provided for @receiptReplayNote.
  ///
  /// In ar, this message translates to:
  /// **'تحققنا من الخادم: البيع مسجّل مرة واحدة فقط رغم انقطاع الاتصال.'**
  String get receiptReplayNote;

  /// No description provided for @receiptVoidedBy.
  ///
  /// In ar, this message translates to:
  /// **'أُلغيت بواسطة {name} · {time}'**
  String receiptVoidedBy(String name, String time);

  /// No description provided for @receiptVoidReason.
  ///
  /// In ar, this message translates to:
  /// **'السبب: {reason}'**
  String receiptVoidReason(String reason);

  /// No description provided for @receiptVoidEffect.
  ///
  /// In ar, this message translates to:
  /// **'أُعيد المخزون وأُلغي الدين المرتبط. الفاتورة باقية في السجل بحالة «ملغاة».'**
  String get receiptVoidEffect;

  /// No description provided for @newSale.
  ///
  /// In ar, this message translates to:
  /// **'بيع جديد'**
  String get newSale;

  /// No description provided for @voidInvoiceEllipsis.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الفاتورة…'**
  String get voidInvoiceEllipsis;

  /// No description provided for @voidTitle.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الفاتورة #{id}'**
  String voidTitle(int id);

  /// No description provided for @voidEffectsTitle.
  ///
  /// In ar, this message translates to:
  /// **'عند الإلغاء:'**
  String get voidEffectsTitle;

  /// No description provided for @voidEffectStock.
  ///
  /// In ar, this message translates to:
  /// **'تُعاد كميات الأصناف إلى المخزون.'**
  String get voidEffectStock;

  /// No description provided for @voidEffectDebt.
  ///
  /// In ar, this message translates to:
  /// **'يُلغى الدين المرتبط {amount} على {name}.'**
  String voidEffectDebt(String amount, String name);

  /// No description provided for @voidEffectKept.
  ///
  /// In ar, this message translates to:
  /// **'تبقى الفاتورة في السجل بحالة «ملغاة» ولا تُحذف.'**
  String get voidEffectKept;

  /// No description provided for @voidEffectFinal.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن التراجع عن الإلغاء.'**
  String get voidEffectFinal;

  /// No description provided for @voidReasonLabel.
  ///
  /// In ar, this message translates to:
  /// **'سبب الإلغاء (مطلوب)'**
  String get voidReasonLabel;

  /// No description provided for @voidReasonRequired.
  ///
  /// In ar, this message translates to:
  /// **'اكتب سبب الإلغاء — يُحفظ في سجل التدقيق'**
  String get voidReasonRequired;

  /// No description provided for @voidBlocked.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إلغاء هذه الفاتورة: عليها دفعات لاحقة أو مرتجعات. استخدم «مرتجع» من إدارة المبيعات على الويب.'**
  String get voidBlocked;

  /// No description provided for @voidForbidden.
  ///
  /// In ar, this message translates to:
  /// **'ليست لديك صلاحية إلغاء الفواتير. الإلغاء للمالك أو المدير.'**
  String get voidForbidden;

  /// No description provided for @voidNetwork.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال — لم تُلغَ الفاتورة. أعد المحاولة.'**
  String get voidNetwork;

  /// No description provided for @voiding.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الإلغاء…'**
  String get voiding;

  /// No description provided for @voidConfirm.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الفاتورة نهائياً'**
  String get voidConfirm;

  /// No description provided for @custSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'بحث بالاسم أو الهاتف'**
  String get custSearchHint;

  /// No description provided for @custAdd.
  ///
  /// In ar, this message translates to:
  /// **'+ زبون'**
  String get custAdd;

  /// No description provided for @custSearchMin.
  ///
  /// In ar, this message translates to:
  /// **'اكتب حرفين أو أكثر للبحث.'**
  String get custSearchMin;

  /// No description provided for @custEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا زبائن بعد'**
  String get custEmptyTitle;

  /// No description provided for @custEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'أضف زبائن الدين. البيع النقدي لا يحتاج زبوناً.'**
  String get custEmptyBody;

  /// No description provided for @custNoResults.
  ///
  /// In ar, this message translates to:
  /// **'لا زبون باسم «{query}»'**
  String custNoResults(String query);

  /// No description provided for @custNoResultsBody.
  ///
  /// In ar, this message translates to:
  /// **'أضفه الآن بالاسم والهاتف.'**
  String get custNoResultsBody;

  /// No description provided for @custAddNamed.
  ///
  /// In ar, this message translates to:
  /// **'إضافة «{name}»'**
  String custAddNamed(String name);

  /// No description provided for @custLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الزبائن. تحقق من الاتصال ثم أعد المحاولة.'**
  String get custLoadError;

  /// No description provided for @custOverdue.
  ///
  /// In ar, this message translates to:
  /// **'متأخر'**
  String get custOverdue;

  /// No description provided for @custInactive.
  ///
  /// In ar, this message translates to:
  /// **'موقوف'**
  String get custInactive;

  /// No description provided for @custRemaining.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي عليه'**
  String get custRemaining;

  /// No description provided for @custOverdueAmount.
  ///
  /// In ar, this message translates to:
  /// **'متأخر {amount}'**
  String custOverdueAmount(String amount);

  /// No description provided for @custLimit.
  ///
  /// In ar, this message translates to:
  /// **'حد الدين {amount}'**
  String custLimit(String amount);

  /// No description provided for @custNoLimit.
  ///
  /// In ar, this message translates to:
  /// **'بلا حد للدين'**
  String get custNoLimit;

  /// No description provided for @custRecordPayment.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل دفعة'**
  String get custRecordPayment;

  /// No description provided for @custCall.
  ///
  /// In ar, this message translates to:
  /// **'اتصال بـ {phone}'**
  String custCall(String phone);

  /// No description provided for @custOpenDebts.
  ///
  /// In ar, this message translates to:
  /// **'ديون مفتوحة'**
  String get custOpenDebts;

  /// No description provided for @custNoOpenDebts.
  ///
  /// In ar, this message translates to:
  /// **'لا ديون مفتوحة على هذا الزبون.'**
  String get custNoOpenDebts;

  /// No description provided for @custRecentPayments.
  ///
  /// In ar, this message translates to:
  /// **'آخر الدفعات'**
  String get custRecentPayments;

  /// No description provided for @custNoPayments.
  ///
  /// In ar, this message translates to:
  /// **'لا دفعات بعد.'**
  String get custNoPayments;

  /// No description provided for @custDebtSale.
  ///
  /// In ar, this message translates to:
  /// **'فاتورة #{id}'**
  String custDebtSale(int id);

  /// No description provided for @custDebtOpening.
  ///
  /// In ar, this message translates to:
  /// **'دين افتتاحي'**
  String get custDebtOpening;

  /// No description provided for @custDue.
  ///
  /// In ar, this message translates to:
  /// **'استحقاق {date}'**
  String custDue(String date);

  /// No description provided for @custNoDue.
  ///
  /// In ar, this message translates to:
  /// **'بلا تاريخ استحقاق'**
  String get custNoDue;

  /// No description provided for @custStatusOpen.
  ///
  /// In ar, this message translates to:
  /// **'مفتوح'**
  String get custStatusOpen;

  /// No description provided for @custReversed.
  ///
  /// In ar, this message translates to:
  /// **'معكوسة'**
  String get custReversed;

  /// No description provided for @custDetailError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل ملف الزبون.'**
  String get custDetailError;

  /// No description provided for @custInactiveNote.
  ///
  /// In ar, this message translates to:
  /// **'هذا الزبون موقوف: لا يظهر في البيع الجديد، ودفعاته مقبولة.'**
  String get custInactiveNote;

  /// No description provided for @payTitle.
  ///
  /// In ar, this message translates to:
  /// **'دفعة من {name}'**
  String payTitle(String name);

  /// No description provided for @payAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get payAmount;

  /// No description provided for @payFull.
  ///
  /// In ar, this message translates to:
  /// **'كامل المتبقي'**
  String get payFull;

  /// No description provided for @payOther.
  ///
  /// In ar, this message translates to:
  /// **'مبلغ آخر'**
  String get payOther;

  /// No description provided for @payRemainingNote.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي {amount} · حتى خانتين عشريتين'**
  String payRemainingNote(String amount);

  /// No description provided for @payMethod.
  ///
  /// In ar, this message translates to:
  /// **'طريقة الدفع'**
  String get payMethod;

  /// No description provided for @payNow.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي الآن'**
  String get payNow;

  /// No description provided for @payThis.
  ///
  /// In ar, this message translates to:
  /// **'الدفعة'**
  String get payThis;

  /// No description provided for @payAfter.
  ///
  /// In ar, this message translates to:
  /// **'بعد الدفعة'**
  String get payAfter;

  /// No description provided for @payOldestFirst.
  ///
  /// In ar, this message translates to:
  /// **'تُوزَّع على الديون من الأقدم استحقاقاً.'**
  String get payOldestFirst;

  /// No description provided for @payConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد استلام {amount}'**
  String payConfirm(String amount);

  /// No description provided for @paySaving.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تسجيل الدفعة…'**
  String get paySaving;

  /// No description provided for @payRetry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get payRetry;

  /// No description provided for @payUncertain.
  ///
  /// In ar, this message translates to:
  /// **'لم يصل رد الخادم، فلا نعرف إن سُجّلت الدفعة. اضغط «إعادة المحاولة»: تُرسل بنفس المفتاح فلن تُسجَّل مرتين.'**
  String get payUncertain;

  /// No description provided for @payInvalid.
  ///
  /// In ar, this message translates to:
  /// **'أدخل مبلغاً صحيحاً بخانتين عشريتين على الأكثر.'**
  String get payInvalid;

  /// No description provided for @payTooMuch.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ أكبر من المتبقي ({amount}).'**
  String payTooMuch(String amount);

  /// No description provided for @payNothing.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد على هذا الزبون مبلغ متبقٍّ.'**
  String get payNothing;

  /// No description provided for @payDone.
  ///
  /// In ar, this message translates to:
  /// **'استُلمت {amount}'**
  String payDone(String amount);

  /// No description provided for @payDoneRemaining.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي على {name} الآن {amount}'**
  String payDoneRemaining(String name, String amount);

  /// No description provided for @payDoneButton.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get payDoneButton;

  /// No description provided for @prodSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'بحث بالاسم أو الباركود'**
  String get prodSearchHint;

  /// No description provided for @prodAdd.
  ///
  /// In ar, this message translates to:
  /// **'+ منتج'**
  String get prodAdd;

  /// No description provided for @prodFilterAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get prodFilterAll;

  /// No description provided for @prodFilterLow.
  ///
  /// In ar, this message translates to:
  /// **'منخفض'**
  String get prodFilterLow;

  /// No description provided for @prodFilterNegative.
  ///
  /// In ar, this message translates to:
  /// **'سالب'**
  String get prodFilterNegative;

  /// No description provided for @prodEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا منتجات بعد'**
  String get prodEmptyTitle;

  /// No description provided for @prodEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'امسح رمز المنتج أو الباركود لإضافته بسرعة، أو استورد قائمتك من الويب.'**
  String get prodEmptyBody;

  /// No description provided for @prodNoResults.
  ///
  /// In ar, this message translates to:
  /// **'لا منتجات تطابق هذا البحث.'**
  String get prodNoResults;

  /// No description provided for @prodLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل المنتجات.'**
  String get prodLoadError;

  /// No description provided for @prodStockOk.
  ///
  /// In ar, this message translates to:
  /// **'متوفر'**
  String get prodStockOk;

  /// No description provided for @prodStockLow.
  ///
  /// In ar, this message translates to:
  /// **'منخفض'**
  String get prodStockLow;

  /// No description provided for @prodStockOut.
  ///
  /// In ar, this message translates to:
  /// **'نفد'**
  String get prodStockOut;

  /// No description provided for @prodStockNegative.
  ///
  /// In ar, this message translates to:
  /// **'سالب'**
  String get prodStockNegative;

  /// No description provided for @prodPerPiece.
  ///
  /// In ar, this message translates to:
  /// **'قطعة'**
  String get prodPerPiece;

  /// No description provided for @prodPerKg.
  ///
  /// In ar, this message translates to:
  /// **'كغ'**
  String get prodPerKg;

  /// No description provided for @addTitle.
  ///
  /// In ar, this message translates to:
  /// **'إضافة منتج'**
  String get addTitle;

  /// No description provided for @addScan.
  ///
  /// In ar, this message translates to:
  /// **'مسح رمز QR أو الباركود'**
  String get addScan;

  /// No description provided for @addScanSub.
  ///
  /// In ar, this message translates to:
  /// **'نقرأ ما في الرمز ونعبّئ الحقول'**
  String get addScanSub;

  /// No description provided for @addManual.
  ///
  /// In ar, this message translates to:
  /// **'إدخال يدوي'**
  String get addManual;

  /// No description provided for @addManualSub.
  ///
  /// In ar, this message translates to:
  /// **'للمنتجات بلا رمز، مثل الموزون'**
  String get addManualSub;

  /// No description provided for @addChecking.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحقق من الرمز…'**
  String get addChecking;

  /// No description provided for @addExistsTitle.
  ///
  /// In ar, this message translates to:
  /// **'المنتج موجود'**
  String get addExistsTitle;

  /// No description provided for @addExistsBody.
  ///
  /// In ar, this message translates to:
  /// **'الباركود {code} مسجّل في متجرك. لن نضيفه مرة ثانية.'**
  String addExistsBody(String code);

  /// No description provided for @addScanAnother.
  ///
  /// In ar, this message translates to:
  /// **'مسح رمز آخر'**
  String get addScanAnother;

  /// No description provided for @addFromCode.
  ///
  /// In ar, this message translates to:
  /// **'من الرمز'**
  String get addFromCode;

  /// No description provided for @addBarcodeOnly.
  ///
  /// In ar, this message translates to:
  /// **'الرمز يحتوي الباركود فقط. أكمل الاسم والسعر.'**
  String get addBarcodeOnly;

  /// No description provided for @addReadFields.
  ///
  /// In ar, this message translates to:
  /// **'قرأنا من الرمز: {fields}. راجعها قبل الحفظ.'**
  String addReadFields(String fields);

  /// No description provided for @addFieldName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get addFieldName;

  /// No description provided for @addFieldBarcode.
  ///
  /// In ar, this message translates to:
  /// **'الباركود'**
  String get addFieldBarcode;

  /// No description provided for @addFieldPrice.
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get addFieldPrice;

  /// No description provided for @addFieldUnit.
  ///
  /// In ar, this message translates to:
  /// **'الوحدة'**
  String get addFieldUnit;

  /// No description provided for @addUnreadable.
  ///
  /// In ar, this message translates to:
  /// **'هذا الرمز لا يحتوي بيانات منتج. أدخل المنتج يدوياً؛ لن نستخدم محتواه.'**
  String get addUnreadable;

  /// No description provided for @addManualNote.
  ///
  /// In ar, this message translates to:
  /// **'إدخال يدوي. الاسم وسعر البيع مطلوبان.'**
  String get addManualNote;

  /// No description provided for @addLookupFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التحقق من وجود المنتج الآن؛ سنتحقق عند الحفظ.'**
  String get addLookupFailed;

  /// No description provided for @addFromCatalog.
  ///
  /// In ar, this message translates to:
  /// **'هذا المنتج معروف في حسبة، فملأنا اسمه ووحدته. أدخل سعر البيع والتكلفة والكمية لمتجرك.'**
  String get addFromCatalog;

  /// No description provided for @formNewTitle.
  ///
  /// In ar, this message translates to:
  /// **'منتج جديد'**
  String get formNewTitle;

  /// No description provided for @formName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المنتج'**
  String get formName;

  /// No description provided for @formNameHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: تمر مجهول 1 كغ'**
  String get formNameHint;

  /// No description provided for @formBarcode.
  ///
  /// In ar, this message translates to:
  /// **'الباركود'**
  String get formBarcode;

  /// No description provided for @formOptional.
  ///
  /// In ar, this message translates to:
  /// **'اختياري'**
  String get formOptional;

  /// No description provided for @formSoldBy.
  ///
  /// In ar, this message translates to:
  /// **'يُباع'**
  String get formSoldBy;

  /// No description provided for @formByPiece.
  ///
  /// In ar, this message translates to:
  /// **'بالقطعة'**
  String get formByPiece;

  /// No description provided for @formByKg.
  ///
  /// In ar, this message translates to:
  /// **'بالوزن (كغ)'**
  String get formByKg;

  /// No description provided for @formPrice.
  ///
  /// In ar, this message translates to:
  /// **'سعر البيع'**
  String get formPrice;

  /// No description provided for @formCost.
  ///
  /// In ar, this message translates to:
  /// **'سعر الشراء'**
  String get formCost;

  /// No description provided for @formStock.
  ///
  /// In ar, this message translates to:
  /// **'المخزون الآن'**
  String get formStock;

  /// No description provided for @formMin.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه عند'**
  String get formMin;

  /// No description provided for @formNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسم المنتج.'**
  String get formNameRequired;

  /// No description provided for @formPriceInvalid.
  ///
  /// In ar, this message translates to:
  /// **'أدخل سعراً صحيحاً.'**
  String get formPriceInvalid;

  /// No description provided for @formStockPiece.
  ///
  /// In ar, this message translates to:
  /// **'عدد صحيح للمنتج بالقطعة.'**
  String get formStockPiece;

  /// No description provided for @formStockKg.
  ///
  /// In ar, this message translates to:
  /// **'حتى 3 خانات عشرية.'**
  String get formStockKg;

  /// No description provided for @formSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ المنتج'**
  String get formSave;

  /// No description provided for @formSaving.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الحفظ…'**
  String get formSaving;

  /// No description provided for @formNetwork.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الحفظ: لا اتصال بالخادم. بياناتك باقية في النموذج؛ أعد المحاولة.'**
  String get formNetwork;

  /// No description provided for @formForbidden.
  ///
  /// In ar, this message translates to:
  /// **'إضافة المنتجات للمالك أو المدير. اطلب من المالك إضافته.'**
  String get formForbidden;

  /// No description provided for @formFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الحفظ. حاول مرة أخرى.'**
  String get formFailed;

  /// No description provided for @savedTitle.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف «{name}»'**
  String savedTitle(String name);

  /// No description provided for @savedScanNext.
  ///
  /// In ar, this message translates to:
  /// **'مسح منتج آخر'**
  String get savedScanNext;

  /// No description provided for @savedBack.
  ///
  /// In ar, this message translates to:
  /// **'العودة إلى المنتجات'**
  String get savedBack;

  /// No description provided for @homeAttention.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج انتباهك'**
  String get homeAttention;

  /// No description provided for @homeOverdueAlert.
  ///
  /// In ar, this message translates to:
  /// **'ديون متأخرة: {count}'**
  String homeOverdueAlert(int count);

  /// No description provided for @homeDueTodayAlert.
  ///
  /// In ar, this message translates to:
  /// **'مستحق اليوم: {count}'**
  String homeDueTodayAlert(int count);

  /// No description provided for @homeLowStockAlert.
  ///
  /// In ar, this message translates to:
  /// **'منتجات تحت الحد: {count}'**
  String homeLowStockAlert(int count);

  /// No description provided for @homeNegativeAlert.
  ///
  /// In ar, this message translates to:
  /// **'مخزون سالب للمراجعة: {count}'**
  String homeNegativeAlert(int count);

  /// No description provided for @homeAllClear.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء يحتاج انتباهك الآن.'**
  String get homeAllClear;

  /// No description provided for @homeCollections.
  ///
  /// In ar, this message translates to:
  /// **'التحصيلات'**
  String get homeCollections;

  /// No description provided for @homeCollectionsSplit.
  ///
  /// In ar, this message translates to:
  /// **'عند البيع {atSale} · ديون {repayments}'**
  String homeCollectionsSplit(String atSale, String repayments);

  /// No description provided for @loginNoAccount.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك حساب؟'**
  String get loginNoAccount;

  /// No description provided for @loginCreateStore.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء متجر جديد'**
  String get loginCreateStore;

  /// No description provided for @storeSuspended.
  ///
  /// In ar, this message translates to:
  /// **'حساب هذا المتجر موقوف. تواصل مع إدارة حسبة لإعادة تفعيله.'**
  String get storeSuspended;

  /// No description provided for @registerTitle.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء متجر جديد'**
  String get registerTitle;

  /// No description provided for @registerHelper.
  ///
  /// In ar, this message translates to:
  /// **'ثلاث خطوات، وتبدأ بفترة تجريبية مجانية 7 أيام.'**
  String get registerHelper;

  /// No description provided for @registerStepOf.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة {current} من {total}'**
  String registerStepOf(int current, int total);

  /// No description provided for @registerStepStore.
  ///
  /// In ar, this message translates to:
  /// **'المتجر'**
  String get registerStepStore;

  /// No description provided for @registerStepStoreSub.
  ///
  /// In ar, this message translates to:
  /// **'لنبدأ باسم متجرك واسم صاحبه المسؤول عنه.'**
  String get registerStepStoreSub;

  /// No description provided for @registerStepContact.
  ///
  /// In ar, this message translates to:
  /// **'الموقع والتواصل'**
  String get registerStepContact;

  /// No description provided for @registerStepContactSub.
  ///
  /// In ar, this message translates to:
  /// **'الهاتف والعنوان يظهران على إيصال الزبون.'**
  String get registerStepContactSub;

  /// No description provided for @registerStepAccount.
  ///
  /// In ar, this message translates to:
  /// **'بيانات الدخول'**
  String get registerStepAccount;

  /// No description provided for @registerStepAccountSub.
  ///
  /// In ar, this message translates to:
  /// **'اختر البريد وكلمة المرور التي تدخل بها إلى حسبة.'**
  String get registerStepAccountSub;

  /// No description provided for @storeNameLabel.
  ///
  /// In ar, this message translates to:
  /// **'اسم المتجر'**
  String get storeNameLabel;

  /// No description provided for @ownerNameLabel.
  ///
  /// In ar, this message translates to:
  /// **'اسم صاحب المتجر'**
  String get ownerNameLabel;

  /// No description provided for @storePhoneLabel.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get storePhoneLabel;

  /// No description provided for @cityLabel.
  ///
  /// In ar, this message translates to:
  /// **'المدينة'**
  String get cityLabel;

  /// No description provided for @cityHint.
  ///
  /// In ar, this message translates to:
  /// **'اختر المدينة'**
  String get cityHint;

  /// No description provided for @streetLabel.
  ///
  /// In ar, this message translates to:
  /// **'العنوان (الشارع والمنطقة)'**
  String get streetLabel;

  /// No description provided for @passwordConfirmLabel.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد كلمة المرور'**
  String get passwordConfirmLabel;

  /// No description provided for @passwordMinHint.
  ///
  /// In ar, this message translates to:
  /// **'8 أحرف على الأقل'**
  String get passwordMinHint;

  /// No description provided for @storeNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال اسم المتجر.'**
  String get storeNameRequired;

  /// No description provided for @ownerNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال اسم صاحب المتجر.'**
  String get ownerNameRequired;

  /// No description provided for @phoneRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال رقم الهاتف.'**
  String get phoneRequired;

  /// No description provided for @phoneInvalid.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف 9 أو 10 أرقام، مثل 0599123456.'**
  String get phoneInvalid;

  /// No description provided for @cityRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار المدينة.'**
  String get cityRequired;

  /// No description provided for @streetRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال عنوان المتجر.'**
  String get streetRequired;

  /// No description provided for @registerEmailRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال البريد الإلكتروني.'**
  String get registerEmailRequired;

  /// No description provided for @registerEmailInvalid.
  ///
  /// In ar, this message translates to:
  /// **'صيغة البريد الإلكتروني غير صحيحة.'**
  String get registerEmailInvalid;

  /// No description provided for @passwordTooShort.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور 8 أحرف على الأقل.'**
  String get passwordTooShort;

  /// No description provided for @passwordMismatch.
  ///
  /// In ar, this message translates to:
  /// **'التأكيد لا يطابق كلمة المرور.'**
  String get passwordMismatch;

  /// No description provided for @emailTaken.
  ///
  /// In ar, this message translates to:
  /// **'هذا البريد مسجّل مسبقاً. سجّل الدخول، أو استخدم بريداً آخر.'**
  String get emailTaken;

  /// No description provided for @registerFailedTaken.
  ///
  /// In ar, this message translates to:
  /// **'لم يُنشأ المتجر: البريد الإلكتروني مستخدم.'**
  String get registerFailedTaken;

  /// No description provided for @registerFailedValidation.
  ///
  /// In ar, this message translates to:
  /// **'لم يُنشأ المتجر. راجع الحقول المعلّمة.'**
  String get registerFailedValidation;

  /// No description provided for @registerNetworkError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال بالخادم. بياناتك باقية في النموذج، أعد المحاولة.'**
  String get registerNetworkError;

  /// No description provided for @registerServerError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ في الخادم ولم يُنشأ المتجر. أعد المحاولة بعد قليل.'**
  String get registerServerError;

  /// No description provided for @registerNext.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get registerNext;

  /// No description provided for @registerBack.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get registerBack;

  /// No description provided for @registerSubmit.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء المتجر'**
  String get registerSubmit;

  /// No description provided for @registerSubmitting.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ إنشاء المتجر…'**
  String get registerSubmitting;

  /// No description provided for @registerHaveAccount.
  ///
  /// In ar, this message translates to:
  /// **'لديك حساب؟'**
  String get registerHaveAccount;

  /// No description provided for @registerSignIn.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get registerSignIn;

  /// No description provided for @subscriptionTrialEndedTitle.
  ///
  /// In ar, this message translates to:
  /// **'انتهت الفترة التجريبية'**
  String get subscriptionTrialEndedTitle;

  /// No description provided for @subscriptionPaidEndedTitle.
  ///
  /// In ar, this message translates to:
  /// **'انتهى اشتراك متجرك'**
  String get subscriptionPaidEndedTitle;

  /// No description provided for @subscriptionEndedOn.
  ///
  /// In ar, this message translates to:
  /// **'متجر «{store}»، انتهت في {date}'**
  String subscriptionEndedOn(String store, String date);

  /// No description provided for @subscriptionDataSafe.
  ///
  /// In ar, this message translates to:
  /// **'بياناتك محفوظة كما هي: الزبائن والديون والمبيعات والمنتجات. يعود كل شيء فور تفعيل الاشتراك.'**
  String get subscriptionDataSafe;

  /// No description provided for @subscriptionContactWhatsapp.
  ///
  /// In ar, this message translates to:
  /// **'تواصل معنا عبر واتساب'**
  String get subscriptionContactWhatsapp;

  /// No description provided for @subscriptionContactNoNumber.
  ///
  /// In ar, this message translates to:
  /// **'تواصل مع إدارة حسبة لتفعيل الاشتراك.'**
  String get subscriptionContactNoNumber;

  /// No description provided for @subscriptionWhatsappMessage.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً، أريد تفعيل اشتراك متجر «{store}» على حسبة.\nالبريد: {email}'**
  String subscriptionWhatsappMessage(String store, String email);

  /// No description provided for @subscriptionWhatsappFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح واتساب. رقم الدعم: {number}'**
  String subscriptionWhatsappFailed(String number);

  /// No description provided for @subscriptionCheckAgain.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من جديد'**
  String get subscriptionCheckAgain;

  /// No description provided for @subscriptionChecking.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحقق…'**
  String get subscriptionChecking;

  /// No description provided for @subscriptionStillInactive.
  ///
  /// In ar, this message translates to:
  /// **'لم يُفعَّل الاشتراك بعد. بعد تأكيد الدفع من إدارة حسبة اضغط «تحقق من جديد».'**
  String get subscriptionStillInactive;

  /// No description provided for @saleScanTitle.
  ///
  /// In ar, this message translates to:
  /// **'مسح منتجات البيع'**
  String get saleScanTitle;

  /// No description provided for @saleScanKeepGoing.
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا شغّالة: امسح المنتج التالي'**
  String get saleScanKeepGoing;

  /// No description provided for @saleScanCloseA11y.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق الكاميرا والعودة إلى السلة'**
  String get saleScanCloseA11y;

  /// No description provided for @cartPanelTitle.
  ///
  /// In ar, this message translates to:
  /// **'السلة'**
  String get cartPanelTitle;

  /// No description provided for @saleScanEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'وجّه الكاميرا إلى باركود المنتج. تبقى الكاميرا مفتوحة لتضيف المنتجات واحداً تلو الآخر.'**
  String get saleScanEmptyBody;

  /// No description provided for @completeSale.
  ///
  /// In ar, this message translates to:
  /// **'إتمام البيع'**
  String get completeSale;

  /// No description provided for @methodRecordOnly.
  ///
  /// In ar, this message translates to:
  /// **'يُسجَّل فقط أن الزبون دفع عبر {method}. حسبة لا تتصل بهذه الخدمة ولا تتحقق من وصول المبلغ، فتأكد منه قبل تأكيد البيع.'**
  String methodRecordOnly(String method);

  /// No description provided for @invTitle.
  ///
  /// In ar, this message translates to:
  /// **'إضافة منتجات بالمسح'**
  String get invTitle;

  /// No description provided for @invInstruction.
  ///
  /// In ar, this message translates to:
  /// **'امسح باركود المنتج لإضافته إلى متجرك. لا يدخل سلة البيع.'**
  String get invInstruction;

  /// No description provided for @invWaiting.
  ///
  /// In ar, this message translates to:
  /// **'أكمل النموذج أو أغلقه لمسح المنتج التالي'**
  String get invWaiting;

  /// No description provided for @invCloseA11y.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق الكاميرا والعودة إلى المنتجات'**
  String get invCloseA11y;

  /// No description provided for @invBackToScanning.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق والعودة إلى المسح'**
  String get invBackToScanning;

  /// No description provided for @invStockNow.
  ///
  /// In ar, this message translates to:
  /// **'المخزون الآن {stock}'**
  String invStockNow(String stock);

  /// No description provided for @invExistsNote.
  ///
  /// In ar, this message translates to:
  /// **'هذا المنتج في متجرك، فلن يُضاف مرة ثانية. لإدخال بضاعة جديدة منه اختر «إضافة كمية».'**
  String get invExistsNote;

  /// No description provided for @invAddStock.
  ///
  /// In ar, this message translates to:
  /// **'إضافة كمية'**
  String get invAddStock;

  /// No description provided for @invAddStockQty.
  ///
  /// In ar, this message translates to:
  /// **'الكمية المستلمة ({unit})'**
  String invAddStockQty(String unit);

  /// No description provided for @invReason.
  ///
  /// In ar, this message translates to:
  /// **'السبب'**
  String get invReason;

  /// No description provided for @invReasonDefault.
  ///
  /// In ar, this message translates to:
  /// **'بضاعة واردة'**
  String get invReasonDefault;

  /// No description provided for @invReasonRequired.
  ///
  /// In ar, this message translates to:
  /// **'اكتب سبب إضافة الكمية.'**
  String get invReasonRequired;

  /// No description provided for @invQtyPiece.
  ///
  /// In ar, this message translates to:
  /// **'أدخل عدداً صحيحاً أكبر من صفر.'**
  String get invQtyPiece;

  /// No description provided for @invQtyKg.
  ///
  /// In ar, this message translates to:
  /// **'أدخل وزناً أكبر من صفر، حتى 3 خانات عشرية.'**
  String get invQtyKg;

  /// No description provided for @invAddStockSave.
  ///
  /// In ar, this message translates to:
  /// **'إضافة إلى المخزون'**
  String get invAddStockSave;

  /// No description provided for @invStockAdded.
  ///
  /// In ar, this message translates to:
  /// **'أُضيفت الكمية إلى «{name}». المخزون الآن {stock}'**
  String invStockAdded(String name, String stock);

  /// No description provided for @invStockForbidden.
  ///
  /// In ar, this message translates to:
  /// **'تعديل المخزون للمالك أو المدير.'**
  String get invStockForbidden;

  /// No description provided for @invOpeningStock.
  ///
  /// In ar, this message translates to:
  /// **'الكمية الموجودة الآن ({unit})'**
  String invOpeningStock(String unit);

  /// No description provided for @invNetworkUncertain.
  ///
  /// In ar, this message translates to:
  /// **'انقطع الاتصال قبل أن يصل رد الخادم، فقد يكون الحفظ تمّ. بياناتك باقية؛ اضغط «إعادة المحاولة» وسنتحقق دون تكرار المنتج.'**
  String get invNetworkUncertain;

  /// No description provided for @invFromCatalog.
  ///
  /// In ar, this message translates to:
  /// **'معروف في حسبة: الاسم والوحدة جاهزان. أكمل أسعار متجرك والكمية.'**
  String get invFromCatalog;

  /// No description provided for @packWord.
  ///
  /// In ar, this message translates to:
  /// **'كرتونة'**
  String get packWord;

  /// No description provided for @unitChipPack.
  ///
  /// In ar, this message translates to:
  /// **'كرتونة ×{size}'**
  String unitChipPack(int size);

  /// No description provided for @packPer.
  ///
  /// In ar, this message translates to:
  /// **'كرتونة ({size} قطعة)'**
  String packPer(int size);

  /// No description provided for @packEquals.
  ///
  /// In ar, this message translates to:
  /// **'= {pieces} قطعة'**
  String packEquals(String pieces);

  /// No description provided for @addPackLine.
  ///
  /// In ar, this message translates to:
  /// **'+ كرتونة ({size} قطعة) بـ {price}'**
  String addPackLine(int size, String price);

  /// No description provided for @packToggle.
  ///
  /// In ar, this message translates to:
  /// **'يُباع بالكرتونة أيضاً (جملة)'**
  String get packToggle;

  /// No description provided for @packToggleSub.
  ///
  /// In ar, this message translates to:
  /// **'المخزون يبقى بالقطعة؛ بيع كرتونة يخصم كل قطعها.'**
  String get packToggleSub;

  /// No description provided for @packSizeLabel.
  ///
  /// In ar, this message translates to:
  /// **'عدد القطع في الكرتونة'**
  String get packSizeLabel;

  /// No description provided for @packPriceLabel.
  ///
  /// In ar, this message translates to:
  /// **'سعر الكرتونة كاملة'**
  String get packPriceLabel;

  /// No description provided for @packSizeInvalid.
  ///
  /// In ar, this message translates to:
  /// **'عدد صحيح من 2 إلى 10000.'**
  String get packSizeInvalid;

  /// No description provided for @packPriceNotAbovePiece.
  ///
  /// In ar, this message translates to:
  /// **'سعر الكرتونة يجب أن يكون أعلى من سعر القطعة. هل أدخلت سعر القطعة هنا؟'**
  String get packPriceNotAbovePiece;

  /// No description provided for @packPerPiece.
  ///
  /// In ar, this message translates to:
  /// **'القطعة داخل الكرتونة بـ {price}.'**
  String packPerPiece(String price);

  /// No description provided for @packPerPieceVs.
  ///
  /// In ar, this message translates to:
  /// **'القطعة داخل الكرتونة بـ {pack} مقابل {piece} بالمفرد.'**
  String packPerPieceVs(String pack, String piece);

  /// No description provided for @invQtyPack.
  ///
  /// In ar, this message translates to:
  /// **'أدخل عدداً صحيحاً من الكراتين أكبر من صفر.'**
  String get invQtyPack;
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
