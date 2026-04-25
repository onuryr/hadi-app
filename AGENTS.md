# AGENTS.md — Hadi App Çalışma Kuralları

Bu dosya, repo üzerinde çalışan AI agent'larının (Paperclip, Claude, vb.) uyması gereken kuralları tanımlar. Her görev başlamadan ÖNCE bu dosyayı oku.

---

## 1. Git & Commit Kuralları

- **Asla local commit bırakma.** Görev tamamlandığında her commit `git push origin main` (veya feature branch + PR) ile remote'a gönderilmiş olmalı. Çıkmadan önce `git status` temiz, `git log origin/main..HEAD` boş olsun.
- **Branch protection açık** — main'e direkt push yasak, PR gerekli, CI yeşil olmalı.
- **Tek görev = tek PR**. Bir PR'da birden fazla feature karıştırma. Tek concern, tek değişiklik.
- **Commit mesajında ticket ID** (örn `feat(HAD-22): add rating UI`).
- **PR'ı kendin merge et**: Görevini tamamlayıp PR açtıktan sonra:
  1. CI'ın geçmesini bekle: `gh pr checks <PR_NUMBER> --watch`
  2. CI yeşil olunca: `gh pr merge <PR_NUMBER> --squash --delete-branch`
  3. Lokal main'i güncelle: `git checkout main && git pull`
  4. Telefonu güncelle (Bölüm 6)
  - **CI fail olursa düzelt** — kırmızı PR'ı asla bırakma. Hata mesajını oku, fix push et, tekrar bekle.
  - Branch protection veya merge engeli olursa kullanıcıya bildir, atla.

## 2. Frontend ↔ Backend Senkronu

- **API contract değişiyorsa Flutter aynı PR'da güncellenmeli.** Backend response/request formatı değiştirilirse (örn. array → `PagedResult`), Flutter'daki tüketici kodu da aynı commit setinde güncellensin.
- Backwards compatible olmuyorsa yeni endpoint olarak ekle (`/v2/...`), eskiyi bir süre koru.
- Backend Railway'e push olunca anında deploy olur — Flutter güncel değilse production app kırılır.

## 3. Dosya Sahipliği & Çakışma

- **Aynı dosyaya paralel task verme**. Özellikle `lib/screens/activity_detail_screen.dart` çok dokunulan bir dosya — paralel değişikliklerde sıralı çalış.
- **Tek görev — tek dosya scope**. `activity_detail_screen.dart` üzerinde çalışıyorsan sadece spesifik fonksiyonu/section'ı değiştir. Import'lara, başka method'lara dokunma.
- Dosyalar 600 satırı aştığında refactor'a aday — yeni widget/screen'e böl.

## 4. SQL & Schema Değişiklikleri

- Supabase'de yeni kolon/tablo eklenirse SQL'i `migrations/YYYY-MM-DD_description.sql` olarak commit et.
- RLS policy değişiklikleri de migration dosyasında olmalı.
- Manual SQL Editor'da çalıştırma → kayıt kalmaz, başka cihazda çalışmaz.

## 5. Test Kuralları

- **Gerçek cihazda test et.** Sadece `flutter analyze` veya unit test geçmesi yetmez. Etkilenen UI flow'unu Android emülatör veya gerçek cihazda elle test edip "X yaptım, beklenen şey oldu" şeklinde rapor et.
- **Etkilenen diğer flow'ları da test et.** Bir özelliği değiştirirken bağlı flow'ların hâlâ çalıştığını doğrula (örn. `joinActivity` değişikliği detail screen, home, inbox'ı etkiler).
- Acceptance criteria task açıklamasında olsun, hepsini tik atarak gönder.

## 6. Build & Telefon Güncellemesi

### Test cihazı bilgileri
- **Cihaz**: Samsung Galaxy S23 (model: SM-S911B)
- **Device ID**: `RFCWA0ZQX1K`
- **Android sürüm**: 16 (API 36), arm64

### Deploy adımları
1. `flutter devices` çalıştır, çıktıda `RFCWA0ZQX1K` görünüyorsa devam.
2. Görünmüyorsa:
   - **ADB sunucusunu başlat**: `adb start-server` (ADB path: `C:\Users\onur_\AppData\Local\Android\Sdk\platform-tools\adb.exe`)
   - **Authorization prompt**: Telefon ekranında "USB hata ayıklamasına izin ver?" dialog'u olabilir, kullanıcıya bildir.
   - **PATH kontrolü**: Senin cwd'nde `flutter` ve `adb` PATH'te olmayabilir. Tam path kullan ya da kullanıcının PATH'inden inherit et.
3. Yükle: 
   ```
   flutter run -d RFCWA0ZQX1K --release
   ```
   Veya hot reload için debug:
   ```
   flutter run -d RFCWA0ZQX1K
   ```
4. Build başarılı olduktan sonra "Telefon güncellendi, X özelliğini test et" şeklinde kullanıcıya bildir.

### Test
- "Test cihazda X yaptım, beklenen sonuç Y oldu" şeklinde rapor et.
- CI fail eden bir PR merge edilmesin.
- Pre-commit hook'ta `flutter analyze` çalışsın.

## 7. Aynı Anda Tek Agent

- Bu repo üzerinde aktif çalışan agent: **Paperclip** (veya görev başlamadan önce belirt). Sürmekte olan task varken başka bir agent değişiklik yapmasın — conflict kaçınılmaz.
- Görev sonunda PR merge + push'ı doğrula.

## 8. Mevcut Mimari

- Backend: ASP.NET Core 8, Railway deploy, Supabase PostgreSQL + PostGIS
- Flutter: Material 3, Supabase SDK, Firebase (FCM + Crashlytics)
- `GetNearby` → `PagedResult<ActivityDto>` (`{items, page, pageSize, totalCount}`)
- PostGIS geometry → EWKB hex (Flutter'da `_parseEwkbHex` ile parse)
- Aktivite participation status: `pending` | `approved` | `rejected`
- Aktivite status: `active` | `inactive` (cancel)
