# Patch Notes (Developer Technical Notes)

Bu dokument, her major release'in teknik detaylarını, design kararlarını ve geliştiriciler için önemli implementasyon notlarını içerir.

---

## v0.1.0 — MVP Skeleton

### Design Kararları

#### 1. YAML Parser Seçimi (Pure Bash)

**Karar**: YAML parsing için python, perl gibi dışarıdan tool kullanmadan pure Bash ile yaptık.

**Neden**:
- Python orchestration'ı avoid etmek (CLAUDE.md kuralı)
- Minimal dışarıdan bağımlılık
- Linux native environment'ında YAML basit key-value dosyaları olarak tutabilir

**Implementasyon**:
- lib/config_loader.sh — parse_yaml() fonksiyonu satır-satır okur
- Inline list syntax: [item1, item2, item3]
- Pipe character (|) forbidden (plan entry delimiter)
- Keyword "all" special meaning: supported_distros: [all] = universal

#### 2. Execution Plan Array Format

**Karar**: Seçimlerden execution plan'ı generate ederken pipe-delimited string format'ında tuttuk.

**Format**: distro|pm|de|preset_id|theme_id|app_id|install_mode|script_path

**Neden**:
- Nested array structure bash < 5.0 compat için complex olurdu
- Pipe delimiter'ını seçtik (şimdi forbidden config rule'u)
- String manipulation tools (grep, sed) ile uyumlu

#### 3. Non-Interactive Bypass Architecture

**Karar**: Docker container'larında ve CI/CD'de non-interactive mode'ı enable etmek için HYUNARCH_NON_INTERACTIVE env var'ını kullandık.

**Implementasyon**:
- distro_prompt() — HYUNARCH_NON_INTERACTIVE=1 ise env var'dan oku
- pm_prompt() — benzer
- de_prompt() — benzer
- main.sh — non-interactive ise plan'dan sonra exit et

#### 4. Distro Detection Logic

**Karar**: Runtime'da distro'yu detect etmek yerine user'dan prompt almayı seçtik.

**Neden**:
- Multi-target system: script'ler farklı distro'larda çalışacak
- Container test'lerde detection yanıltıcı olabilir
- Explicit user choice daha güvenli

#### 5. Desktop Environment Selection as Primary Branching

**Karar**: DE seçimi yapıldıktan sonra sadece o DE'nin desteklediği preset/theme/app'ler gösterilir.

**Neden** (CLAUDE.md rule 5):
- DE-specific config leakage prevent et
- Menu clutter'ını azalt
- Clear option scoping

#### 6. Hyunarch Config Install Hooks

**Karar**: Hyunarch config installs sadece scripts/hyunarch/ altında predefined script'ler çalıştırabilir.

**Neden** (CLAUDE.md rule 6):
- Explicit, intentional dispatch
- Config drift risk'i azalt
- Clean vs Hyunarch modes mix'lenmiş olmasını prevent et

---

## v0.2.0 — Docker Test Infrastructure

### Design Kararları

#### 1. Container Seçimi

**Karar**: Distro-specific container'lar: Dockerfile.arch, Dockerfile.ubuntu, Dockerfile.fedora

**Neden**:
- Test environment'ı production environment'a match et
- Distro-specific package manager'ları test et
- AUR (yay/paru) Arch-exclusive
- DE package'ları distro'ya göre değişir

#### 2. MSYS_NO_PATHCONV Workaround (Windows Git Bash)

**Karar**: docker/test-all.sh'de export MSYS_NO_PATHCONV=1

**Neden**:
- Git Bash path conversion'u off tut
- Docker volume mount hatalarını prevent et
- MSYS-specific env variable

#### 3. ShellCheck Severity Level

**Karar**: --severity=error mode. Warning'ler report edilmez.

**Neden**:
- Syntax errors block
- Style divergence OK
- CI/CD fail'ini prevent et minor issue'lerden

#### 4. Test Matrisi Boyutu

**Karar**: 8 kombinasyon dry-run:

- arch × pacman × [hyprland, kde, gnome]
- ubuntu × apt × [kde, gnome]
- fedora × dnf × [hyprland, kde, gnome]

**Neden**:
- 3 distro representative
- 3 DE representative
- PM'ler distro'ya locked
- Coverage vs build time trade-off

#### 5. Dry-Run Mode + Non-Interactive Combination

**Karar**: HYUNARCH_DRY_RUN=1 ve HYUNARCH_NON_INTERACTIVE=1 birlikte

#### 6. GitHub Actions Matrix Strategy

**Karar**: .github/workflows/test.yml matrix strategy

**Neden**:
- 3 distro paralel build
- fail-fast: false
- Clear reporting per distro

### Implementation Details

#### Modules

- lib/config_loader.sh — YAML parse
- lib/distro.sh — distro lookup
- lib/package_manager.sh — PM validation
- lib/desktop_environment.sh — DE filtering
- lib/planner.sh — plan generation
- lib/dispatcher.sh — script execution

#### Testing Strategy

Unit tests, config tests, dispatch tests, smoke tests, integration tests

#### Environment Exports

- HYUNARCH_DISTRO
- HYUNARCH_PM
- HYUNARCH_DE
- HYUNARCH_INSTALL_MODE
- HYUNARCH_DRY_RUN
- HYUNARCH_VERBOSE

---

## Migration Notes

### v0.1.0 — v0.2.0

**Breaking Changes**: None

**Deprecations**: None

**Migration**: 
- Developers: bash docker/test-all.sh ile test et
- CI/CD: otomatik çalışır

---

## Future Considerations (v0.3.0+)

### Planned

1. Real Install Command Execution
2. AUR Helper Support
3. Interactive UI Refactor
4. Config Validation Tool
5. Install State Persistence
6. Rollback Support

### Tentative

1. Python Replacement Tools
2. Alpine Container
3. Module-Based Distribution

---

## Performance Notes

Container build time: ~45s (Arch), ~30s (Ubuntu), ~40s (Fedora)

Use Docker cache for CI optimization.
