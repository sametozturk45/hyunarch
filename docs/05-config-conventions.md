# Config Kuralları

## Amaç

Config dosyaları, sistemin kullanıcıya hangi seçenekleri sunacağını ve hangi scriptleri çalıştıracağını tanımlar.

## Temel Kurallar

- Config dosyaları seçilebilir seçeneklerin kaynağıdır.
- Bash içinde büyüyen sabit liste kullanımı minimumda tutulmalıdır.
- Config içindeki script referansları doğrulanmadan çalıştırılmamalıdır.
- Her yeni seçenek için önce config tasarımı düşünülmelidir.

## Önerilen Alanlar

### Distrolar
- id
- display_name
- supported_package_managers
- default_package_manager

### Desktop Environments
- id
- display_name
- supported_presets
- supported_themes
- supported_app_categories

### Presetler
- id
- display_name
- desktop_environments
- scripts
- description

### Temalar
- id
- display_name
- desktop_environments
- script
- description

### Uygulamalar
- id
- display_name
- category
- desktop_environments
- clean_install_script
- hyunarch_install_script
- supports_clean_install
- supports_hyunarch_config

## Önemli Davranış Kuralı

Bir uygulama yalnızca desteklediği modları göstermelidir.

Örnek:
- sadece clean install destekliyorsa `Hyunarch config ile kur` seçeneği gösterilmemeli
- sadece Hyunarch config destekliyorsa clean install seçeneği gösterilmemeli

## Schema Drift Uyarısı

Config şeması değişirse şunlar birlikte güncellenmelidir:
- config loader
- lookup fonksiyonları
- dispatcher
- testler
- dokümantasyon
