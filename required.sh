#!/bin/bash

# Hata yönetimi ve güvenlik ayarları
set -euo pipefail
IFS=$'\n\t'

# Scriptin bulunduğu dizine git
cd "$(dirname "$(realpath "$0")")"

# Renk tanımlamaları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Dependencies ve AppConfig dosyalarının varlığını kontrol et
if [[ ! -f "data/dependencies.json" ]]; then
    log "ERROR" "dependencies.json dosyası bulunamadı!"
    exit 1
fi

if [[ ! -f "data/appconfig.json" ]]; then
    log "ERROR" "appconfig.json dosyası bulunamadı!"
    exit 1
fi

# Log fonksiyonu
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] [${level}] ${message}"
}

# Hata yönetimi fonksiyonu
handle_error() {
    local line_no=$1
    local error_code=$2
    log "ERROR" "Hata oluştu: Satır ${line_no}, Kod ${error_code}"
    exit 1
}

# Root kontrolü
if [[ $EUID -eq 0 ]]; then
    log "ERROR" "Bu betik root olarak çalıştırılmamalıdır!"
    exit 1
fi

# jq'yu yükle (eğer yoksa)
if ! command -v jq &> /dev/null; then
    log "INFO" "📦 jq yükleniyor..."
    if ! yay -S --noconfirm jq; then
        log "ERROR" "jq kurulumu başarısız!"
        exit 1
    fi
fi

log "INFO" "📌 Zorunlu bağımlılıklar kuruluyor..."

# Zorunlu paketleri dependencies.json'dan al
REQUIRED_PACKAGES=$(jq -r '.Zorunlu[] | .PackageName' data/dependencies.json)

if [[ -z "$REQUIRED_PACKAGES" ]]; then
    log "ERROR" "Zorunlu paketler dependencies.json'dan okunamadı!"
    exit 1
fi

# Her zorunlu paketi kur ve yapılandır
echo "$REQUIRED_PACKAGES" | while read -r package; do
    log "INFO" "📦 $package yükleniyor..."
    
    if ! yay -S --noconfirm "$package"; then
        log "ERROR" "$package kurulumu başarısız!"
        continue
    fi

    # Yapılandırma bilgisini appconfig.json'dan al
    config_info=$(jq -r --arg pkg "$package" '.[$pkg] | "\(.ConfigPath)|\(.SystemPath)"' data/appconfig.json)

    # Eğer config_info boş veya null ise, sonraki pakete geç
    if [[ -z "$config_info" || "$config_info" == "null|null" ]]; then
        log "INFO" "⚙️ $package için yapılandırma gerekmiyor, devam ediliyor..."
        continue
    fi

    config_path=$(echo "$config_info" | cut -d'|' -f1)
    system_path=$(echo "$config_info" | cut -d'|' -f2)

    if [[ -n "$config_path" && -n "$system_path" ]]; then
        log "INFO" "⚙️ $package yapılandırması uygulanıyor..."
        
        # Yapılandırma dizininin varlığını kontrol et
        if [[ ! -d "$config_path" ]]; then
            log "WARNING" "$config_path dizini bulunamadı, atlanıyor..."
            continue
        fi

        # ~ karakterini $HOME ile değiştir
        system_path="${system_path/#\~/$HOME}"

        # Hedef dizini oluştur
        if ! mkdir -p "$system_path"; then
            log "ERROR" "Hedef dizin oluşturulamadı: $system_path"
            continue
        fi

        # Dosyaları kopyala
        if ! cp -r "$config_path/." "$system_path/"; then
            log "ERROR" "Yapılandırma dosyaları kopyalanamadı: $package"
            continue
        fi

        log "SUCCESS" "✅ $package yapılandırması başarıyla uygulandı."
    else
        log "WARNING" "$package için geçerli yapılandırma yolları bulunamadı."
    fi

    # Paket kurulumu başarılı oldu
    log "SUCCESS" "✅ $package başarıyla kuruldu."
done

# Tüm zorunlu kurulumlar tamamlandı
log "SUCCESS" "✅ Tüm zorunlu kurulumlar tamamlandı."
