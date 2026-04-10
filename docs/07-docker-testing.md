# Docker Testing Guide

## Overview

Hyunarch test suite'ini isolated Docker container'larında her target distro için çalıştırabilirsiniz.

Bu guide:
- Local development'ta Docker test etmeyi
- CI/CD pipeline'ında Docker'ı nasıl kullandığımızı
- Non-interactive test mode'unu
- Windows Git Bash compatibility'sini

anlatır.

## Prerequisites

- Docker installed and running
- Git Bash (Windows) veya native bash (Linux/macOS)

## Quick Start

```bash
# Tüm distrolarda full test suite (build + test + shellcheck + dry-run)
bash docker/test-all.sh

# Tek distro interaktif shell
bash docker/run-arch.sh
bash docker/run-ubuntu.sh
bash docker/run-fedora.sh
```

## Test Yapısı

### docker/test-all.sh

Tüm distrolarda sırayla çalıştıran master script:

1. 3 distro için Docker image'ı build et (Dockerfile.arch, .ubuntu, .fedora)
2. Her distro'da şu test'leri çalıştır:
   - Test suite (tests/run_all.sh)
   - ShellCheck (--severity=error)
   - Dry-run main.sh doğrulama

3. Sonuçları tabloda göster

**Kullanım**:
```bash
bash docker/test-all.sh
```

**Output**: PASS/FAIL summary per distro

### docker/dryrun-main.sh

8 kombinasyon non-interactive dry-run testi:

- arch/pacman/hyprland
- arch/pacman/kde
- arch/pacman/gnome
- ubuntu/apt/kde
- ubuntu/apt/gnome
- fedora/dnf/hyprland
- fedora/dnf/kde
- fedora/dnf/gnome

**Kullanım**:
```bash
# Container içinde
docker run -e HYUNARCH_DRY_RUN=1 hyunarch-test-arch bash docker/dryrun-main.sh
```

### docker/run-*.sh

Belirli distro'da interaktif shell:

```bash
bash docker/run-arch.sh
# → /hyunarch# bash main.sh
# (interaktif menü)
```

## Non-Interactive Mode

Docker container'larında ve CI/CD'de interaktif mode'ı bypass etmek için:

```bash
export HYUNARCH_NON_INTERACTIVE=1
export HYUNARCH_DISTRO="arch"        # arch, ubuntu, debian, fedora
export HYUNARCH_PM="pacman"          # pacman, yay, paru, apt, dnf
export HYUNARCH_DE="hyprland"        # hyprland, kde, gnome
export HYUNARCH_DRY_RUN=1            # Don't execute real scripts

bash main.sh
```

Bu environment variable'ları set'leyince:
- Distro prompt'u atla, HYUNARCH_DISTRO'yu kullan
- PM prompt'u atla, HYUNARCH_PM'yi kullan
- DE prompt'u atla, HYUNARCH_DE'yi kullan
- Execution plan'ını generate et, exit et (--dry-run mode'unda)

## CI/CD Integration

### GitHub Actions Workflow

`.github/workflows/test.yml` — her push ve PR'da otomatik çalışır.

**Jobs**:
- Matrix strategy: 3 distro × 3 step (tests, shellcheck, dry-run)
- fail-fast: false — tüm kombinasyonlar test edilir
- Parallelization: 3 distro aynı anda build

**Trigger**:
```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
```

## Windows Git Bash Uyumluluğu

### Sorun

Windows Git Bash, Docker volume path'ini convert etmeye çalışır:
- `C:/Users/Hyuna/Desktop/Hyunarch` → `/mnt/c/Users/...`
- Bu dönüşüm, volume mount'u fail edebilir

### Çözüm

`docker/test-all.sh` içinde:

```bash
export MSYS_NO_PATHCONV=1
```

Bu env variable, Git Bash path conversion'u off tutar.

**Scope**: Sadece Windows Git Bash kullanan developers. Linux/macOS'te effect yok.

## Local Development Kontrol Listesi

Yeni kod yazmadan önce:

```bash
# 1. Docker image'ı build et
docker build -f docker/Dockerfile.arch -t hyunarch-test-arch .

# 2. Test suite'i çalıştır
docker run --rm -v "$(pwd):/hyunarch:ro" -e HYUNARCH_DRY_RUN=1 \
  hyunarch-test-arch bash tests/run_all.sh

# 3. ShellCheck
docker run --rm -v "$(pwd):/hyunarch:ro" hyunarch-test-arch \
  bash -c "shellcheck --severity=error /hyunarch/lib/*.sh /hyunarch/main.sh"

# 4. 8 kombinasyon dry-run
docker run --rm -v "$(pwd):/hyunarch:ro" -e HYUNARCH_DRY_RUN=1 \
  hyunarch-test-arch bash docker/dryrun-main.sh

# Veya hepsini bir komutla:
bash docker/test-all.sh
```

## Container Images Cleanup

Docker image'ları temizlemek için:

```bash
# Remove test images
docker rmi hyunarch-test-arch hyunarch-test-ubuntu hyunarch-test-fedora

# Remove build cache
docker builder prune
```

## Troubleshooting

### Volume Mount Error (Windows)

**Symptom**: `docker: Error response from daemon: invalid mount config`

**Fix**: 
```bash
export MSYS_NO_PATHCONV=1
bash docker/test-all.sh
```

### Container Out of Disk Space

**Symptom**: Build fails with "no space left on device"

**Fix**:
```bash
docker system prune --all --volumes
```

### Non-Interactive Mode Hangs

**Symptom**: `docker run` doesn't exit

**Fix**:
1. Verify all HYUNARCH_* env vars are set
2. Check /tmp/hyunarch-*.log for errors
3. Try interactive shell for debugging:
   ```bash
   docker run -it -v "$(pwd):/hyunarch:ro" hyunarch-test-arch bash
   ```

## Additional Resources

- `.github/workflows/test.yml` — CI/CD pipeline tanımı
- `docker/Dockerfile.*` — Container tanımları
- `docs/04-development-workflow.md` — Geliştirme workflow'u detayı
- `docs/08-release-notes.md` — Docker infrastructure version history
