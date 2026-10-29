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

  /// No description provided for @guideTitle.
  ///
  /// In ar, this message translates to:
  /// **'دليل الاستخدام'**
  String get guideTitle;

  /// No description provided for @guideCardTitle.
  ///
  /// In ar, this message translates to:
  /// **'جديد على حسبة؟'**
  String get guideCardTitle;

  /// No description provided for @guideCardBody.
  ///
  /// In ar, this message translates to:
  /// **'جرّب في دقيقتين: أضف صنفاً بالباركود، ثم بِعه في فاتورة.'**
  String get guideCardBody;

  /// No description provided for @guideStart.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الدليل'**
  String get guideStart;

  /// No description provided for @guideLater.
  ///
  /// In ar, this message translates to:
  /// **'لاحقاً'**
  String get guideLater;

  /// No description provided for @guideStep.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة {n} من {total}'**
  String guideStep(int n, int total);

  /// No description provided for @guideWelcomeTitle.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً بك في حسبة'**
  String get guideWelcomeTitle;

  /// No description provided for @guideWelcomeBody.
  ///
  /// In ar, this message translates to:
  /// **'سنجرب معاً أهم شيئين في المحل: إضافة صنف بالباركود، وعمل فاتورة بالباركود. كل ما تفعله هنا حقيقي ويُحفظ في متجرك.'**
  String get guideWelcomeBody;

  /// No description provided for @guideAddTitle.
  ///
  /// In ar, this message translates to:
  /// **'أضف صنفك الأول بالباركود'**
  String get guideAddTitle;

  /// No description provided for @guideAdd1.
  ///
  /// In ar, this message translates to:
  /// **'اضغط «امسح صنفاً الآن» ووجّه الكاميرا إلى باركود أي صنف في محلك.'**
  String get guideAdd1;

  /// No description provided for @guideAdd2.
  ///
  /// In ar, this message translates to:
  /// **'إن كان الصنف معروفاً نملأ اسمه، وأنت تكتب السعر والكمية الموجودة.'**
  String get guideAdd2;

  /// No description provided for @guideAdd3.
  ///
  /// In ar, this message translates to:
  /// **'اضغط «حفظ»، ثم ارجع لتكمل الدليل.'**
  String get guideAdd3;

  /// No description provided for @guideAddAction.
  ///
  /// In ar, this message translates to:
  /// **'امسح صنفاً الآن'**
  String get guideAddAction;

  /// No description provided for @guideAddDone.
  ///
  /// In ar, this message translates to:
  /// **'أضفت صنفك الأول. أحسنت!'**
  String get guideAddDone;

  /// No description provided for @guideSaleTitle.
  ///
  /// In ar, this message translates to:
  /// **'اعمل فاتورتك الأولى بالباركود'**
  String get guideSaleTitle;

  /// No description provided for @guideSale1.
  ///
  /// In ar, this message translates to:
  /// **'اضغط «افتح شاشة البيع» ثم امسح الصنف؛ يدخل السلة فوراً.'**
  String get guideSale1;

  /// No description provided for @guideSale2.
  ///
  /// In ar, this message translates to:
  /// **'امسح الصنف مرة ثانية لزيادة الكمية، أو امسح أصناف أخرى.'**
  String get guideSale2;

  /// No description provided for @guideSale3.
  ///
  /// In ar, this message translates to:
  /// **'اضغط «إتمام البيع»، اختر نقداً أو ديناً على زبون، ثم احفظ الفاتورة.'**
  String get guideSale3;

  /// No description provided for @guideSaleAction.
  ///
  /// In ar, this message translates to:
  /// **'افتح شاشة البيع'**
  String get guideSaleAction;

  /// No description provided for @guideDoneTitle.
  ///
  /// In ar, this message translates to:
  /// **'جاهز للعمل!'**
  String get guideDoneTitle;

  /// No description provided for @guideDoneBody.
  ///
  /// In ar, this message translates to:
  /// **'الفواتير في «المبيعات»، والديون في «الزبائن»، والمخزون في «البضاعة». الإعدادات والدعم الفني في «المزيد»، ومنها تفتح هذا الدليل متى شئت.'**
  String get guideDoneBody;

  /// No description provided for @guideFinish.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ العمل'**
  String get guideFinish;

  /// No description provided for @guideNext.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get guideNext;

  /// No description provided for @guideSkip.
  ///
  /// In ar, this message translates to:
  /// **'تخطَّ هذه الخطوة'**
  String get guideSkip;

  /// No description provided for @moreGuideSub.
  ///
  /// In ar, this message translates to:
  /// **'جرّب إضافة صنف وعمل فاتورة خطوة بخطوة'**
  String get moreGuideSub;

  /// No description provided for @moreSupport.
  ///
  /// In ar, this message translates to:
  /// **'الدعم الفني'**
  String get moreSupport;

  /// No description provided for @moreSupportSub.
  ///
  /// In ar, this message translates to:
  /// **'أرسل شكوى أو اقتراحاً لفريق حسبة'**
  String get moreSupportSub;

  /// No description provided for @supportType.
  ///
  /// In ar, this message translates to:
  /// **'نوع الدعم'**
  String get supportType;

  /// No description provided for @supportTypeTechnical.
  ///
  /// In ar, this message translates to:
  /// **'مشكلة تقنية'**
  String get supportTypeTechnical;

  /// No description provided for @supportTypeAccount.
  ///
  /// In ar, this message translates to:
  /// **'الحساب والاشتراك'**
  String get supportTypeAccount;

  /// No description provided for @supportTypeSuggestion.
  ///
  /// In ar, this message translates to:
  /// **'اقتراح'**
  String get supportTypeSuggestion;

  /// No description provided for @supportTypeOther.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get supportTypeOther;

  /// No description provided for @supportSubject.
  ///
  /// In ar, this message translates to:
  /// **'موضوع المشكلة'**
  String get supportSubject;

  /// No description provided for @phSupportSubject.
  ///
  /// In ar, this message translates to:
  /// **'بكلمات قليلة، مثل: الطابعة لا تطبع الإيصال'**
  String get phSupportSubject;

  /// No description provided for @supportDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل المشكلة'**
  String get supportDetails;

  /// No description provided for @phSupportDetails.
  ///
  /// In ar, this message translates to:
  /// **'ماذا حدث، وأين، ومتى؟ كلما كتبت أكثر ساعدناك أسرع'**
  String get phSupportDetails;

  /// No description provided for @supportSend.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الشكوى'**
  String get supportSend;

  /// No description provided for @supportSent.
  ///
  /// In ar, this message translates to:
  /// **'وصلت شكواك إلى فريق حسبة، وسنرد عليك هنا.'**
  String get supportSent;

  /// No description provided for @supportTypeRequired.
  ///
  /// In ar, this message translates to:
  /// **'اختر نوع الدعم.'**
  String get supportTypeRequired;

  /// No description provided for @supportSubjectRequired.
  ///
  /// In ar, this message translates to:
  /// **'اكتب موضوع المشكلة.'**
  String get supportSubjectRequired;

  /// No description provided for @supportDetailsRequired.
  ///
  /// In ar, this message translates to:
  /// **'اكتب تفاصيل المشكلة.'**
  String get supportDetailsRequired;

  /// No description provided for @supportMine.
  ///
  /// In ar, this message translates to:
  /// **'شكاواي'**
  String get supportMine;

  /// No description provided for @supportNone.
  ///
  /// In ar, this message translates to:
  /// **'لم ترسل أي شكوى بعد.'**
  String get supportNone;

  /// No description provided for @supportStatusOpen.
  ///
  /// In ar, this message translates to:
  /// **'جديدة'**
  String get supportStatusOpen;

  /// No description provided for @supportStatusInProgress.
  ///
  /// In ar, this message translates to:
  /// **'قيد المعالجة'**
  String get supportStatusInProgress;

  /// No description provided for @supportStatusClosed.
  ///
  /// In ar, this message translates to:
  /// **'مغلقة'**
  String get supportStatusClosed;

  /// No description provided for @supportReply.
  ///
  /// In ar, this message translates to:
  /// **'رد فريق حسبة'**
  String get supportReply;

  /// No description provided for @supportLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الشكاوى. تحقق من الاتصال ثم أعد المحاولة.'**
  String get supportLoadError;

  /// No description provided for @phBarcode.
  ///
  /// In ar, this message translates to:
  /// **'الرقم تحت خطوط الباركود على العبوة'**
  String get phBarcode;

  /// No description provided for @phOpeningStock.
  ///
  /// In ar, this message translates to:
  /// **'كم عندك منه على الرف الآن'**
  String get phOpeningStock;

  /// No description provided for @phPackSize.
  ///
  /// In ar, this message translates to:
  /// **'كم قطعة في الكرتونة'**
  String get phPackSize;

  /// No description provided for @phPackPrice.
  ///
  /// In ar, this message translates to:
  /// **'سعر الكرتونة كاملة للزبون'**
  String get phPackPrice;

  /// No description provided for @phAddQty.
  ///
  /// In ar, this message translates to:
  /// **'كم وصلك من هذه البضاعة'**
  String get phAddQty;

  /// No description provided for @phReason.
  ///
  /// In ar, this message translates to:
  /// **'سبب تغيير المخزون، مثل: بضاعة واردة'**
  String get phReason;

  /// No description provided for @phAdjustQty.
  ///
  /// In ar, this message translates to:
  /// **'الكمية حسب نوع التعديل المختار أعلاه'**
  String get phAdjustQty;

  /// No description provided for @phStoreName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الذي يظهر أعلى الإيصال'**
  String get phStoreName;

  /// No description provided for @phAddress.
  ///
  /// In ar, this message translates to:
  /// **'الشارع أو أقرب معلم، يظهر على الإيصال'**
  String get phAddress;

  /// No description provided for @phArea.
  ///
  /// In ar, this message translates to:
  /// **'المدينة أو المنطقة، مثل: نابلس'**
  String get phArea;

  /// No description provided for @phCurrentPw.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور التي تدخل بها الآن'**
  String get phCurrentPw;

  /// No description provided for @phConfirmPw.
  ///
  /// In ar, this message translates to:
  /// **'اكتب كلمة المرور الجديدة مرة ثانية'**
  String get phConfirmPw;

  /// No description provided for @phLoginPw.
  ///
  /// In ar, this message translates to:
  /// **'كلمة مرور حسابك'**
  String get phLoginPw;

  /// No description provided for @phRegStoreName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المحل كما يعرفه الزبائن'**
  String get phRegStoreName;

  /// No description provided for @phOwnerName.
  ///
  /// In ar, this message translates to:
  /// **'اسمك الكامل'**
  String get phOwnerName;

  /// No description provided for @phStreet.
  ///
  /// In ar, this message translates to:
  /// **'الشارع أو أقرب معلم'**
  String get phStreet;

  /// No description provided for @phPhone.
  ///
  /// In ar, this message translates to:
  /// **'رقم جوالك، مثل 0599123456'**
  String get phPhone;

  /// No description provided for @phEmail.
  ///
  /// In ar, this message translates to:
  /// **'بريدك الذي تدخل به، مثل name@store.ps'**
  String get phEmail;

  /// No description provided for @phCustomerName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الزبون كما تناديه'**
  String get phCustomerName;

  /// No description provided for @phPaidNow.
  ///
  /// In ar, this message translates to:
  /// **'كم دفع الزبون الآن بالشيكل'**
  String get phPaidNow;

  /// No description provided for @phPayAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ الذي دفعه الزبون بالشيكل'**
  String get phPayAmount;

  /// No description provided for @phVoidReason.
  ///
  /// In ar, this message translates to:
  /// **'لماذا تُلغى هذه الفاتورة'**
  String get phVoidReason;

  /// No description provided for @splashTagline.
  ///
  /// In ar, this message translates to:
  /// **'دفتر متجرك، في جيبك'**
  String get splashTagline;

  /// No description provided for @splashSubline.
  ///
  /// In ar, this message translates to:
  /// **'المبيعات والديون والبضاعة في مكان واحد'**
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
  /// **'البضاعة'**
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
  /// **'البضاعة والأصناف اللي قرّبت تخلص'**
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
  /// **'عرض بيانات صنف'**
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
  /// **'جارٍ البحث عن الصنف…'**
  String get scanSearchingProduct;

  /// No description provided for @scanHintTitle.
  ///
  /// In ar, this message translates to:
  /// **'صعب القراءة؟'**
  String get scanHintTitle;

  /// No description provided for @scanHintBody.
  ///
  /// In ar, this message translates to:
  /// **'قرّب الباركود ببطء، أمِل الصنف لتجنب اللمعان، وشغّل الإضاءة. أو أدخله يدويًا.'**
  String get scanHintBody;

  /// No description provided for @scanManual.
  ///
  /// In ar, this message translates to:
  /// **'إدخال الباركود يدويًا'**
  String get scanManual;

  /// No description provided for @scanFound.
  ///
  /// In ar, this message translates to:
  /// **'لقينا الصنف'**
  String get scanFound;

  /// No description provided for @scanPrice.
  ///
  /// In ar, this message translates to:
  /// **'سعر البيع'**
  String get scanPrice;

  /// No description provided for @scanStock.
  ///
  /// In ar, this message translates to:
  /// **'الكمية الموجودة'**
  String get scanStock;

  /// No description provided for @scanBarcodeLabel.
  ///
  /// In ar, this message translates to:
  /// **'الباركود'**
  String get scanBarcodeLabel;

  /// No description provided for @scanAnother.
  ///
  /// In ar, this message translates to:
  /// **'امسح صنف ثاني'**
  String get scanAnother;

  /// No description provided for @scanBackToSale.
  ///
  /// In ar, this message translates to:
  /// **'الرجوع إلى البيع'**
  String get scanBackToSale;

  /// No description provided for @scanNotFoundTitle.
  ///
  /// In ar, this message translates to:
  /// **'ما في صنف بهذا الباركود'**
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
  /// **'الأرقام كما تظهر تحت خطوط الباركود'**
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
  /// **'عرض الصنف'**
  String get manualSubmit;

  /// No description provided for @manualCancelA11y.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الإدخال اليدوي'**
  String get manualCancelA11y;

  /// No description provided for @lookupFailedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر عرض الصنف'**
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
  /// **'جارٍ البحث عن الصنف…'**
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
  /// **'لا يوجد صنف بهذا الرقم في متجرك:'**
  String get scanUnknownBody;

  /// No description provided for @scanLookupFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر البحث عن الصنف'**
  String get scanLookupFailed;

  /// No description provided for @scanLookupFailedBody.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من الاتصال ثم أعد المحاولة.'**
  String get scanLookupFailedBody;

  /// No description provided for @cartEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'امسح أول صنف لتبدأ'**
  String get cartEmptyTitle;

  /// No description provided for @cartEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'أو ابحث عنه بالاسم. البضاعة بالوزن تفتح شاشة إدخال الوزن.'**
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
  /// **'الكمية'**
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
  /// **'بحث عن صنف'**
  String get productSearchTitle;

  /// No description provided for @productSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث باسم الصنف أو الباركود'**
  String get productSearchHint;

  /// No description provided for @productSearchEmpty.
  ///
  /// In ar, this message translates to:
  /// **'ما في صنف بهذا الاسم'**
  String get productSearchEmpty;

  /// No description provided for @productSearchEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من الكتابة. البضاعة تُضاف من لوحة الإدارة على الويب.'**
  String get productSearchEmptyBody;

  /// No description provided for @productSearchError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل البضاعة'**
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
  /// **'رقم جوال الزبون، 10 أرقام'**
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
  /// **'ما في زبائن لسّا'**
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
  /// **'الباقي عليه'**
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
  /// **'قبض دفعة'**
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
  /// **'ما عليه ديون مفتوحة.'**
  String get custNoOpenDebts;

  /// No description provided for @custRecentPayments.
  ///
  /// In ar, this message translates to:
  /// **'آخر الدفعات'**
  String get custRecentPayments;

  /// No description provided for @custNoPayments.
  ///
  /// In ar, this message translates to:
  /// **'ما في دفعات لسّا.'**
  String get custNoPayments;

  /// No description provided for @custDebtSale.
  ///
  /// In ar, this message translates to:
  /// **'فاتورة #{id}'**
  String custDebtSale(int id);

  /// No description provided for @custDebtOpening.
  ///
  /// In ar, this message translates to:
  /// **'دين قديم'**
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
  /// **'كل الباقي'**
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
  /// **'الباقي هلّأ'**
  String get payNow;

  /// No description provided for @payThis.
  ///
  /// In ar, this message translates to:
  /// **'الدفعة'**
  String get payThis;

  /// No description provided for @payAfter.
  ///
  /// In ar, this message translates to:
  /// **'الباقي بعد الدفعة'**
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
  /// **'+ صنف'**
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
  /// **'ما في بضاعة لسّا'**
  String get prodEmptyTitle;

  /// No description provided for @prodEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'امسح رمز الصنف أو الباركود لإضافته بسرعة، أو استورد قائمتك من الويب.'**
  String get prodEmptyBody;

  /// No description provided for @prodNoResults.
  ///
  /// In ar, this message translates to:
  /// **'ما في بضاعة بهذا الاسم.'**
  String get prodNoResults;

  /// No description provided for @prodLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل البضاعة.'**
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
  /// **'إضافة صنف'**
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
  /// **'للأصناف بلا رمز، مثل الموزون'**
  String get addManualSub;

  /// No description provided for @addChecking.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحقق من الرمز…'**
  String get addChecking;

  /// No description provided for @addExistsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الصنف موجود'**
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
  /// **'هذا الرمز لا يحتوي بيانات صنف. أدخل الصنف يدوياً؛ لن نستخدم محتواه.'**
  String get addUnreadable;

  /// No description provided for @addManualNote.
  ///
  /// In ar, this message translates to:
  /// **'إدخال يدوي. الاسم وسعر البيع مطلوبان.'**
  String get addManualNote;

  /// No description provided for @addLookupFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التحقق من وجود الصنف الآن؛ سنتحقق عند الحفظ.'**
  String get addLookupFailed;

  /// No description provided for @addFromCatalog.
  ///
  /// In ar, this message translates to:
  /// **'هذا الصنف معروف في حسبة، فملأنا اسمه ووحدته. أدخل سعر البيع والتكلفة والكمية لمتجرك.'**
  String get addFromCatalog;

  /// No description provided for @formNewTitle.
  ///
  /// In ar, this message translates to:
  /// **'صنف جديد'**
  String get formNewTitle;

  /// No description provided for @formName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الصنف'**
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
  /// **'السعر للزبون (سعر البيع)'**
  String get formPrice;

  /// No description provided for @formCost.
  ///
  /// In ar, this message translates to:
  /// **'تكلفة الصنف عليك (سعر الشراء)'**
  String get formCost;

  /// No description provided for @formStock.
  ///
  /// In ar, this message translates to:
  /// **'الكمية الموجودة الآن'**
  String get formStock;

  /// No description provided for @formMin.
  ///
  /// In ar, this message translates to:
  /// **'نبّهني لمّا توصل الكمية إلى'**
  String get formMin;

  /// No description provided for @formNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسم الصنف.'**
  String get formNameRequired;

  /// No description provided for @formPriceInvalid.
  ///
  /// In ar, this message translates to:
  /// **'أدخل سعراً صحيحاً.'**
  String get formPriceInvalid;

  /// No description provided for @formStockPiece.
  ///
  /// In ar, this message translates to:
  /// **'عدد صحيح للصنف بالقطعة.'**
  String get formStockPiece;

  /// No description provided for @formStockKg.
  ///
  /// In ar, this message translates to:
  /// **'حتى 3 خانات عشرية.'**
  String get formStockKg;

  /// No description provided for @formSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ الصنف'**
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
  /// **'إضافة البضاعة للمالك أو المدير. اطلب من المالك إضافته.'**
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
  /// **'امسح صنف ثاني'**
  String get savedScanNext;

  /// No description provided for @savedBack.
  ///
  /// In ar, this message translates to:
  /// **'الرجوع للبضاعة'**
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
  /// **'بضاعة تحت الحد: {count}'**
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
  /// **'كلمة مرور للدخول، 8 أحرف على الأقل'**
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
  /// **'بياناتك محفوظة كما هي: الزبائن والديون والمبيعات والبضاعة. يعود كل شيء فور تفعيل الاشتراك.'**
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
  /// **'مسح أصناف البيع'**
  String get saleScanTitle;

  /// No description provided for @saleScanKeepGoing.
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا شغّالة: امسح الصنف اللي بعده'**
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
  /// **'وجّه الكاميرا إلى باركود الصنف. تبقى الكاميرا مفتوحة لتضيف البضاعة واحداً تلو الآخر.'**
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
  /// **'إضافة بضاعة بالمسح'**
  String get invTitle;

  /// No description provided for @invInstruction.
  ///
  /// In ar, this message translates to:
  /// **'امسح باركود الصنف لإضافته إلى متجرك. لا يدخل سلة البيع.'**
  String get invInstruction;

  /// No description provided for @invWaiting.
  ///
  /// In ar, this message translates to:
  /// **'أكمل النموذج أو أغلقه لمسح الصنف التالي'**
  String get invWaiting;

  /// No description provided for @invCloseA11y.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق الكاميرا والرجوع للبضاعة'**
  String get invCloseA11y;

  /// No description provided for @invBackToScanning.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق والعودة إلى المسح'**
  String get invBackToScanning;

  /// No description provided for @invStockNow.
  ///
  /// In ar, this message translates to:
  /// **'الكمية الآن {stock}'**
  String invStockNow(String stock);

  /// No description provided for @invExistsNote.
  ///
  /// In ar, this message translates to:
  /// **'هذا الصنف في متجرك، فلن يُضاف مرة ثانية. لإدخال بضاعة جديدة منه اختر «إضافة كمية».'**
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
  /// **'إضافة للكمية'**
  String get invAddStockSave;

  /// No description provided for @invStockAdded.
  ///
  /// In ar, this message translates to:
  /// **'أُضيفت الكمية إلى «{name}». الكمية الآن {stock}'**
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
  /// **'انقطع الاتصال قبل أن يصل رد الخادم، فقد يكون الحفظ تمّ. بياناتك باقية؛ اضغط «إعادة المحاولة» وسنتحقق دون تكرار الصنف.'**
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

  /// No description provided for @formPriceHelpPiece.
  ///
  /// In ar, this message translates to:
  /// **'ما يدفعه الزبون مقابل قطعة واحدة.'**
  String get formPriceHelpPiece;

  /// No description provided for @formPriceHelpKg.
  ///
  /// In ar, this message translates to:
  /// **'ما يدفعه الزبون مقابل كيلو واحد.'**
  String get formPriceHelpKg;

  /// No description provided for @formCostHelp.
  ///
  /// In ar, this message translates to:
  /// **'ما تدفعه للمورّد، لا يراه الزبون'**
  String get formCostHelp;

  /// No description provided for @formMinHelp.
  ///
  /// In ar, this message translates to:
  /// **'عند هذا العدد أو أقل يظهر في «منخفض»'**
  String get formMinHelp;

  /// No description provided for @formRequiredA11y.
  ///
  /// In ar, this message translates to:
  /// **'مطلوب'**
  String get formRequiredA11y;

  /// No description provided for @formFixErrors.
  ///
  /// In ar, this message translates to:
  /// **'راجع الحقول المعلَّمة باللون الأحمر.'**
  String get formFixErrors;

  /// No description provided for @subscriptionHowTo.
  ///
  /// In ar, this message translates to:
  /// **'بعد الدفع تفعّل إدارة حسبة اشتراكك، ثم اضغط «تحقق من جديد» لتعود إلى متجرك.'**
  String get subscriptionHowTo;

  /// No description provided for @subscriptionDetails.
  ///
  /// In ar, this message translates to:
  /// **'اذكر هذه البيانات عند التواصل:'**
  String get subscriptionDetails;

  /// No description provided for @subscriptionStoreLine.
  ///
  /// In ar, this message translates to:
  /// **'المتجر: {store}'**
  String subscriptionStoreLine(String store);

  /// No description provided for @subscriptionEmailLine.
  ///
  /// In ar, this message translates to:
  /// **'البريد: {email}'**
  String subscriptionEmailLine(String email);

  /// No description provided for @subscriptionCopy.
  ///
  /// In ar, this message translates to:
  /// **'نسخ البيانات'**
  String get subscriptionCopy;

  /// No description provided for @subscriptionCopied.
  ///
  /// In ar, this message translates to:
  /// **'نُسخت البيانات.'**
  String get subscriptionCopied;

  /// No description provided for @discardTitle.
  ///
  /// In ar, this message translates to:
  /// **'تجاهل ما كتبته؟'**
  String get discardTitle;

  /// No description provided for @discardBody.
  ///
  /// In ar, this message translates to:
  /// **'لم يُحفظ هذا الصنف بعد. إذا خرجت الآن ستضيع البيانات التي أدخلتها.'**
  String get discardBody;

  /// No description provided for @discardKeep.
  ///
  /// In ar, this message translates to:
  /// **'متابعة الإدخال'**
  String get discardKeep;

  /// No description provided for @discardConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تجاهل وخروج'**
  String get discardConfirm;

  /// No description provided for @saleDetailError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الفاتورة. تحقق من الاتصال ثم أعد المحاولة.'**
  String get saleDetailError;

  /// No description provided for @saleReturnedNote.
  ///
  /// In ar, this message translates to:
  /// **'أُرجعت بضاعة من هذه الفاتورة بقيمة {amount}.'**
  String saleReturnedNote(String amount);

  /// No description provided for @moreSectionStore.
  ///
  /// In ar, this message translates to:
  /// **'المحل'**
  String get moreSectionStore;

  /// No description provided for @moreStaff.
  ///
  /// In ar, this message translates to:
  /// **'الموظفون'**
  String get moreStaff;

  /// No description provided for @moreStaffSub.
  ///
  /// In ar, this message translates to:
  /// **'دعوة موظف، تغيير الدور، الإيقاف'**
  String get moreStaffSub;

  /// No description provided for @moreStoreInfo.
  ///
  /// In ar, this message translates to:
  /// **'بيانات المحل'**
  String get moreStoreInfo;

  /// No description provided for @moreStoreInfoSub.
  ///
  /// In ar, this message translates to:
  /// **'الاسم والهاتف والعنوان على الإيصال'**
  String get moreStoreInfoSub;

  /// No description provided for @moreSectionStock.
  ///
  /// In ar, this message translates to:
  /// **'البضاعة والكميات'**
  String get moreSectionStock;

  /// No description provided for @moreLowStock.
  ///
  /// In ar, this message translates to:
  /// **'بضاعة قرّبت تخلص'**
  String get moreLowStock;

  /// No description provided for @moreLowStockSub.
  ///
  /// In ar, this message translates to:
  /// **'عند الحد الأدنى أو أقل'**
  String get moreLowStockSub;

  /// No description provided for @moreNegative.
  ///
  /// In ar, this message translates to:
  /// **'مخزون سالب للمراجعة'**
  String get moreNegative;

  /// No description provided for @moreNegativeSub.
  ///
  /// In ar, this message translates to:
  /// **'بيعت بأكثر من الكمية المسجّلة'**
  String get moreNegativeSub;

  /// No description provided for @moreSectionSales.
  ///
  /// In ar, this message translates to:
  /// **'المبيعات'**
  String get moreSectionSales;

  /// No description provided for @moreSalesHistory.
  ///
  /// In ar, this message translates to:
  /// **'سجل المبيعات'**
  String get moreSalesHistory;

  /// No description provided for @moreSalesHistorySub.
  ///
  /// In ar, this message translates to:
  /// **'كل الفواتير، وفتح أي فاتورة كاملة'**
  String get moreSalesHistorySub;

  /// No description provided for @moreSectionSettings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get moreSectionSettings;

  /// No description provided for @morePassword.
  ///
  /// In ar, this message translates to:
  /// **'تغيير كلمة المرور'**
  String get morePassword;

  /// No description provided for @morePasswordSub.
  ///
  /// In ar, this message translates to:
  /// **'ويُسجَّل الخروج من الأجهزة الأخرى'**
  String get morePasswordSub;

  /// No description provided for @moreSubscription.
  ///
  /// In ar, this message translates to:
  /// **'الاشتراك'**
  String get moreSubscription;

  /// No description provided for @moreSubTrialUntil.
  ///
  /// In ar, this message translates to:
  /// **'تجربة مجانية حتى {date}'**
  String moreSubTrialUntil(String date);

  /// No description provided for @moreSubActiveUntil.
  ///
  /// In ar, this message translates to:
  /// **'مفعّل حتى {date}'**
  String moreSubActiveUntil(String date);

  /// No description provided for @moreSubActive.
  ///
  /// In ar, this message translates to:
  /// **'مفعّل'**
  String get moreSubActive;

  /// No description provided for @moreSubContact.
  ///
  /// In ar, this message translates to:
  /// **'تواصل مع إدارة حسبة عبر واتساب'**
  String get moreSubContact;

  /// No description provided for @moreSubWhatsappText.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً، بخصوص اشتراك متجر «{store}» على حسبة.'**
  String moreSubWhatsappText(String store);

  /// No description provided for @staffTitle.
  ///
  /// In ar, this message translates to:
  /// **'الموظفون'**
  String get staffTitle;

  /// No description provided for @staffInvite.
  ///
  /// In ar, this message translates to:
  /// **'دعوة موظف'**
  String get staffInvite;

  /// No description provided for @staffEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا موظفين بعد. ادعُ أول موظف برابط يفتحه من جواله.'**
  String get staffEmpty;

  /// No description provided for @staffYou.
  ///
  /// In ar, this message translates to:
  /// **'أنت'**
  String get staffYou;

  /// No description provided for @staffInactive.
  ///
  /// In ar, this message translates to:
  /// **'موقوف'**
  String get staffInactive;

  /// No description provided for @staffMakeManager.
  ///
  /// In ar, this message translates to:
  /// **'جعله مديراً'**
  String get staffMakeManager;

  /// No description provided for @staffMakeEmployee.
  ///
  /// In ar, this message translates to:
  /// **'جعله موظفاً'**
  String get staffMakeEmployee;

  /// No description provided for @staffDeactivate.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف الموظف'**
  String get staffDeactivate;

  /// No description provided for @staffDeactivateTitle.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف {name}؟'**
  String staffDeactivateTitle(String name);

  /// No description provided for @staffDeactivateBody.
  ///
  /// In ar, this message translates to:
  /// **'يُسجَّل خروجه من كل الأجهزة فوراً ولن يستطيع الدخول. فواتيره ودفعاته تبقى باسمه في السجل.'**
  String get staffDeactivateBody;

  /// No description provided for @staffRolesNote.
  ///
  /// In ar, this message translates to:
  /// **'المدير: كل شيء عدا الموظفين وبيانات المحل. الموظف: البيع والزبائن وتسجيل الدفعات، بلا مرتجع أو إلغاء فاتورة أو تعديل مخزون أو تجاوز حد الدين.'**
  String get staffRolesNote;

  /// No description provided for @staffLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الموظفين. تحقق من الاتصال ثم أعد المحاولة.'**
  String get staffLoadError;

  /// No description provided for @staffActionError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تنفيذ الإجراء. تحقق من الاتصال ثم حاول مرة أخرى.'**
  String get staffActionError;

  /// No description provided for @staffOwnerOnly.
  ///
  /// In ar, this message translates to:
  /// **'إدارة الموظفين للمالك فقط.'**
  String get staffOwnerOnly;

  /// No description provided for @staffRoleChanged.
  ///
  /// In ar, this message translates to:
  /// **'أصبح {name} {role}.'**
  String staffRoleChanged(String name, String role);

  /// No description provided for @staffDeactivated.
  ///
  /// In ar, this message translates to:
  /// **'أُوقف {name}.'**
  String staffDeactivated(String name);

  /// No description provided for @inviteRole.
  ///
  /// In ar, this message translates to:
  /// **'الدور'**
  String get inviteRole;

  /// No description provided for @inviteValid.
  ///
  /// In ar, this message translates to:
  /// **'صلاحية الرابط'**
  String get inviteValid;

  /// No description provided for @invite24h.
  ///
  /// In ar, this message translates to:
  /// **'24 ساعة'**
  String get invite24h;

  /// No description provided for @invite3d.
  ///
  /// In ar, this message translates to:
  /// **'3 أيام'**
  String get invite3d;

  /// No description provided for @invite7d.
  ///
  /// In ar, this message translates to:
  /// **'7 أيام'**
  String get invite7d;

  /// No description provided for @inviteEmail.
  ///
  /// In ar, this message translates to:
  /// **'بريده الإلكتروني'**
  String get inviteEmail;

  /// No description provided for @inviteEmailHint.
  ///
  /// In ar, this message translates to:
  /// **'إن كتبته، لا يعمل الرابط إلا بهذا البريد'**
  String get inviteEmailHint;

  /// No description provided for @inviteCreate.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء رابط الدعوة'**
  String get inviteCreate;

  /// No description provided for @inviteCreating.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الإنشاء…'**
  String get inviteCreating;

  /// No description provided for @inviteReady.
  ///
  /// In ar, this message translates to:
  /// **'الدعوة جاهزة. أرسل الرابط إلى الموظف؛ يظهر هنا مرة واحدة فقط.'**
  String get inviteReady;

  /// No description provided for @inviteExpires.
  ///
  /// In ar, this message translates to:
  /// **'ينتهي في {date}'**
  String inviteExpires(String date);

  /// No description provided for @inviteHowTo.
  ///
  /// In ar, this message translates to:
  /// **'يفتح الموظف الرابط، يكتب اسمه وبريده وكلمة مرور، ثم يدخل من تطبيق حسبة.'**
  String get inviteHowTo;

  /// No description provided for @inviteCopy.
  ///
  /// In ar, this message translates to:
  /// **'نسخ الرابط'**
  String get inviteCopy;

  /// No description provided for @inviteCopied.
  ///
  /// In ar, this message translates to:
  /// **'نُسخ الرابط.'**
  String get inviteCopied;

  /// No description provided for @inviteWhatsapp.
  ///
  /// In ar, this message translates to:
  /// **'إرسال عبر واتساب'**
  String get inviteWhatsapp;

  /// No description provided for @inviteWhatsappText.
  ///
  /// In ar, this message translates to:
  /// **'دعوة للانضمام إلى متجر «{store}» على حسبة كـ{role}. افتح الرابط وأنشئ حسابك:\n{link}'**
  String inviteWhatsappText(String store, String role, String link);

  /// No description provided for @inviteWhatsappFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح واتساب. انسخ الرابط وأرسله بأي طريقة.'**
  String get inviteWhatsappFailed;

  /// No description provided for @inviteDone.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get inviteDone;

  /// No description provided for @storeTitle.
  ///
  /// In ar, this message translates to:
  /// **'بيانات المحل'**
  String get storeTitle;

  /// No description provided for @storeName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المحل'**
  String get storeName;

  /// No description provided for @storePhone.
  ///
  /// In ar, this message translates to:
  /// **'هاتف المحل'**
  String get storePhone;

  /// No description provided for @storePhoneHint.
  ///
  /// In ar, this message translates to:
  /// **'هاتف المحل على الإيصال، مثل 0599123456'**
  String get storePhoneHint;

  /// No description provided for @storeAddress.
  ///
  /// In ar, this message translates to:
  /// **'العنوان'**
  String get storeAddress;

  /// No description provided for @storeArea.
  ///
  /// In ar, this message translates to:
  /// **'المنطقة أو المدينة'**
  String get storeArea;

  /// No description provided for @storeReceiptNote.
  ///
  /// In ar, this message translates to:
  /// **'تظهر هذه البيانات أعلى كل إيصال.'**
  String get storeReceiptNote;

  /// No description provided for @storeSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ التغييرات'**
  String get storeSave;

  /// No description provided for @storeSaved.
  ///
  /// In ar, this message translates to:
  /// **'حُفظت بيانات المحل.'**
  String get storeSaved;

  /// No description provided for @storeOwnerOnly.
  ///
  /// In ar, this message translates to:
  /// **'تعديل بيانات المحل للمالك فقط.'**
  String get storeOwnerOnly;

  /// No description provided for @storeLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل بيانات المحل. تحقق من الاتصال ثم أعد المحاولة.'**
  String get storeLoadError;

  /// No description provided for @pwTitle.
  ///
  /// In ar, this message translates to:
  /// **'تغيير كلمة المرور'**
  String get pwTitle;

  /// No description provided for @pwCurrent.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الحالية'**
  String get pwCurrent;

  /// No description provided for @pwNew.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الجديدة'**
  String get pwNew;

  /// No description provided for @pwConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد كلمة المرور الجديدة'**
  String get pwConfirm;

  /// No description provided for @pwHelp.
  ///
  /// In ar, this message translates to:
  /// **'8 أحرف على الأقل، والأجهزة الأخرى تُسجَّل خارجاً'**
  String get pwHelp;

  /// No description provided for @pwSave.
  ///
  /// In ar, this message translates to:
  /// **'تغيير كلمة المرور'**
  String get pwSave;

  /// No description provided for @pwDone.
  ///
  /// In ar, this message translates to:
  /// **'تم تغيير كلمة المرور، وسُجّل الخروج من الأجهزة الأخرى.'**
  String get pwDone;

  /// No description provided for @pwCurrentRequired.
  ///
  /// In ar, this message translates to:
  /// **'اكتب كلمة المرور الحالية.'**
  String get pwCurrentRequired;

  /// No description provided for @pwShort.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور 8 أحرف على الأقل.'**
  String get pwShort;

  /// No description provided for @pwMismatch.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد كلمة المرور لا يطابقها.'**
  String get pwMismatch;

  /// No description provided for @salesTitle.
  ///
  /// In ar, this message translates to:
  /// **'سجل المبيعات'**
  String get salesTitle;

  /// No description provided for @salesToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get salesToday;

  /// No description provided for @sales7.
  ///
  /// In ar, this message translates to:
  /// **'آخر 7 أيام'**
  String get sales7;

  /// No description provided for @sales30.
  ///
  /// In ar, this message translates to:
  /// **'آخر 30 يوماً'**
  String get sales30;

  /// No description provided for @salesAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get salesAll;

  /// No description provided for @salesEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا مبيعات في هذه الفترة.'**
  String get salesEmpty;

  /// No description provided for @salesLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل المبيعات. تحقق من الاتصال ثم أعد المحاولة.'**
  String get salesLoadError;

  /// No description provided for @salesMore.
  ///
  /// In ar, this message translates to:
  /// **'عرض المزيد'**
  String get salesMore;

  /// No description provided for @salesMoreError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل المزيد. اضغط للمحاولة مرة أخرى.'**
  String get salesMoreError;

  /// No description provided for @salesWalkIn.
  ///
  /// In ar, this message translates to:
  /// **'بلا زبون'**
  String get salesWalkIn;

  /// No description provided for @salesItems.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{صنف واحد} =2{صنفان} few{{count} أصناف} many{{count} صنفاً} other{{count} صنف}}'**
  String salesItems(int count);

  /// No description provided for @saleStatusPaid.
  ///
  /// In ar, this message translates to:
  /// **'مدفوعة'**
  String get saleStatusPaid;

  /// No description provided for @saleStatusCredit.
  ///
  /// In ar, this message translates to:
  /// **'دين'**
  String get saleStatusCredit;

  /// No description provided for @saleStatusPartial.
  ///
  /// In ar, this message translates to:
  /// **'دفع جزئي'**
  String get saleStatusPartial;

  /// No description provided for @prodDetailError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الصنف. تحقق من الاتصال ثم أعد المحاولة.'**
  String get prodDetailError;

  /// No description provided for @prodStockNowLabel.
  ///
  /// In ar, this message translates to:
  /// **'الكمية الموجودة الآن'**
  String get prodStockNowLabel;

  /// No description provided for @prodMinimumLabel.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه عند {qty}'**
  String prodMinimumLabel(String qty);

  /// No description provided for @prodCostLabel.
  ///
  /// In ar, this message translates to:
  /// **'التكلفة {price}'**
  String prodCostLabel(String price);

  /// No description provided for @prodPackLabel.
  ///
  /// In ar, this message translates to:
  /// **'كرتونة {size} قطعة بـ {price}'**
  String prodPackLabel(int size, String price);

  /// No description provided for @prodEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الصنف'**
  String get prodEdit;

  /// No description provided for @prodAdjust.
  ///
  /// In ar, this message translates to:
  /// **'جرد أو تعديل الكمية'**
  String get prodAdjust;

  /// No description provided for @prodMovements.
  ///
  /// In ar, this message translates to:
  /// **'حركات البضاعة'**
  String get prodMovements;

  /// No description provided for @prodNoMovements.
  ///
  /// In ar, this message translates to:
  /// **'لا حركات بعد.'**
  String get prodNoMovements;

  /// No description provided for @prodDeactivate.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف الصنف'**
  String get prodDeactivate;

  /// No description provided for @prodDeactivateTitle.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف «{name}»؟'**
  String prodDeactivateTitle(String name);

  /// No description provided for @prodDeactivateBody.
  ///
  /// In ar, this message translates to:
  /// **'لن يظهر في البيع ولا في قائمة البضاعة. حركاته وفواتيره السابقة تبقى في السجل، وتستطيع إعادته متى شئت من «موقوفة».'**
  String get prodDeactivateBody;

  /// No description provided for @prodDeactivated.
  ///
  /// In ar, this message translates to:
  /// **'أُوقف «{name}».'**
  String prodDeactivated(String name);

  /// No description provided for @prodInactiveNote.
  ///
  /// In ar, this message translates to:
  /// **'هذا الصنف موقوف: لا يُباع ولا يظهر في القائمة.'**
  String get prodInactiveNote;

  /// No description provided for @prodFilterInactive.
  ///
  /// In ar, this message translates to:
  /// **'موقوفة'**
  String get prodFilterInactive;

  /// No description provided for @prodReactivate.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تفعيل الصنف'**
  String get prodReactivate;

  /// No description provided for @prodReactivated.
  ///
  /// In ar, this message translates to:
  /// **'رجع الصنف إلى البيع والقائمة كما كان.'**
  String get prodReactivated;

  /// No description provided for @invOpenProduct.
  ///
  /// In ar, this message translates to:
  /// **'تعديل السعر والتفاصيل'**
  String get invOpenProduct;

  /// No description provided for @prodSaved.
  ///
  /// In ar, this message translates to:
  /// **'حُفظت التعديلات.'**
  String get prodSaved;

  /// No description provided for @prodViewOnly.
  ///
  /// In ar, this message translates to:
  /// **'تعديل البضاعة والكمية للمالك أو المدير.'**
  String get prodViewOnly;

  /// No description provided for @moveOpening.
  ///
  /// In ar, this message translates to:
  /// **'رصيد افتتاحي'**
  String get moveOpening;

  /// No description provided for @moveSale.
  ///
  /// In ar, this message translates to:
  /// **'بيع'**
  String get moveSale;

  /// No description provided for @moveVoid.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء فاتورة'**
  String get moveVoid;

  /// No description provided for @moveReturn.
  ///
  /// In ar, this message translates to:
  /// **'مرتجع'**
  String get moveReturn;

  /// No description provided for @moveIn.
  ///
  /// In ar, this message translates to:
  /// **'تعديل: زيادة'**
  String get moveIn;

  /// No description provided for @moveOut.
  ///
  /// In ar, this message translates to:
  /// **'تعديل: خصم'**
  String get moveOut;

  /// No description provided for @moveAfter.
  ///
  /// In ar, this message translates to:
  /// **'بعدها {qty}'**
  String moveAfter(String qty);

  /// No description provided for @adjTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل كمية «{name}»'**
  String adjTitle(String name);

  /// No description provided for @adjCount.
  ///
  /// In ar, this message translates to:
  /// **'جرد الرف'**
  String get adjCount;

  /// No description provided for @adjDelta.
  ///
  /// In ar, this message translates to:
  /// **'إضافة أو خصم'**
  String get adjDelta;

  /// No description provided for @adjCartons.
  ///
  /// In ar, this message translates to:
  /// **'استلام كراتين'**
  String get adjCartons;

  /// No description provided for @adjCountLabel.
  ///
  /// In ar, this message translates to:
  /// **'كم يوجد الآن فعلياً؟ ({unit})'**
  String adjCountLabel(String unit);

  /// No description provided for @adjDeltaLabel.
  ///
  /// In ar, this message translates to:
  /// **'الكمية ({unit})، بإشارة سالبة للخصم'**
  String adjDeltaLabel(String unit);

  /// No description provided for @adjCartonsLabel.
  ///
  /// In ar, this message translates to:
  /// **'عدد الكراتين المستلمة ({size} قطعة لكل كرتونة)'**
  String adjCartonsLabel(int size);

  /// No description provided for @adjReason.
  ///
  /// In ar, this message translates to:
  /// **'السبب'**
  String get adjReason;

  /// No description provided for @adjReasonCount.
  ///
  /// In ar, this message translates to:
  /// **'جرد الرف'**
  String get adjReasonCount;

  /// No description provided for @adjReasonDamaged.
  ///
  /// In ar, this message translates to:
  /// **'تالف أو منتهي الصلاحية'**
  String get adjReasonDamaged;

  /// No description provided for @adjReasonReceived.
  ///
  /// In ar, this message translates to:
  /// **'استلام بضاعة'**
  String get adjReasonReceived;

  /// No description provided for @adjReasonFix.
  ///
  /// In ar, this message translates to:
  /// **'تصحيح خطأ إدخال'**
  String get adjReasonFix;

  /// No description provided for @adjPreview.
  ///
  /// In ar, this message translates to:
  /// **'المسجّل {from} ← بعد التعديل {to}'**
  String adjPreview(String from, String to);

  /// No description provided for @adjNoChange.
  ///
  /// In ar, this message translates to:
  /// **'العدد مطابق للمسجّل؛ لا شيء لتعديله.'**
  String get adjNoChange;

  /// No description provided for @adjNegative.
  ///
  /// In ar, this message translates to:
  /// **'المخزون لا يصبح سالباً بالتعديل.'**
  String get adjNegative;

  /// No description provided for @adjInvalidPiece.
  ///
  /// In ar, this message translates to:
  /// **'عدد صحيح للصنف بالقطعة.'**
  String get adjInvalidPiece;

  /// No description provided for @adjInvalidKg.
  ///
  /// In ar, this message translates to:
  /// **'حتى 3 خانات عشرية.'**
  String get adjInvalidKg;

  /// No description provided for @adjSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ التعديل'**
  String get adjSave;

  /// No description provided for @adjDone.
  ///
  /// In ar, this message translates to:
  /// **'تعدّلت الكمية. صارت {stock}'**
  String adjDone(String stock);

  /// No description provided for @lowTitle.
  ///
  /// In ar, this message translates to:
  /// **'بضاعة قرّبت تخلص'**
  String get lowTitle;

  /// No description provided for @lowEmpty.
  ///
  /// In ar, this message translates to:
  /// **'كل البضاعة فوق حد التنبيه.'**
  String get lowEmpty;

  /// No description provided for @lowRow.
  ///
  /// In ar, this message translates to:
  /// **'الكمية {stock} · التنبيه عند {min}'**
  String lowRow(String stock, String min);

  /// No description provided for @negTitle.
  ///
  /// In ar, this message translates to:
  /// **'مخزون سالب للمراجعة'**
  String get negTitle;

  /// No description provided for @negEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا أصناف بمخزون سالب.'**
  String get negEmpty;

  /// No description provided for @negHelp.
  ///
  /// In ar, this message translates to:
  /// **'بيعت هذه البضاعة بأكثر مما هو مسجّل. عُدّ الرف ثم صحّح المخزون من صفحة الصنف.'**
  String get negHelp;

  /// No description provided for @negSale.
  ///
  /// In ar, this message translates to:
  /// **'فاتورة #{id} · {qty}'**
  String negSale(int id, String qty);

  /// No description provided for @listLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التحميل. تحقق من الاتصال ثم أعد المحاولة.'**
  String get listLoadError;

  /// No description provided for @legacyAction.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل دين قديم'**
  String get legacyAction;

  /// No description provided for @legacyActionSub.
  ///
  /// In ar, this message translates to:
  /// **'دين على زبون من قبل ما تستعمل حسبة، من دفترك القديم'**
  String get legacyActionSub;

  /// No description provided for @legacyTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل دين قديم'**
  String get legacyTitle;

  /// No description provided for @legacyIntro.
  ///
  /// In ar, this message translates to:
  /// **'بيتسجّل كدين على الزبون بس: ما بينحسب بيع، وما بينقص من البضاعة، وما بيدخل الصندوق.'**
  String get legacyIntro;

  /// No description provided for @legacyCustomer.
  ///
  /// In ar, this message translates to:
  /// **'الزبون'**
  String get legacyCustomer;

  /// No description provided for @legacyPickCustomer.
  ///
  /// In ar, this message translates to:
  /// **'اختر الزبون'**
  String get legacyPickCustomer;

  /// No description provided for @legacyChange.
  ///
  /// In ar, this message translates to:
  /// **'تغيير'**
  String get legacyChange;

  /// No description provided for @legacyAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ اللي عليه'**
  String get legacyAmount;

  /// No description provided for @legacyAmountHint.
  ///
  /// In ar, this message translates to:
  /// **'مثلاً 150'**
  String get legacyAmountHint;

  /// No description provided for @legacyAmountInvalid.
  ///
  /// In ar, this message translates to:
  /// **'اكتب مبلغ صحيح أكبر من صفر، وبحد أقصى رقمين بعد الفاصلة.'**
  String get legacyAmountInvalid;

  /// No description provided for @legacyAmountTooBig.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ أكبر من المسموح.'**
  String get legacyAmountTooBig;

  /// No description provided for @legacyPartlyPaid.
  ///
  /// In ar, this message translates to:
  /// **'إذا الزبون دفع جزء منه قبل، اكتب الباقي عليه بس.'**
  String get legacyPartlyPaid;

  /// No description provided for @legacyOrigin.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الدين'**
  String get legacyOrigin;

  /// No description provided for @legacyOriginNone.
  ///
  /// In ar, this message translates to:
  /// **'مش محدد'**
  String get legacyOriginNone;

  /// No description provided for @legacyDue.
  ///
  /// In ar, this message translates to:
  /// **'موعد السداد (اختياري)'**
  String get legacyDue;

  /// No description provided for @legacyDueNone.
  ///
  /// In ar, this message translates to:
  /// **'بدون موعد'**
  String get legacyDueNone;

  /// No description provided for @legacyNote.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة (اختياري)'**
  String get legacyNote;

  /// No description provided for @legacyNoteHint.
  ///
  /// In ar, this message translates to:
  /// **'مثلاً: من دفتر الديون القديم'**
  String get legacyNoteHint;

  /// No description provided for @legacyClear.
  ///
  /// In ar, this message translates to:
  /// **'مسح'**
  String get legacyClear;

  /// No description provided for @legacySave.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدين'**
  String get legacySave;

  /// No description provided for @legacySaving.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التسجيل…'**
  String get legacySaving;

  /// No description provided for @legacyRetry.
  ///
  /// In ar, this message translates to:
  /// **'أعد المحاولة'**
  String get legacyRetry;

  /// No description provided for @legacyUncertain.
  ///
  /// In ar, this message translates to:
  /// **'انقطع الاتصال قبل ما يوصل رد الخادم، ويمكن يكون الدين تسجّل. اضغط «أعد المحاولة» وما رح يتسجّل مرتين.'**
  String get legacyUncertain;

  /// No description provided for @legacyConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الدين القديم'**
  String get legacyConfirmTitle;

  /// No description provided for @legacyConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'رح يتسجّل على {name} دين قديم بقيمة {amount}. بتقدر تعدّله أو تحذفه لاحقاً من لوحة الويب.'**
  String legacyConfirmBody(String name, String amount);

  /// No description provided for @legacyConfirmOk.
  ///
  /// In ar, this message translates to:
  /// **'نعم، سجّل'**
  String get legacyConfirmOk;

  /// No description provided for @legacyBack.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get legacyBack;

  /// No description provided for @legacyDone.
  ///
  /// In ar, this message translates to:
  /// **'تسجّل الدين القديم'**
  String get legacyDone;

  /// No description provided for @legacyDoneBody.
  ///
  /// In ar, this message translates to:
  /// **'صار على {name} دين قديم بقيمة {amount}.'**
  String legacyDoneBody(String name, String amount);

  /// No description provided for @legacyDoneButton.
  ///
  /// In ar, this message translates to:
  /// **'تمام'**
  String get legacyDoneButton;

  /// No description provided for @legacyForbidden.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الديون القديمة للمالك أو المدير.'**
  String get legacyForbidden;

  /// No description provided for @legacySince.
  ///
  /// In ar, this message translates to:
  /// **'من {date}'**
  String legacySince(String date);

  /// No description provided for @offlineSavedBanner.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال — البيع والدفعات تُحفظ على الهاتف وتُرسل عند عودة الإنترنت'**
  String get offlineSavedBanner;

  /// No description provided for @offlineSavedBannerCount.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال — {count} عملية محفوظة على الهاتف بانتظار الإرسال'**
  String offlineSavedBannerCount(int count);

  /// No description provided for @syncSynced.
  ///
  /// In ar, this message translates to:
  /// **'متزامن'**
  String get syncSynced;

  /// No description provided for @syncSyncing.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ المزامنة…'**
  String get syncSyncing;

  /// No description provided for @syncPending.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار المزامنة ({count})'**
  String syncPending(int count);

  /// No description provided for @syncOfflinePending.
  ///
  /// In ar, this message translates to:
  /// **'غير متصل · {count}'**
  String syncOfflinePending(int count);

  /// No description provided for @syncNeedsReview.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج مراجعة ({count})'**
  String syncNeedsReview(int count);

  /// No description provided for @syncNow.
  ///
  /// In ar, this message translates to:
  /// **'مزامنة الآن'**
  String get syncNow;

  /// No description provided for @syncTitle.
  ///
  /// In ar, this message translates to:
  /// **'المزامنة'**
  String get syncTitle;

  /// No description provided for @syncOfflineTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال · {count} عملية بانتظار الإرسال'**
  String syncOfflineTitle(int count);

  /// No description provided for @syncAllSent.
  ///
  /// In ar, this message translates to:
  /// **'كل العمليات وصلت إلى الخادم'**
  String get syncAllSent;

  /// No description provided for @syncStuck.
  ///
  /// In ar, this message translates to:
  /// **'{count} عملية تعذّر إرسالها عدة مرات. تواصل مع الدعم إن استمر ذلك.'**
  String syncStuck(int count);

  /// No description provided for @syncHeldTitle.
  ///
  /// In ar, this message translates to:
  /// **'أوقفها الخادم للمراجعة ({count})'**
  String syncHeldTitle(int count);

  /// No description provided for @syncHeldHelp.
  ///
  /// In ar, this message translates to:
  /// **'لم تُحذف. يراجعها المالك أو المدير من موقع حسبة على الويب.'**
  String get syncHeldHelp;

  /// No description provided for @syncHeldPayment.
  ///
  /// In ar, this message translates to:
  /// **'الدفعة أكبر من رصيد العميل الآن على الخادم.'**
  String get syncHeldPayment;

  /// No description provided for @syncHeldClock.
  ///
  /// In ar, this message translates to:
  /// **'وقت العملية خارج المدة المسموحة. راجع ساعة الهاتف.'**
  String get syncHeldClock;

  /// No description provided for @syncPendingTitle.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار الإرسال'**
  String get syncPendingTitle;

  /// No description provided for @syncNothingPending.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء بانتظار الإرسال.'**
  String get syncNothingPending;

  /// No description provided for @syncItemSale.
  ///
  /// In ar, this message translates to:
  /// **'بيع'**
  String get syncItemSale;

  /// No description provided for @syncItemCreditSale.
  ///
  /// In ar, this message translates to:
  /// **'بيع بالدين'**
  String get syncItemCreditSale;

  /// No description provided for @syncItemPayment.
  ///
  /// In ar, this message translates to:
  /// **'دفعة'**
  String get syncItemPayment;

  /// No description provided for @syncItemStuck.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الإرسال {count} مرة'**
  String syncItemStuck(int count);

  /// No description provided for @queueWarnBody.
  ///
  /// In ar, this message translates to:
  /// **'{count} عملية بانتظار المزامنة من أصل {limit}. اتصل بالإنترنت وزامن الآن.'**
  String queueWarnBody(int count, int limit);

  /// No description provided for @queueFullTitle.
  ///
  /// In ar, this message translates to:
  /// **'امتلأت قائمة الانتظار — لا يمكن حفظ بيع أو دفعة جديدة دون اتصال'**
  String get queueFullTitle;

  /// No description provided for @queueFullBody.
  ///
  /// In ar, this message translates to:
  /// **'على الهاتف 1000 عملية لم تُرسل بعد. اتصل بالإنترنت لإرسالها، ثم تابع. البحث والعرض يعملان.'**
  String get queueFullBody;

  /// No description provided for @receiptPendingNote.
  ///
  /// In ar, this message translates to:
  /// **'محفوظ على الهاتف بانتظار الإرسال. يُرسل تلقائيًا عند عودة الإنترنت.'**
  String get receiptPendingNote;

  /// No description provided for @receiptLocalRef.
  ///
  /// In ar, this message translates to:
  /// **'رقم مؤقت'**
  String get receiptLocalRef;

  /// No description provided for @payPendingNote.
  ///
  /// In ar, this message translates to:
  /// **'محفوظة على الهاتف ({ref}) وتُرسل عند عودة الإنترنت.'**
  String payPendingNote(String ref);

  /// No description provided for @logoutPendingTitle.
  ///
  /// In ar, this message translates to:
  /// **'{count} عملية لم تُرسل بعد'**
  String logoutPendingTitle(int count);

  /// No description provided for @logoutPendingBody.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن تسجيل الخروج قبل إرسالها، حتى لا تضيع ولا تُنسب لحساب آخر.'**
  String get logoutPendingBody;

  /// No description provided for @formByCarton.
  ///
  /// In ar, this message translates to:
  /// **'بالكرتونة'**
  String get formByCarton;

  /// No description provided for @cartonsLabel.
  ///
  /// In ar, this message translates to:
  /// **'عدد الكراتين عندك'**
  String get cartonsLabel;

  /// No description provided for @cartonsHint.
  ///
  /// In ar, this message translates to:
  /// **'كم كرتونة على الرف'**
  String get cartonsHint;

  /// No description provided for @looseLabel.
  ///
  /// In ar, this message translates to:
  /// **'قطع زيادة'**
  String get looseLabel;

  /// No description provided for @looseHint.
  ///
  /// In ar, this message translates to:
  /// **'من كرتونة مفتوحة'**
  String get looseHint;

  /// No description provided for @cartonPriceLabel.
  ///
  /// In ar, this message translates to:
  /// **'سعر الكرتونة (جملة)'**
  String get cartonPriceLabel;

  /// No description provided for @piecePriceLabel.
  ///
  /// In ar, this message translates to:
  /// **'سعر القطعة الواحدة'**
  String get piecePriceLabel;

  /// No description provided for @cartonTotal.
  ///
  /// In ar, this message translates to:
  /// **'المجموع: {total} قطعة'**
  String cartonTotal(int total);

  /// No description provided for @cartonsInvalid.
  ///
  /// In ar, this message translates to:
  /// **'أدخل عدداً صحيحاً، 0 أو أكثر.'**
  String get cartonsInvalid;

  /// No description provided for @looseTooMany.
  ///
  /// In ar, this message translates to:
  /// **'القطع الزيادة أقل من {size}؛ وإلا فهي كرتونة كاملة.'**
  String looseTooMany(int size);

  /// No description provided for @prodColName.
  ///
  /// In ar, this message translates to:
  /// **'المنتج'**
  String get prodColName;

  /// No description provided for @prodColCartons.
  ///
  /// In ar, this message translates to:
  /// **'الكراتين'**
  String get prodColCartons;

  /// No description provided for @prodColPieces.
  ///
  /// In ar, this message translates to:
  /// **'عدد القطع'**
  String get prodColPieces;

  /// No description provided for @prodColPrice.
  ///
  /// In ar, this message translates to:
  /// **'سعر القطعة'**
  String get prodColPrice;

  /// No description provided for @cartonsCell.
  ///
  /// In ar, this message translates to:
  /// **'{count} كرتونة'**
  String cartonsCell(int count);

  /// No description provided for @cartonsCellLoose.
  ///
  /// In ar, this message translates to:
  /// **'{count} كرتونة + {pieces} قطعة'**
  String cartonsCellLoose(int count, int pieces);
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
