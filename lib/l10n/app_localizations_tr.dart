// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get loginSubtitle => 'Sana en yakın aktiviteleri keşfet.';

  @override
  String get emailLabel => 'E-posta';

  @override
  String get passwordLabel => 'Şifre';

  @override
  String get passwordHelperText => 'En az 6 karakter';

  @override
  String get verificationCodeLabel => 'Doğrulama kodu';

  @override
  String get verificationCodeHelper => 'E-posta adresine gönderilen kodu gir';

  @override
  String get loginButton => 'Hadi Giriş Yap';

  @override
  String get registerButton => 'Hadi Kayıt Ol';

  @override
  String get verifyButton => 'Doğrula';

  @override
  String get haveAccountPrompt => 'Zaten hesabın var mı? Giriş yap';

  @override
  String get noAccountPrompt => 'Henüz üye değil misin? Kayıt ol';

  @override
  String get backButton => 'Geri';

  @override
  String get emailPasswordRequired =>
      'E-posta adresini ve şifreni gir (en az 6 karakter)';

  @override
  String get verificationCodeResent =>
      'Kod tekrar gönderildi! Gelen kutunu kontrol et.';

  @override
  String get genericError => 'Bir şeyler ters gitti — tekrar dener misin?';

  @override
  String get invalidCodeError => 'Bu kod doğrulanamadı. Tekrar dene?';

  @override
  String get searchHint => 'Aktivite ara...';

  @override
  String get searchRadiusTitle => 'Arama yarıçapı';

  @override
  String get allCategoriesChip => 'Tümü';

  @override
  String get listViewTooltip => 'Liste';

  @override
  String get mapViewTooltip => 'Harita';

  @override
  String get messagesTooltip => 'Mesajlar';

  @override
  String get signOutTooltip => 'Çıkış yap';

  @override
  String get activitiesLoadError => 'Aktiviteler şu an yüklenemiyor 😕';

  @override
  String get retryButton => 'Tekrar Dene';

  @override
  String get noActivitiesNearby =>
      'Çevrende henüz aktif aktivite yok. İlkini sen oluştursana? 🙌';

  @override
  String get exploreButton => 'Keşfet';

  @override
  String participantCount(int count) {
    return '$count katılımcı';
  }

  @override
  String get categoryWalk => 'Yürüyüş';

  @override
  String get categoryRun => 'Koşu';

  @override
  String get categoryFootball => 'Halı Saha';

  @override
  String get categoryBasketball => 'Basketbol';

  @override
  String get categoryCycling => 'Bisiklet';

  @override
  String get categoryConcert => 'Konser';

  @override
  String get categoryTheatre => 'Tiyatro';

  @override
  String get categoryFood => 'Yemek';

  @override
  String get categoryMuseum => 'Müze';

  @override
  String get categoryCinema => 'Sinema';

  @override
  String get createActivityTitle => 'Aktivite Oluştur';

  @override
  String get editActivityTitle => 'Aktiviteyi Düzenle';

  @override
  String get activityTitleLabel => 'Başlık';

  @override
  String get titleRequired => 'Bir başlık eklemeyi unutma';

  @override
  String get locationNameLabel => 'Konum adı';

  @override
  String get locationRequired => 'Haritadan bir konum seçmelisin';

  @override
  String get pickLocationButton => 'Haritadan konum seç';

  @override
  String locationSelected(String coordinates) {
    return 'Konum seçildi: $coordinates';
  }

  @override
  String get descriptionLabel => 'Açıklama (opsiyonel)';

  @override
  String get categoryLabel => 'Kategori';

  @override
  String get categoryLocked =>
      'Katılımcı olduğu için kategori artık değiştirilemiyor';

  @override
  String get addImagePrompt => 'Bir fotoğraf ekle (opsiyonel)';

  @override
  String get addImageHelper => 'Seçmezsen kategori görseli kullanılır';

  @override
  String get dateTimeLabel => 'Tarih & Saat';

  @override
  String get maxParticipantsLabel => 'Maksimum katılımcı:';

  @override
  String get createButton => 'Hadi Oluştur!';

  @override
  String get updateButton => 'Değişiklikleri Kaydet';

  @override
  String get locationPickRequired =>
      'Konum seçmeyi unutma — haritadan bir nokta işaretle';

  @override
  String get activityCreatedSuccess =>
      'Aktivite oluşturuldu! Herkesi bekliyor 🎉';

  @override
  String get deleteDialogTitle => 'Bu aktiviteyi silmek istiyor musun?';

  @override
  String get deleteDialogContent =>
      'Bu aktivite ve katılımcı listesi kalıcı olarak silinecek. Bu işlem geri alınamaz.';

  @override
  String get cancelButton => 'İptal';

  @override
  String get deleteConfirmButton => 'Evet, Sil';

  @override
  String get activityDeletedSuccess => 'Aktivite silindi.';

  @override
  String get deleteError => 'Silerken bir hata oluştu — tekrar dener misin?';

  @override
  String get ratingSubmitted => 'Puanın kaydedildi, teşekkürler! 🌟';

  @override
  String get activityFullMessage => 'Bu aktivitede yer kalmadı 😕';

  @override
  String get joinedActivity => 'Katıldın! Görüşürüz 🙌';

  @override
  String get leftActivity => 'Ayrıldın. Başka zaman görüşürüz!';

  @override
  String get favouriteTooltip => 'Favori';

  @override
  String get editTooltip => 'Düzenle';

  @override
  String get deleteTooltip => 'Aktiviteyi sil';

  @override
  String get getDirectionsButton => 'Yol Tarifi Al';

  @override
  String get rateParticipantsTitle => 'Katılımcıları Puanla';

  @override
  String get participantsTitle => 'Katılımcılar';

  @override
  String get unknownParticipant => 'Bilinmiyor';

  @override
  String get leaveButton => 'Ayrıl';

  @override
  String get joinButton => 'Hadi Katıl!';

  @override
  String get profileTitle => 'Profilim';

  @override
  String get saveButton => 'Kaydet';

  @override
  String get nameLabel => 'Ad';

  @override
  String get bioLabel => 'Hakkımda';

  @override
  String get bioHint => 'Kendinden biraz bahset...';

  @override
  String get profileUpdated => 'Profil güncellendi!';

  @override
  String get profileUpdateError =>
      'Profil güncellenemedi — tekrar dener misin?';

  @override
  String get photoUpdated => 'Fotoğraf güncellendi!';

  @override
  String get photoUploadError => 'Fotoğraf yüklenemedi — tekrar dener misin?';

  @override
  String get noActivitiesYet => 'Henüz aktivite yok. Hadi başlayalım! 🚀';

  @override
  String get completedBadge => 'Tamamlandı';

  @override
  String get createdActivitiesTab => 'Oluşturduklarım';

  @override
  String get joinedActivitiesTab => 'Katıldıklarım';

  @override
  String get favoritesTab => 'Favoriler';

  @override
  String ratingsCount(int count) {
    return '$count değerlendirme';
  }

  @override
  String get mapPickerTitle => 'Konum Seç';

  @override
  String get mapPickerSearchHint => 'Yer ara (örn: Kadıköy)';

  @override
  String get selectLocationButton => 'Bu Konumu Seç';

  @override
  String get locationNotFound =>
      'Bu arama için sonuç bulunamadı — başka bir şey dene';

  @override
  String get searchError =>
      'Arama sırasında bir hata oluştu — tekrar dener misin?';

  @override
  String get locationPermissionDenied =>
      'Konum iznine ihtiyacımız var — Ayarlar\'dan izin verebilirsin';

  @override
  String get locationFetchError => 'Konumun alınamadı — tekrar dener misin?';

  @override
  String get notificationChannelName => 'Hadi Bildirimleri';

  @override
  String get notificationChannelDescription =>
      'Aktivite güncellemeleri ve bildirimler';
}
