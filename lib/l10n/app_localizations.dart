import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_tr.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
  static const List<Locale> supportedLocales = <Locale>[Locale('tr')];

  /// Subtitle on the login/register screen
  ///
  /// In tr, this message translates to:
  /// **'Sana en yakın aktiviteleri keşfet.'**
  String get loginSubtitle;

  /// Email field label
  ///
  /// In tr, this message translates to:
  /// **'E-posta'**
  String get emailLabel;

  /// Password field label
  ///
  /// In tr, this message translates to:
  /// **'Şifre'**
  String get passwordLabel;

  /// Password helper text below field
  ///
  /// In tr, this message translates to:
  /// **'En az 6 karakter'**
  String get passwordHelperText;

  /// Verification code field label
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama kodu'**
  String get verificationCodeLabel;

  /// Helper text below verification code field
  ///
  /// In tr, this message translates to:
  /// **'E-posta adresine gönderilen kodu gir'**
  String get verificationCodeHelper;

  /// Primary login button
  ///
  /// In tr, this message translates to:
  /// **'Hadi Giriş Yap'**
  String get loginButton;

  /// Primary register button
  ///
  /// In tr, this message translates to:
  /// **'Hadi Kayıt Ol'**
  String get registerButton;

  /// Verify code button
  ///
  /// In tr, this message translates to:
  /// **'Doğrula'**
  String get verifyButton;

  /// Switch to login link
  ///
  /// In tr, this message translates to:
  /// **'Zaten hesabın var mı? Giriş yap'**
  String get haveAccountPrompt;

  /// Switch to register link
  ///
  /// In tr, this message translates to:
  /// **'Henüz üye değil misin? Kayıt ol'**
  String get noAccountPrompt;

  /// Generic back button label
  ///
  /// In tr, this message translates to:
  /// **'Geri'**
  String get backButton;

  /// Validation snackbar when email or password is missing
  ///
  /// In tr, this message translates to:
  /// **'E-posta adresini ve şifreni gir (en az 6 karakter)'**
  String get emailPasswordRequired;

  /// Success snackbar after resending verification code
  ///
  /// In tr, this message translates to:
  /// **'Kod tekrar gönderildi! Gelen kutunu kontrol et.'**
  String get verificationCodeResent;

  /// Fallback error snackbar for unexpected errors; replaces raw 'Hata: $e' pattern
  ///
  /// In tr, this message translates to:
  /// **'Bir şeyler ters gitti — tekrar dener misin?'**
  String get genericError;

  /// Snackbar shown when verification code is wrong
  ///
  /// In tr, this message translates to:
  /// **'Bu kod doğrulanamadı. Tekrar dene?'**
  String get invalidCodeError;

  /// Placeholder in the home screen search field
  ///
  /// In tr, this message translates to:
  /// **'Aktivite ara...'**
  String get searchHint;

  /// Modal title for radius picker
  ///
  /// In tr, this message translates to:
  /// **'Arama yarıçapı'**
  String get searchRadiusTitle;

  /// Category filter chip showing all categories
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get allCategoriesChip;

  /// Tooltip for list view icon button
  ///
  /// In tr, this message translates to:
  /// **'Liste'**
  String get listViewTooltip;

  /// Tooltip for map view icon button
  ///
  /// In tr, this message translates to:
  /// **'Harita'**
  String get mapViewTooltip;

  /// Tooltip for the messages/inbox icon button in AppBar
  ///
  /// In tr, this message translates to:
  /// **'Mesajlar'**
  String get messagesTooltip;

  /// Tooltip for the sign-out icon button in AppBar
  ///
  /// In tr, this message translates to:
  /// **'Çıkış yap'**
  String get signOutTooltip;

  /// Error state message when activity list fails to load
  ///
  /// In tr, this message translates to:
  /// **'Aktiviteler şu an yüklenemiyor 😕'**
  String get activitiesLoadError;

  /// Generic retry button
  ///
  /// In tr, this message translates to:
  /// **'Tekrar Dene'**
  String get retryButton;

  /// Empty state on home screen when no activities are nearby
  ///
  /// In tr, this message translates to:
  /// **'Çevrende henüz aktif aktivite yok. İlkini sen oluştursana? 🙌'**
  String get noActivitiesNearby;

  /// Button on activity card to view details (replaces 'Detayları Gör')
  ///
  /// In tr, this message translates to:
  /// **'Keşfet'**
  String get exploreButton;

  /// Participant count label on activity cards and detail page
  ///
  /// In tr, this message translates to:
  /// **'{count} katılımcı'**
  String participantCount(int count);

  /// No description provided for @categoryWalk.
  ///
  /// In tr, this message translates to:
  /// **'Yürüyüş'**
  String get categoryWalk;

  /// No description provided for @categoryRun.
  ///
  /// In tr, this message translates to:
  /// **'Koşu'**
  String get categoryRun;

  /// No description provided for @categoryFootball.
  ///
  /// In tr, this message translates to:
  /// **'Halı Saha'**
  String get categoryFootball;

  /// No description provided for @categoryBasketball.
  ///
  /// In tr, this message translates to:
  /// **'Basketbol'**
  String get categoryBasketball;

  /// No description provided for @categoryCycling.
  ///
  /// In tr, this message translates to:
  /// **'Bisiklet'**
  String get categoryCycling;

  /// No description provided for @categoryConcert.
  ///
  /// In tr, this message translates to:
  /// **'Konser'**
  String get categoryConcert;

  /// No description provided for @categoryTheatre.
  ///
  /// In tr, this message translates to:
  /// **'Tiyatro'**
  String get categoryTheatre;

  /// No description provided for @categoryFood.
  ///
  /// In tr, this message translates to:
  /// **'Yemek'**
  String get categoryFood;

  /// No description provided for @categoryMuseum.
  ///
  /// In tr, this message translates to:
  /// **'Müze'**
  String get categoryMuseum;

  /// No description provided for @categoryCinema.
  ///
  /// In tr, this message translates to:
  /// **'Sinema'**
  String get categoryCinema;

  /// AppBar title on create activity screen
  ///
  /// In tr, this message translates to:
  /// **'Aktivite Oluştur'**
  String get createActivityTitle;

  /// AppBar title on edit activity screen
  ///
  /// In tr, this message translates to:
  /// **'Aktiviteyi Düzenle'**
  String get editActivityTitle;

  /// Title field label on create/edit activity screen
  ///
  /// In tr, this message translates to:
  /// **'Başlık'**
  String get activityTitleLabel;

  /// Inline validation when activity title is empty
  ///
  /// In tr, this message translates to:
  /// **'Bir başlık eklemeyi unutma'**
  String get titleRequired;

  /// Location name field label
  ///
  /// In tr, this message translates to:
  /// **'Konum adı'**
  String get locationNameLabel;

  /// Inline validation when no location is picked
  ///
  /// In tr, this message translates to:
  /// **'Haritadan bir konum seçmelisin'**
  String get locationRequired;

  /// Button to open map picker
  ///
  /// In tr, this message translates to:
  /// **'Haritadan konum seç'**
  String get pickLocationButton;

  /// Button label after a location is picked, showing coordinates
  ///
  /// In tr, this message translates to:
  /// **'Konum seçildi: {coordinates}'**
  String locationSelected(String coordinates);

  /// Description field label
  ///
  /// In tr, this message translates to:
  /// **'Açıklama (opsiyonel)'**
  String get descriptionLabel;

  /// Category dropdown label
  ///
  /// In tr, this message translates to:
  /// **'Kategori'**
  String get categoryLabel;

  /// Helper shown when category can't be changed because participants have joined
  ///
  /// In tr, this message translates to:
  /// **'Katılımcı olduğu için kategori artık değiştirilemiyor'**
  String get categoryLocked;

  /// Image upload section heading
  ///
  /// In tr, this message translates to:
  /// **'Bir fotoğraf ekle (opsiyonel)'**
  String get addImagePrompt;

  /// Helper text below image upload prompt
  ///
  /// In tr, this message translates to:
  /// **'Seçmezsen kategori görseli kullanılır'**
  String get addImageHelper;

  /// Date & time row label
  ///
  /// In tr, this message translates to:
  /// **'Tarih & Saat'**
  String get dateTimeLabel;

  /// Max participants row label
  ///
  /// In tr, this message translates to:
  /// **'Maksimum katılımcı:'**
  String get maxParticipantsLabel;

  /// Submit button on create activity screen
  ///
  /// In tr, this message translates to:
  /// **'Hadi Oluştur!'**
  String get createButton;

  /// Submit button on edit activity screen (replaces 'Güncelle')
  ///
  /// In tr, this message translates to:
  /// **'Değişiklikleri Kaydet'**
  String get updateButton;

  /// Snackbar shown when user tries to submit without picking a location
  ///
  /// In tr, this message translates to:
  /// **'Konum seçmeyi unutma — haritadan bir nokta işaretle'**
  String get locationPickRequired;

  /// Success snackbar after creating an activity
  ///
  /// In tr, this message translates to:
  /// **'Aktivite oluşturuldu! Herkesi bekliyor 🎉'**
  String get activityCreatedSuccess;

  /// Title of the delete confirmation dialog
  ///
  /// In tr, this message translates to:
  /// **'Bu aktiviteyi silmek istiyor musun?'**
  String get deleteDialogTitle;

  /// Body of the delete confirmation dialog
  ///
  /// In tr, this message translates to:
  /// **'Bu aktivite ve katılımcı listesi kalıcı olarak silinecek. Bu işlem geri alınamaz.'**
  String get deleteDialogContent;

  /// Cancel button in dialogs
  ///
  /// In tr, this message translates to:
  /// **'İptal'**
  String get cancelButton;

  /// Confirm delete button — explicit phrasing reduces accidental taps
  ///
  /// In tr, this message translates to:
  /// **'Evet, Sil'**
  String get deleteConfirmButton;

  /// Snackbar after successfully deleting an activity
  ///
  /// In tr, this message translates to:
  /// **'Aktivite silindi.'**
  String get activityDeletedSuccess;

  /// Snackbar when delete fails
  ///
  /// In tr, this message translates to:
  /// **'Silerken bir hata oluştu — tekrar dener misin?'**
  String get deleteError;

  /// Snackbar after submitting a rating
  ///
  /// In tr, this message translates to:
  /// **'Puanın kaydedildi, teşekkürler! 🌟'**
  String get ratingSubmitted;

  /// Snackbar when user tries to join a full activity
  ///
  /// In tr, this message translates to:
  /// **'Bu aktivitede yer kalmadı 😕'**
  String get activityFullMessage;

  /// Snackbar after successfully joining an activity
  ///
  /// In tr, this message translates to:
  /// **'Katıldın! Görüşürüz 🙌'**
  String get joinedActivity;

  /// Snackbar after leaving an activity
  ///
  /// In tr, this message translates to:
  /// **'Ayrıldın. Başka zaman görüşürüz!'**
  String get leftActivity;

  /// Tooltip for the favourite icon button
  ///
  /// In tr, this message translates to:
  /// **'Favori'**
  String get favouriteTooltip;

  /// Tooltip for the edit icon button
  ///
  /// In tr, this message translates to:
  /// **'Düzenle'**
  String get editTooltip;

  /// Tooltip for the delete icon button
  ///
  /// In tr, this message translates to:
  /// **'Aktiviteyi sil'**
  String get deleteTooltip;

  /// Button to open navigation to activity location
  ///
  /// In tr, this message translates to:
  /// **'Yol Tarifi Al'**
  String get getDirectionsButton;

  /// Section heading when current user is organiser and can rate
  ///
  /// In tr, this message translates to:
  /// **'Katılımcıları Puanla'**
  String get rateParticipantsTitle;

  /// Section heading for participant list (non-organiser view)
  ///
  /// In tr, this message translates to:
  /// **'Katılımcılar'**
  String get participantsTitle;

  /// Fallback name when participant display name is null
  ///
  /// In tr, this message translates to:
  /// **'Bilinmiyor'**
  String get unknownParticipant;

  /// Button to leave an activity
  ///
  /// In tr, this message translates to:
  /// **'Ayrıl'**
  String get leaveButton;

  /// Primary CTA button to join an activity
  ///
  /// In tr, this message translates to:
  /// **'Hadi Katıl!'**
  String get joinButton;

  /// AppBar title on profile screen
  ///
  /// In tr, this message translates to:
  /// **'Profilim'**
  String get profileTitle;

  /// Save button on profile screen
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get saveButton;

  /// Name field label on profile screen
  ///
  /// In tr, this message translates to:
  /// **'Ad'**
  String get nameLabel;

  /// Bio field label on profile screen
  ///
  /// In tr, this message translates to:
  /// **'Hakkımda'**
  String get bioLabel;

  /// Placeholder text in bio field
  ///
  /// In tr, this message translates to:
  /// **'Kendinden biraz bahset...'**
  String get bioHint;

  /// Snackbar after profile save succeeds
  ///
  /// In tr, this message translates to:
  /// **'Profil güncellendi!'**
  String get profileUpdated;

  /// Snackbar when profile save fails
  ///
  /// In tr, this message translates to:
  /// **'Profil güncellenemedi — tekrar dener misin?'**
  String get profileUpdateError;

  /// Snackbar after photo upload succeeds
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf güncellendi!'**
  String get photoUpdated;

  /// Snackbar when photo upload fails
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf yüklenemedi — tekrar dener misin?'**
  String get photoUploadError;

  /// Empty state on profile tabs (created/joined/favourites)
  ///
  /// In tr, this message translates to:
  /// **'Henüz aktivite yok. Hadi başlayalım! 🚀'**
  String get noActivitiesYet;

  /// Status badge on past activities
  ///
  /// In tr, this message translates to:
  /// **'Tamamlandı'**
  String get completedBadge;

  /// Profile tab: activities the user created
  ///
  /// In tr, this message translates to:
  /// **'Oluşturduklarım'**
  String get createdActivitiesTab;

  /// Profile tab: activities the user joined
  ///
  /// In tr, this message translates to:
  /// **'Katıldıklarım'**
  String get joinedActivitiesTab;

  /// Profile tab: favourited activities
  ///
  /// In tr, this message translates to:
  /// **'Favoriler'**
  String get favoritesTab;

  /// Rating count label on profile screen
  ///
  /// In tr, this message translates to:
  /// **'{count} değerlendirme'**
  String ratingsCount(int count);

  /// AppBar title on map picker screen
  ///
  /// In tr, this message translates to:
  /// **'Konum Seç'**
  String get mapPickerTitle;

  /// Placeholder in map picker search field
  ///
  /// In tr, this message translates to:
  /// **'Yer ara (örn: Kadıköy)'**
  String get mapPickerSearchHint;

  /// Confirm button on map picker (replaces bare 'Seç')
  ///
  /// In tr, this message translates to:
  /// **'Bu Konumu Seç'**
  String get selectLocationButton;

  /// Snackbar when place search returns no results
  ///
  /// In tr, this message translates to:
  /// **'Bu arama için sonuç bulunamadı — başka bir şey dene'**
  String get locationNotFound;

  /// Snackbar when place search throws an error
  ///
  /// In tr, this message translates to:
  /// **'Arama sırasında bir hata oluştu — tekrar dener misin?'**
  String get searchError;

  /// Snackbar when location permission is permanently denied
  ///
  /// In tr, this message translates to:
  /// **'Konum iznine ihtiyacımız var — Ayarlar\'dan izin verebilirsin'**
  String get locationPermissionDenied;

  /// Snackbar when getting device location fails
  ///
  /// In tr, this message translates to:
  /// **'Konumun alınamadı — tekrar dener misin?'**
  String get locationFetchError;

  /// Android notification channel name
  ///
  /// In tr, this message translates to:
  /// **'Hadi Bildirimleri'**
  String get notificationChannelName;

  /// Android notification channel description
  ///
  /// In tr, this message translates to:
  /// **'Aktivite güncellemeleri ve bildirimler'**
  String get notificationChannelDescription;
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
      <String>['tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
