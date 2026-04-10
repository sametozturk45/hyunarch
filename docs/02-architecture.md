# Mimari Tasarım

## Mimari Özeti

Sistem üç ana katmandan oluşur:

1. **Giriş ve akış yönetimi**
2. **Tanım ve seçim verisi**
3. **Kurulum scriptleri**

## 1. Giriş ve Akış Yönetimi

Bu katman Bash ile yazılır.

Sorumlulukları:
- kullanıcıdan seçim almak
- seçimleri doğrulamak
- config verisini okumak
- uygun seçenekleri filtrelemek
- execution plan üretmek
- script dispatch etmek
- hata ve log yönetimi yapmak

Örnek dosyalar:
- `main.sh`
- `lib/ui.sh`
- `lib/distro.sh`
- `lib/package_manager.sh`
- `lib/desktop_environment.sh`
- `lib/planner.sh`
- `lib/dispatcher.sh`

## 2. Tanım ve Seçim Verisi

Bu katman YAML/JSON ile tutulur.

Örnek içerikler:
- hangi distro hangi paket yöneticilerini destekler
- hangi desktop environment hangi presetleri destekler
- hangi tema hangi scripti çalıştırır
- hangi uygulama kategoride yer alır
- hangi uygulama Hyunarch config destekler
- hangi uygulama clean install destekler

Örnek dosyalar:
- `configs/distros.yaml`
- `configs/desktops.yaml`
- `configs/presets.yaml`
- `configs/themes.yaml`
- `configs/apps.yaml`

## 3. Kurulum Scriptleri

Gerçek işlemler burada yapılır.

Örnek klasörler:
- `scripts/presets/`
- `scripts/themes/`
- `scripts/apps/`
- `scripts/hyunarch/`

## Önerilen Akış

1. Distro seç
2. Paket yöneticisini doğrula veya seçtir
3. Desktop environment seç
4. İlgili preset/theme/app seçeneklerini config üzerinden yükle
5. Kullanıcı seçimlerini topla
6. Her uygulama için kurulum modunu belirle
7. Execution plan oluştur
8. Planı kullanıcıya göster
9. Onay al
10. Scriptleri sırayla çalıştır

## Kritik Tasarım Kuralı

**Seçim alındıktan sonra komutları hemen çalıştırma.**
Önce bir plan üret, sonra yürüt.

Bu yaklaşım:
- hata ayıklamayı kolaylaştırır
- dry-run yapmayı mümkün kılar
- yanlış seçimlerin etkisini azaltır
- test yazmayı kolaylaştırır
