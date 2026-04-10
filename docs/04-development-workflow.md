# Geliştirme Akışı

## 1. Planner ile başla

Planner agent önce şu sorulara cevap vermelidir:
- Bu değişiklik yeni bir akış mı ekliyor?
- Yeni bir distro, paket yöneticisi veya desktop environment mı geliyor?
- Bu değişiklik config mi ağırlıklı, script mi ağırlıklı?
- Mevcut dispatch yapısını etkiliyor mu?
- Hyunarch entegrasyonunu etkiliyor mu?

## 2. Coder küçük ve güvenli adımlarla ilerlemeli

Coder agent:
- tek seferde büyük rewrite yapmamalı
- önce config yapısını hazırlamalı
- sonra Bash dispatch ve menü akışını bağlamalı
- en son gerçek script çağrılarını bağlamalı

## 3. Tester gerçek sistem değişikliği yerine davranışı doğrulamalı

Öncelikli test alanları:
- yanlış distro ve package manager eşleşmeleri
- yanlış desktop environment seçenekleri
- eksik script path'leri
- app başına clean / hyunarch mode branching
- execution plan doğruluğu

## 4. Reviewer sadece kodu değil teslimatı da incelemeli

Reviewer kontrol etmelidir:
- shell güvenliği
- config drift riski
- yanlış branch/dispatch ihtimali
- commit kapsamı
- release note ve patch note uygunluğu

## Önerilen Teslim Sırası

1. klasör yapısını kur
2. config dosyalarını tanımla
3. config loader ve lookup katmanını yaz
4. kullanıcı akışını yaz
5. execution plan katmanını ekle
6. script dispatcher'ı bağla
7. dry-run desteğini ekle
8. test ve dokümantasyonu güncelle

## Docker Test Workflow

### Hızlı Start

```bash
# Tüm distrolarda full test suite
bash docker/test-all.sh

# Tek distro interaktif shell
bash docker/run-arch.sh
bash docker/run-ubuntu.sh
bash docker/run-fedora.sh
```

### Non-Interactive Mode

Docker container'larında interaktif olmayan test çalıştırmak için şu env vars'ı ayarlayın:

```bash
export HYUNARCH_NON_INTERACTIVE=1
export HYUNARCH_DISTRO="arch"        # arch, ubuntu, debian, fedora
export HYUNARCH_PM="pacman"          # pacman, yay, paru, apt, dnf
export HYUNARCH_DE="hyprland"        # hyprland, kde, gnome
export HYUNARCH_DRY_RUN=1

bash docker/dryrun-main.sh
```

### Test Matrisi

`docker/dryrun-main.sh` 8 kombinasyon test eder:

| Distro | PM | DE | Sebepleş |
|--------|----|----|---------|
| arch | pacman | hyprland | Arch native AUR WM |
| arch | pacman | kde | Arch + KDE |
| arch | pacman | gnome | Arch + GNOME |
| ubuntu | apt | kde | Ubuntu KDE |
| ubuntu | apt | gnome | Ubuntu GNOME |
| fedora | dnf | hyprland | Fedora + Hyprland |
| fedora | dnf | kde | Fedora + KDE |
| fedora | dnf | gnome | Fedora + GNOME |

### CI/CD

GitHub Actions workflow: `.github/workflows/test.yml`

Her push ve PR'da otomatik çalışır:
1. 3 distro için Docker image'ı build et
2. Test suite'i çalıştır (HYUNARCH_DRY_RUN=1)
3. ShellCheck ve statik analiz yap
4. 8 kombinasyon dry-run testi yap

## Local Geliştirme Kontrol Listesi

Yeni kod yazmadan önce:

```bash
# 1. Mevcut testlerin geçip geçmediğini kontrol et
bash docker/test-all.sh

# 2. ShellCheck çalıştır
shellcheck --severity=error lib/*.sh main.sh docker/*.sh tests/run_all.sh

# 3. Config doğruluğunu kontrol et
bash tests/config/test_config_schema.sh

# 4. Dispatch path'lerini doğrula
bash tests/dispatch/test_script_paths.sh

# 5. Dry-run modu ile interaktif akışı test et
bash docker/dryrun-main.sh
```
