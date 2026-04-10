# Release Notes

## v0.1.0 — MVP Skeleton (2026-04-10)

### Eklenler

**Temel Framework**
- `main.sh` — tam etkileşimli akış (distro → PM → DE → preset/theme/app → plan → execute)
- 9 lib modülü (`lib/common.sh`, `logging.sh`, `ui.sh`, vb.)
- Config-driven YAML tanımları (`configs/distros.yaml`, `desktops.yaml`, `presets.yaml`, `themes.yaml`, `apps.yaml`)
- 21 placeholder install script (`scripts/presets/`, `themes/`, `apps/`, `hyunarch/`)
- Temel test suite (`tests/smoke/`, `unit/`, `config/`, `dispatch/`, `integration/`)

**Özellikler**
- Distro seçimi ve paket yöneticisi doğrulama
- Desktop environment branching (hyprland, kde, gnome)
- Preset kurulumları
- Tema seçimi
- Kategorili uygulama yönetimi
- Per-app install mode seçimi: "clean install" veya "Hyunarch config ile kur"
- Execution plan generation ve görüntüleme
- Dry-run modu (--dry-run flag)
- Kapsamlı logging ve error handling

**Infrastructure**
- `.gitattributes` — LF line endings standardizasyonu
- Temel dokümantasyon (6 md dosyası)

### Bilinen Sınırlamalar

1. **Gerçek paket kurulumu test edilmedi**: Dry-run mode yalnızca script execution path'lerini doğrular. Gerçek `pacman`, `apt`, `dnf` komutları henüz test edilmedi.

2. **UI Interactive mode test edilmedi**: `ui_menu_*` fonksiyonları interaktif input gerektirir. Bu path'ler automated testler tarafından tam olarak cover edilmiyor.

3. **AUR helpers (yay/paru) container'da mevcut değil**: Docker testleri Arch container'da `yay`/`paru` kurmaz. Manual test gerekli.

4. **Placeholder scriptler henüz uygulanmadı**: `scripts/` altındaki tüm dosyalar şu an placeholder'dır. Gerçek kurulum mantığı henüz yazılmamıştır.

### Sonraki Adımlar

- [ ] Gerçek install script'lerini yazma (presets, themes, apps)
- [ ] Hyunarch config installer hook'larını uygulanma
- [ ] UI interaktif path'lerinin entegrasyonlu test'i
- [ ] AUR helpers (yay, paru) entegrasyonu
- [ ] Gerçek paket kurulumu ile smoke test'ler
- [ ] User acceptance testing (UAT)

---

## v0.2.0 — Docker Test Infrastructure (2026-04-10)

### Eklenler

**Docker Testing**
- 3 Dockerfile: `Dockerfile.arch`, `Dockerfile.ubuntu`, `Dockerfile.fedora`
- `docker/test-all.sh` — tüm distrolarda build + test + shellcheck + dry-run
- `docker/dryrun-main.sh` — 8 kombinasyon non-interactive dry-run
- `docker/run-*.sh` — Arch, Ubuntu, Fedora için interaktif shell

**CI/CD**
- `.github/workflows/test.yml` — GitHub Actions workflow (push ve PR'da çalışır)
- Her distro için paralel test matrix
- ShellCheck entegrasyonu (--severity=error)

**Değişiklikler**
- `lib/distro.sh`, `lib/package_manager.sh`, `lib/desktop_environment.sh` — non-interactive bypass logic eklendi (`HYUNARCH_NON_INTERACTIVE` env var)
- `main.sh` — non-interactive moda giren menü exit logic'i eklendi
- `lib/common.sh` — `MSYS_NO_PATHCONV` workaround Windows Git Bash uyumluluğu için
- `.dockerignore` — image'dan `.git`, `docs/`, `static/`, `.github/` gibi dosyalar hariç tutuldu

**Test Matrisi**
8 kombinasyon doğrulanıyor:
- Arch (pacman) × 3 DE (hyprland, kde, gnome)
- Ubuntu (apt) × 2 DE (kde, gnome)
- Fedora (dnf) × 3 DE (hyprland, kde, gnome)

### Test Kapsamı

✓ Config loading ve şema doğrulama  
✓ Distro-PM eşleşmesi  
✓ DE branching ve option filtering  
✓ Plan generation (exec plan array format)  
✓ Script path resolution  
✓ ShellCheck (--severity=error)  
✓ 8 kombinasyon dry-run doğrulama  

### Bilinen Sınırlamalar

1. **Gerçek paket kurulumu hala test edilmiyor**: Docker environment'ı `--dry-run` modu ile çalışır. Paket install komutları çalıştırılmaz.

2. **UI interactive path'i container'da test edilmemiyor**: Docker testleri non-interactive mode'da çalışır. `ui_menu_*` fonksiyonları stdout manipülasyonu gerektirir.

3. **Hyunarch script hooks henüz uygulanmadı**: Plan generation modu "direct" (presets/themes) ve "clean"/"hyunarch" (apps) destekler ama gerçek `scripts/hyunarch/` hook'ları henüz uygulanmadı.

### Sonraki Adımlar

- [ ] Gerçek paket kurulumunu test eden integration tests
- [ ] AUR helpers (yay, paru) container'a eklenme ve test
- [ ] Windows Git Bash ve Linux native bash uyumluluğu tam test
- [ ] UI interactive mode'unu pexpect/expect ile test
- [ ] Per-DE app filtering doğrulama
- [ ] Release pipeline'ı (distribution, tagging)

### Önemli Notlar

**Docker Workflow**
```bash
# Hızlı lokal test
bash docker/test-all.sh

# Non-interactive 8 kombinasyon
bash docker/dryrun-main.sh
```

**CI/CD Behavior**
GitHub Actions, her push'ta otomatik olarak 3 distro × 3 test türü çalıştırır (toplamda 9 iş). Fail-fast devre dışıdır — tüm kombinasyonlar test edilir.

---

## Version Compatibility

| Version | Min Bash | Target OS | Status |
|---------|----------|-----------|--------|
| v0.1.0 | 4.4+ | Linux | MVP (non-interactive test capable) |
| v0.2.0 | 4.4+ | Linux | Docker test infra added |

---

## Known Issues

Şu anda bilinen critilal issue yok. Bkz. "Bilinen Sınırlamalar" bölümü her release'de.
