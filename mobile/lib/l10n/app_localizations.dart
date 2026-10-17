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
  /// **'الرئيسية ✓'**
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
