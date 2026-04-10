# Önerilen Klasör Yapısı

```text
.
├── main.sh
├── .gitattributes
├── .dockerignore
├── lib/
│   ├── common.sh
│   ├── ui.sh
│   ├── logging.sh
│   ├── distro.sh
│   ├── package_manager.sh
│   ├── desktop_environment.sh
│   ├── config_loader.sh
│   ├── planner.sh
│   └── dispatcher.sh
├── configs/
│   ├── distros.yaml
│   ├── desktops.yaml
│   ├── presets.yaml
│   ├── themes.yaml
│   └── apps.yaml
├── scripts/
│   ├── presets/
│   ├── themes/
│   ├── apps/
│   └── hyunarch/
├── docker/
│   ├── Dockerfile.arch
│   ├── Dockerfile.ubuntu
│   ├── Dockerfile.fedora
│   ├── test-all.sh
│   ├── dryrun-main.sh
│   ├── run-arch.sh
│   ├── run-ubuntu.sh
│   └── run-fedora.sh
├── .github/
│   └── workflows/
│       └── test.yml
├── tests/
│   ├── run_all.sh
│   ├── smoke/
│   ├── dispatch/
│   ├── config/
│   ├── integration/
│   └── unit/
├── docs/
├── static/
└── CLAUDE.md
```

## Dizinlerin Sorumluluğu

### `main.sh`
Uygulamanın giriş noktasıdır.

### `lib/`
Ortak yardımcı fonksiyonlar ve akış yönetimi burada yer alır.

### `configs/`
Sistemin sunacağı seçeneklerin kaynak tanımıdır.

### `scripts/`
Gerçek kurulum ve özelleştirme scriptleri burada bulunur.

### `docker/`
Docker container'larında test ortamı sağlayan araçlar:
- `Dockerfile.*` — her distro için container image tanımı
- `test-all.sh` — tüm distrolarda tam test suite çalıştırır
- `dryrun-main.sh` — 8 kombinasyon non-interactive dry-run testi
- `run-*.sh` — etkileşimli shell ortamları

### `.github/workflows/`
CI/CD pipeline tanımı. `test.yml` GitHub Actions'ta otomatik test çalıştırır.

### `tests/`
Dry-run, smoke test, config doğrulama ve dispatch testleri burada tutulur.

### `docs/`
Proje akışı, mimari ve katkı kuralları burada tutulur.

### `static/`
Statik kaynaklar (ikon, banner vb.).

### `.gitattributes` ve `.dockerignore`
Git ve Docker yapılandırması:
- `.gitattributes` — LF line endings standardizasyonu
- `.dockerignore` — Docker image'dan hariç tutulacak dosyalar
