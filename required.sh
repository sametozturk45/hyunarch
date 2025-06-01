#!/bin/bash

# Hata yönetimi ve güvenlik ayarları
set -euo pipefail
IFS=$'\n\t'

# Renk tanımlamaları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# group-map.json dosyasının varlığını kontrol et
if [[ ! -f "group-map.json" ]]; then
    log "ERROR" "group-map.json dosyası bulunamadı!"
    exit 1
fi

log "INFO" "📌 Zorunlu bağımlılıklar kuruluyor..."

REQUIRED_APPS=(
    "hyprland"
    "xdg-desktop-portal-hyprland"
    "xdg-desktop-portal"
    "xdg-utils"
    "polkit-kde-agent"
    "network-manager-applet"
    "waybar"
)

for app in "${REQUIRED_APPS[@]}"; do
    log "INFO" "📦 $app yükleniyor..."
    
    if ! yay -S --noconfirm "$app"; then
        log "ERROR" "$app kurulumu başarısız!"
        exit 1
    fi

    # jq komutunun varlığını kontrol et
    if ! command -v jq &> /dev/null; then
        log "ERROR" "jq komutu bulunamadı!"
        exit 1
    fi

    config_info=$(jq -r --arg pkg "$app" '
        to_entries[] | .value[] | select(.PackageName == $pkg) |
        "\(.ConfigPath)|\(.SystemPath)"' group-map.json)

    if [[ $? -ne 0 ]]; then
        log "ERROR" "Yapılandırma bilgisi alınamadı: $app"
        continue
    fi

    config_path=$(echo "$config_info" | cut -d'|' -f1)
    system_path=$(echo "$config_info" | cut -d'|' -f2)

    if [[ "$config_path" != "null" && "$system_path" != "null" ]]; then
        log "INFO" "⚙️  $app yapılandırması uygulanıyor..."
        
        # Yapılandırma dizininin varlığını kontrol et
        if [[ ! -d "$config_path" ]]; then
            log "WARNING" "$config_path dizini bulunamadı, atlanıyor..."
            continue
        }

        # Hedef dizini oluştur
        if ! mkdir -p "$(eval echo $system_path)"; then
            log "ERROR" "Hedef dizin oluşturulamadı: $system_path"
            continue
        }

        # Dosyaları kopyala
        if ! cp -r "$config_path/." "$(eval echo $system_path)"; then
            log "ERROR" "Yapılandırma dosyaları kopyalanamadı: $app"
            continue
        }

        log "SUCCESS" "✅ $app yapılandırması başarıyla uygulandı."
    fi
done

log "SUCCESS" "✅ Tüm zorunlu bağımlılıklar başarıyla kuruldu ve yapılandırıldı."
