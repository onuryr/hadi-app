import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('tr'));
  }

  bool get _isEn => locale.languageCode == 'en';
  String _t(String tr, String en) => _isEn ? en : tr;

  // ── Common ──
  String get save => _t('Kaydet', 'Save');
  String get cancel => _t('İptal', 'Cancel');
  String get delete => _t('Sil', 'Delete');
  String get edit => _t('Düzenle', 'Edit');
  String get retry => _t('Tekrar Dene', 'Retry');
  String get close => _t('Kapat', 'Close');
  String get loading => _t('Yükleniyor...', 'Loading...');
  String get error => _t('Hata', 'Error');
  String get back => _t('Geri dön', 'Go back');
  String get confirm => _t('Onayla', 'Confirm');
  String get yes => _t('Evet', 'Yes');
  String get no => _t('Hayır', 'No');
  String get share => _t('Paylaş', 'Share');
  String get report => _t('Şikayet Et', 'Report');
  String get block => _t('Engelle', 'Block');
  String get unblock => _t('Engeli Kaldır', 'Unblock');

  // ── Login ──
  String get appSlogan => _t('Etkinlik bul, insanlarla tanış', 'Find events, meet people');
  String get email => _t('E-posta', 'Email');
  String get password => _t('Şifre', 'Password');
  String get passwordMinChars => _t('En az 6 karakter', 'Minimum 6 characters');
  String get forgotPassword => _t('Şifremi Unuttum', 'Forgot Password');
  String get verificationCode => _t('Doğrulama kodu', 'Verification code');
  String get verificationCodeHelper => _t('Email adresine gelen kodu gir', 'Enter the code sent to your email');
  String get verify => _t('Doğrula', 'Verify');
  String get signUp => _t('Kayıt Ol', 'Sign Up');
  String get logIn => _t('Giriş Yap', 'Log In');
  String get alreadyHaveAccount => _t('Hesabın var mı? Giriş yap', 'Already have an account? Log in');
  String get dontHaveAccount => _t('Hesabın yok mu? Kayıt ol', "Don't have an account? Sign up");
  String get emailAndPasswordRequired => _t('Email ve en az 6 karakterli şifre gir', 'Enter email and password (min. 6 chars)');
  String get codeSentAgain => _t('Doğrulama kodu tekrar gönderildi', 'Verification code resent');

  // ── Forgot password ──
  String get resetPassword => _t('Şifremi Sıfırla', 'Reset Password');
  String get resetPasswordHint => _t('E-posta adresinizi girin, şifre sıfırlama bağlantısı göndereceğiz.', 'Enter your email and we will send a password reset link.');
  String get sendResetLink => _t('Sıfırlama Bağlantısı Gönder', 'Send Reset Link');
  String get resetLinkSent => _t('Şifre sıfırlama bağlantısı gönderildi', 'Password reset link sent');

  // ── Home ──
  String get messages => _t('Mesajlar', 'Messages');
  String get signOut => _t('Çıkış yap', 'Sign out');
  String get searchActivities => _t('Aktivite ara...', 'Search activities...');
  String get searchRadius => _t('Arama yarıçapı', 'Search radius');
  String get sort => _t('Sırala', 'Sort');
  String get all => _t('Tümü', 'All');
  String get sortDistance => _t('Yakınlık', 'Distance');
  String get sortDate => _t('En yakın tarih', 'Nearest date');
  String get sortParticipants => _t('En kalabalık', 'Most popular');
  String get sortNewest => _t('En yeni', 'Newest');
  String get participants => _t('katılımcı', 'participants');
  String get away => _t('uzakta', 'away');
  String get viewDetails => _t('Detayları Gör', 'View Details');
  String get activitiesLoadFailed => _t('Aktiviteler yüklenemedi', 'Could not load activities');
  String get noActivitiesNearby => _t('Yakında aktif aktivite bulunamadı', 'No active activities found nearby');
  String get refreshError => _t('Yenilenirken bir hata oluştu.', 'An error occurred while refreshing.');
  String get listView => _t('Liste', 'List');
  String get mapView => _t('Harita', 'Map');

  // ── Activity detail ──
  String get joinActivity => _t('Katıl', 'Join');
  String get leaveActivity => _t('Ayrıl', 'Leave');
  String get cancelActivity => _t('İptal Et', 'Cancel Activity');
  String get deleteActivity => _t('Sil', 'Delete');
  String get editActivity => _t('Düzenle', 'Edit');
  String get activityCancelled => _t('Aktivite iptal edildi', 'Activity cancelled');
  String get activityDeleted => _t('Aktivite silindi', 'Activity deleted');
  String get joinedSuccessfully => _t('Aktiviteye katıldınız!', 'Joined the activity!');
  String get leftActivity => _t('Aktiviteden ayrıldınız.', 'Left the activity.');
  String get organizerLabel => _t('Organizatör', 'Organizer');
  String get participantsLabel => _t('Katılımcılar', 'Participants');
  String get chatLabel => _t('Sohbet', 'Chat');
  String get pendingParticipants => _t('Onay bekleyenler', 'Pending');
  String get approveAll => _t('Tümünü Onayla', 'Approve All');
  String get reject => _t('Reddet', 'Reject');
  String get approve => _t('Onayla', 'Approve');
  String get activityFull => _t('Aktivite dolu', 'Activity is full');
  String get rateParticipants => _t('Katılımcıları Puanla', 'Rate Participants');
  String get yourRating => _t('Puanınız', 'Your Rating');
  String get activityPast => _t('Bu aktivite geçmiş', 'This activity is in the past');
  String get maxParticipantsLabel => _t('Maks. katılımcı', 'Max. participants');
  String get noParticipantsYet => _t('Henüz katılımcı yok', 'No participants yet');

  // ── Create activity ──
  String get createActivity => _t('Aktivite Oluştur', 'Create Activity');
  String get titleLabel => _t('Başlık', 'Title');
  String get descriptionLabel => _t('Açıklama', 'Description');
  String get categoryLabel => _t('Kategori', 'Category');
  String get locationLabel => _t('Konum', 'Location');
  String get dateLabel => _t('Tarih ve Saat', 'Date & Time');
  String get maxParticipants => _t('Maks. katılımcı', 'Max. participants');
  String get activityCreated => _t('Aktivite oluşturuldu!', 'Activity created!');
  String get selectLocation => _t('Konum Seç', 'Select Location');
  String get pickOnMap => _t('Haritadan Seç', 'Pick on Map');
  String get imageLabel => _t('Fotoğraf', 'Photo');
  String get addImage => _t('Fotoğraf Ekle', 'Add Photo');
  String get editActivityTitle => _t('Aktiviteyi Düzenle', 'Edit Activity');
  String get locationNameLabel => _t('Konum adı', 'Location name');
  String get locationRequired => _t('Konum gerekli', 'Location is required');
  String get pickLocationFromMap => _t('Haritadan konum seç', 'Pick location from map');
  String locationPickedAt(String lat, String lng) => _t('Konum seçildi: $lat, $lng', 'Location picked: $lat, $lng');
  String get descriptionOptionalLabel => _t('Açıklama (opsiyonel)', 'Description (optional)');
  String get imageOptionalAdd => _t('Resim ekle (opsiyonel)', 'Add image (optional)');
  String get dateTimeLabel => _t('Tarih & Saat', 'Date & Time');
  String get maxParticipantsRowLabel => _t('Maksimum katılımcı:', 'Maximum participants:');
  String get createButton => _t('Oluştur', 'Create');
  String get catWalk => _t('Yürüyüş', 'Walk');
  String get catRun => _t('Koşu', 'Run');
  String get catFootball => _t('Halı Saha', 'Football');
  String get catBasketball => _t('Basketbol', 'Basketball');
  String get catCycling => _t('Bisiklet', 'Cycling');
  String get catConcert => _t('Konser', 'Concert');
  String get catTheatre => _t('Tiyatro', 'Theatre');
  String get catFood => _t('Yemek', 'Food');
  String get catMuseum => _t('Müze', 'Museum');
  String get catCinema => _t('Sinema', 'Cinema');

  // ── Profile ──
  String get profile => _t('Profil', 'Profile');
  String get createdActivities => _t('Oluşturulan', 'Created');
  String get joinedActivities => _t('Katılınan', 'Joined');
  String get favorites => _t('Favoriler', 'Favorites');
  String get editProfile => _t('Profili Düzenle', 'Edit Profile');
  String get displayName => _t('Görünen İsim', 'Display Name');
  String get bio => _t('Hakkında', 'About');
  String get profileSaved => _t('Profil güncellendi.', 'Profile updated.');
  String get noActivitiesCreated => _t('Henüz aktivite oluşturmadınız.', 'No activities created yet.');
  String get noActivitiesJoined => _t('Henüz bir aktiviteye katılmadınız.', 'No activities joined yet.');
  String get noFavorites => _t('Favori aktivite bulunamadı.', 'No favorite activities found.');
  String get blockedUsers => _t('Engellenen Kullanıcılar', 'Blocked Users');
  String get avgRating => _t('Ort. Puan', 'Avg. Rating');
  String get noRatingsYet => _t('Henüz puan yok', 'No ratings yet');

  // ── Settings ──
  String get settings => _t('Ayarlar', 'Settings');
  String get notifications => _t('Bildirimler', 'Notifications');
  String get appearance => _t('Görünüm', 'Appearance');
  String get theme => _t('Tema', 'Theme');
  String get themeSubtitle => _t('Uygulama görünümünü seç', 'Choose app appearance');
  String get systemTheme => _t('Sistem', 'System');
  String get lightTheme => _t('Açık', 'Light');
  String get darkTheme => _t('Koyu', 'Dark');
  String get language => _t('Dil', 'Language');
  String get account => _t('Hesap', 'Account');
  String get changePassword => _t('Şifreyi Değiştir', 'Change Password');
  String get deleteAccount => _t('Hesabı Sil', 'Delete Account');
  String get deleteAccountConfirm => _t('Bu işlem geri alınamaz. Tüm verileriniz kalıcı olarak silinecek.', 'This action cannot be undone. All your data will be permanently deleted.');
  String get accountDeleted => _t('Hesabınız silindi.', 'Your account has been deleted.');
  String get accountDeleteFailed => _t('Hesap silinemedi', 'Account could not be deleted');
  String get activityUpdates => _t('Aktivite güncellemeleri', 'Activity updates');
  String get newMessages => _t('Yeni mesajlar', 'New messages');
  String get activityReminders => _t('Aktivite hatırlatıcıları', 'Activity reminders');
  String get savingPreferences => _t('Bildirim tercihleri kaydediliyor...', 'Saving notification preferences...');
  String get preferencesSaveFailed => _t('Tercihler kaydedilemedi. Tekrar deneyin.', 'Preferences could not be saved. Please try again.');
  String get currentPassword => _t('Mevcut şifre', 'Current password');
  String get newPassword => _t('Yeni şifre', 'New password');
  String get confirmNewPassword => _t('Yeni şifre (tekrar)', 'Confirm new password');
  String get currentPasswordRequired => _t('Mevcut şifre gerekli', 'Current password is required');
  String get newPasswordRequired => _t('Yeni şifre gerekli', 'New password is required');
  String get passwordMinLength => _t('En az 6 karakter olmalı', 'Must be at least 6 characters');
  String get confirmPasswordRequired => _t('Tekrar şifre gerekli', 'Password confirmation is required');
  String get passwordMismatch => _t('Şifreler eşleşmiyor', 'Passwords do not match');
  String get passwordUpdated => _t('Şifreniz güncellendi.', 'Your password has been updated.');
  String get passwordChangeFailed => _t('Şifre değiştirilemedi', 'Password could not be changed');
  String get sessionNotFound => _t('Oturum bilgisi bulunamadı.', 'Session information not found.');
  String get currentPasswordInvalid => _t('Mevcut şifre doğrulanamadı.', 'Current password could not be verified.');
  String get sessionError => _t('Oturum doğrulanamadı. Lütfen çıkış yapıp tekrar giriş yapın.', 'Session could not be validated. Please sign out and sign in again.');

  // ── Inbox & Chat ──
  String get inbox => _t('Gelen Kutusu', 'Inbox');
  String get noConversations => _t('Henüz mesaj yok', 'No messages yet');
  String get typeMessage => _t('Mesaj yaz...', 'Type a message...');
  String get send => _t('Gönder', 'Send');

  // ── Blocked users ──
  String get noBlockedUsers => _t('Engellenen kullanıcı yok.', 'No blocked users.');
  String get unblockConfirm => _t('Bu kullanıcının engelini kaldırmak istiyor musunuz?', 'Are you sure you want to unblock this user?');

  // ── Onboarding ──
  String get onboardingTitle1 => _t('Yakınında Ne Var?', "What's Near You?");
  String get onboardingBody1 => _t('Etrafındaki aktiviteleri keşfet, haritada gör.', 'Discover activities around you, see them on the map.');
  String get onboardingTitle2 => _t('Birlikte Daha Güzel', 'Better Together');
  String get onboardingBody2 => _t('Aktivitelere katıl, yeni insanlarla tanış.', 'Join activities and meet new people.');
  String get onboardingTitle3 => _t('Hadi Başlayalım!', "Let's Start!");
  String get onboardingBody3 => _t('Kendi aktiviteni oluştur veya bir aktiviteye katıl.', 'Create your own activity or join an existing one.');
  String get getStarted => _t('Başla', 'Get Started');
  String get next => _t('Devam', 'Next');
  String get skip => _t('Geç', 'Skip');

  // ── Misc ──
  String get serverError => _t('Sunucu hatası', 'Server error');
  String get noInternetConnection => _t('İnternet bağlantısı yok', 'No internet connection');
  String get unknownError => _t('Bilinmeyen bir hata oluştu', 'An unknown error occurred');
  String get today => _t('Bugün', 'Today');
  String get yesterday => _t('Dün', 'Yesterday');
  String get unknownUser => _t('Kullanıcı', 'User');
  String get sendFailed => _t('Gönderilemedi', 'Could not send');
  String get userBlocked => _t('Bu kullanıcı engellendi', 'This user is blocked');

  // ── Activity detail / cancel-delete dialogs ──
  String get cancelDialogTitle => _t('Aktiviteyi İptal Et?', 'Cancel activity?');
  String get cancelDialogContent => _t('Katılımcılar bilgilendirilecek ve aktivite iptal edildi olarak işaretlenecek.', 'Participants will be notified and the activity will be marked as cancelled.');
  String get giveUp => _t('Vazgeç', 'Never mind');
  String get cancelIt => _t('İptal Et', 'Cancel It');
  String get cancelError => _t('İptal hatası', 'Cancellation error');
  String get deleteDialogTitle => _t('Aktiviteyi sil?', 'Delete activity?');
  String get deleteDialogContent => _t('Bu aktivite ve tüm katılımcıları kalıcı olarak silinecek. Emin misin?', 'This activity and all participants will be permanently deleted. Are you sure?');
  String get joinRequestSent => _t('Katılım isteğiniz gönderildi', 'Join request sent');
  String get leftActivitySnack => _t('Aktiviteden ayrıldınız', 'You left the activity');
  String get joinApproved => _t('Katılım onaylandı', 'Join approved');
  String get joinRejected => _t('Katılım reddedildi', 'Join rejected');
  String get pendingRequests => _t('Bekleyen İstekler', 'Pending Requests');
  String get joinFull => _t('Aktivite dolu, katılamazsın', 'Activity is full');
  String get cancelledLabel => _t('İptal Edildi', 'Cancelled');
  String get activityCancelledButton => _t('Aktivite iptal edildi', 'Activity cancelled');
  String get participantsHeader => _t('Katılımcılar', 'Participants');
  String get joinButton => _t('Katıl', 'Join');
  String get leaveButton => _t('Ayrıl', 'Leave');

  // ── Block / Report ──
  String get unblockedSuccess => _t('Kullanıcının engeli kaldırıldı', 'User unblocked');
  String get unblockFailed => _t('Engel kaldırılamadı', 'Could not unblock');
  String get reportSubmitted => _t('Raporunuz iletildi', 'Your report was submitted');
  String get reportFailed => _t('Rapor gönderilemedi', 'Report could not be sent');
  String get reportTitle => _t('Raporla', 'Report');
  String get whyReport => _t('Neden raporluyorsunuz?', 'Why are you reporting?');
  String get descriptionOptional => _t('Açıklama (opsiyonel)', 'Description (optional)');
  String get reasonSpam => _t('Spam', 'Spam');
  String get reasonInappropriate => _t('Uygunsuz içerik', 'Inappropriate content');
  String get reasonHarassment => _t('Taciz', 'Harassment');
  String get reasonMisleading => _t('Yanıltıcı', 'Misleading');
  String get reasonOther => _t('Diğer', 'Other');
  String get blockUserDialogTitle => _t('Kullanıcıyı engelle?', 'Block this user?');
  String blockUserDialogContent(String displayName) => _t(
        '$displayName adlı kullanıcıyı engellemek istediğinizden emin misiniz? Engellenen kullanıcıların aktiviteleri size gösterilmez.',
        'Are you sure you want to block $displayName? Blocked users\' activities will not be shown to you.');
  String userBlockedSnack(String displayName) => _t('$displayName engellendi', '$displayName has been blocked');
  String get blockFailed => _t('Engelleme başarısız', 'Could not block');
  String get sentLabel => _t('Gönder', 'Send');
  String get photoUpdated => _t('Fotoğraf güncellendi', 'Photo updated');
  String get photoUploadFailed => _t('Fotoğraf yüklenemedi', 'Could not upload photo');
  String ratingsCount(int count) => _t('$count değerlendirme', '$count ratings');
  String get aboutMeEmptySelf => _t('Hakkımda kısmı boş', 'Bio is empty');
  String get aboutMeEmptyOther => _t('Henüz bir şey yazmamış', 'Has not written anything yet');
  String get aboutMeLabel => _t('Hakkımda', 'About me');
  String get resetSentInfo => _t('Şifre sıfırlama bağlantısı e-posta adresinize gönderildi. Spam kutusunu da kontrol edin.', 'Password reset link sent to your email. Check your spam folder too.');
  String get backToLogin => _t('Giriş ekranına dön', 'Back to login');
  String get nextLabel => _t('İleri', 'Next');
  String get startLabel => _t('Başla', 'Start');
  String get onbMeetTitle => _t('İnsanlarla Tanış, Sohbet Et', 'Meet People, Chat');
  String get onbMeetDesc => _t('Katıldığın aktivitelerde grup sohbetine katıl, katılımcılarla tanış.', 'Join the group chat in activities you attend and meet other participants.');
  String get onbDiscoverTitle => _t('Yakınındaki Aktiviteleri Keşfet', 'Discover Nearby Activities');
  String get onbDiscoverDesc => _t('Sana yakın yürüyüş, koşu, konser ve daha fazlasını mesafeye göre sıralı gör.', 'See walks, runs, concerts and more near you, sorted by distance.');
  String get onbJoinTitle => _t('Aktivitelere Katıl', 'Join Activities');
  String get onbJoinDesc => _t('Beğendiğin aktiviteye tek dokunuşla katıl, katılımcılarla tanış.', 'Join an activity you like with a single tap and meet other participants.');
  String get onbCreateTitle => _t('Kendi Aktiviteni Oluştur', 'Create Your Own Activity');
  String get onbCreateDesc => _t('Birkaç dakikada bir aktivite oluştur, harita ile konum seç, resim ekle.', 'Create an activity in minutes, pick a location on the map, add a photo.');
  String get onbPermsTitle => _t('Konum ve Bildirim İzinleri', 'Location & Notification Permissions');
  String get onbPermsDesc => _t('Yakınındaki aktiviteleri göstermek için konumuna, etkinlik güncellemeleri için bildirim iznine ihtiyacımız var. Bir sonraki adımda sorulacak.', 'We need your location to show nearby activities and notification permission for activity updates. You will be asked in the next step.');
  String get skipLabel => _t('Atla', 'Skip');

  // ── Map / Create ──
  String get placeNotFound => _t('Yer bulunamadı', 'Place not found');
  String get locationPermissionDeniedForever => _t('Konum izni kalıcı olarak reddedildi', 'Location permission permanently denied');
  String get pickLocationTitle => _t('Konum Seç', 'Pick Location');
  String get pickLocationSelect => _t('Seç', 'Select');
  String get searchPlaceHint => _t('Yer ara (örn: Kadıköy)', 'Search place (e.g. Kadıköy)');
  String get searchError => _t('Arama hatası', 'Search error');
  String get locationFetchFailed => _t('Konum alınamadı', 'Could not get location');
  String get titleRequired => _t('Başlık gerekli', 'Title is required');
  String get pleasePickLocation => _t('Lütfen haritadan konum seçin', 'Please pick a location on the map');
  String get categoryLockedHelper => _t('Katılımcı olduğu için kategori değiştirilemez', 'Category cannot be changed because there are participants');
  String get optionalImageHint => _t('Seçmezsen kategori resmi kullanılır', "If not picked, the category image will be used");
  String get update => _t('Güncelle', 'Update');

  // ── Change summary words (for notification) ──
  String get changeTitle => _t('başlık', 'title');
  String get changeDescription => _t('açıklama', 'description');
  String get changeLocationName => _t('konum adı', 'location name');
  String get changeMaxParticipants => _t('katılımcı sayısı', 'max participants');
  String get changeDateTime => _t('tarih/saat', 'date/time');
  String get changeLocation => _t('konum', 'location');
  String get changeImage => _t('resim', 'image');
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['tr', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
