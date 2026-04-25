# AGENTS.md — Hadi App Çalışma Kuralları

Bu dosya, repo üzerinde çalışan AI agent'larının (Paperclip, Claude, vb.) uyması gereken kuralları tanımlar. Her görev başlamadan ÖNCE bu dosyayı oku.

---

## 1. Git & Commit Kuralları

- **Asla local commit bırakma.** Görev tamamlandığında her commit `git push origin main` (veya feature branch + PR) ile remote'a gönderilmiş olmalı. Çıkmadan önce `git status` temiz, `git log origin/main..HEAD` boş olsun.
- **Branch protection açık** — main'e direkt push yasak, PR gerekli, CI yeşil olmalı.
- **Tek görev = tek PR**. Bir PR'da birden fazla feature karıştırma. Tek concern, tek değişiklik.
- **Commit mesajında ticket ID** (örn `feat(HAD-22): add rating UI`).

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

## 6. Build Pipeline

- **APK build edildikten sonra Firebase App Distribution'a yolla** (CI'da kurulu). Test cihazlarına otomatik dağıtılsın.
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
