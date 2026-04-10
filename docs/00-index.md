# Documentation Index

Bu dokümantasyon seti, Hyunarch projesinin kullanıcıları, geliştiricileri ve maintainers'ı için yönlendirme sağlar.

## For Everyone

**01. [Project Overview](01-project-overview.md)**
- Projenin amacı
- Neden Bash ve config-driven tasarım
- Temel hedefler

## For Developers

**02. [Architecture](02-architecture.md)**
- 3-layer architecture (UI flow, definitions, scripts)
- Önerilen akış
- Kritik tasarım kuralları

**03. [Directory Structure](03-directory-structure.md)**
- Tüm klasörlerin sorumluluğu
- Dosya organizasyonu
- Docker ve CI/CD entegrasyon noktaları

**04. [Development Workflow](04-development-workflow.md)**
- Planner, Coder, Tester, Reviewer rolleri
- Önerilen teslim sırası
- Docker test workflow
- Local kontrol listesi

**05. [Config Conventions](05-config-conventions.md)**
- Config kuralları
- Önerilen alanlar per entity
- Davranış kuralları
- Schema drift uyarısı

**06. [Config Schema Reference](06-config-schema.md)**
- Tüm YAML dosyası için schema
- Field definitions
- Dispatch wiring
- Yeni entry ekleme guide'ı

## For DevOps / CI/CD

**07. [Docker Testing Guide](07-docker-testing.md)**
- Docker test infra overview
- Quick start komutları
- Non-interactive mode
- GitHub Actions workflow
- Windows Git Bash uyumluluğu
- Troubleshooting

## For Maintainers / Release Managers

**08. [Release Notes](08-release-notes.md)**
- User-facing release history
- v0.1.0 — MVP Skeleton
- v0.2.0 — Docker Test Infrastructure
- Bilinen sınırlamalar ve sonraki adımlar
- Version compatibility matrix

**09. [Patch Notes](09-patch-notes.md)**
- Developer technical notes
- v0.1.0 design kararları
- v0.2.0 design kararları
- Implementation details
- Testing strategy
- Migration notes
- Future considerations

---

## Quick Navigation

### Yeni bir feature ekliyorsam:
1. [02. Architecture](02-architecture.md) — tasarımı planla
2. [05. Config Conventions](05-config-conventions.md) — config yapısını tanımla
3. [06. Config Schema Reference](06-config-schema.md) — schema'yı güncelle
4. [04. Development Workflow](04-development-workflow.md) — teslim sırasını takip et

### Test yazıyorsam:
1. [04. Development Workflow](04-development-workflow.md) — test kontrol listesi
2. [07. Docker Testing Guide](07-docker-testing.md) — Docker test infra

### Release yapıyorsam:
1. [08. Release Notes](08-release-notes.md) — user-facing notes
2. [09. Patch Notes](09-patch-notes.md) — technical notes
3. [04. Development Workflow](04-development-workflow.md) — delivery checklist

---

## Documentation Status

| File | Version | Last Updated | Status |
|------|---------|--------------|--------|
| 00-index.md | 0.2.0 | 2026-04-10 | Current |
| 01-project-overview.md | 0.1.0 | 2026-04-10 | Current |
| 02-architecture.md | 0.1.0 | 2026-04-10 | Current |
| 03-directory-structure.md | 0.2.0 | 2026-04-10 | Updated |
| 04-development-workflow.md | 0.2.0 | 2026-04-10 | Updated |
| 05-config-conventions.md | 0.1.0 | 2026-04-10 | Current |
| 06-config-schema.md | 0.1.0 | 2026-04-10 | Current |
| 07-docker-testing.md | 0.2.0 | 2026-04-10 | Updated |
| 08-release-notes.md | 0.2.0 | 2026-04-10 | New |
| 09-patch-notes.md | 0.2.0 | 2026-04-10 | New |

---

## Key Concepts

### Config-Driven Design

YAML config files are the source of truth. Bash scripts read and dispatch based on config, but don't hardcode option lists.

### Non-Interactive Mode

HYUNARCH_NON_INTERACTIVE env var allows full test flow without user input. Used in:
- Docker containers
- CI/CD pipelines
- Dry-run validation

### Execution Plan

Before executing scripts, the system generates a plan (pipe-delimited format):
```
distro|pm|de|preset_id|theme_id|app_id|install_mode|script_path
```

This enables:
- Dry-run mode (show plan, don't execute)
- User confirmation before destructive actions
- Easy rollback/audit

### Desktop Environment Branching

DE is the primary branching point. All preset/theme/app options are filtered by DE.

---

## Contributing

Before submitting:
1. Read [Architecture](02-architecture.md)
2. Follow [Development Workflow](04-development-workflow.md)
3. Update relevant docs alongside code
4. Ensure tests pass: bash docker/test-all.sh

---

## Maintenance Tasks

### Weekly

- [ ] Monitor CI/CD failures in GitHub Actions
- [ ] Review open issues

### Per Release

- [ ] Update 08-release-notes.md with user-facing changes
- [ ] Update 09-patch-notes.md with technical details
- [ ] Verify all docs are aligned with codebase
- [ ] Test full workflow end-to-end

### Per Major Version

- [ ] Audit architecture for breaking changes
- [ ] Update CLAUDE.md if rules change
- [ ] Review and update all docs
- [ ] Plan v(N+1) features
