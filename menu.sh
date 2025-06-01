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

# Yardımcı betiklerin varlığını kontrol et
if [[ ! -f "./scripts/helpers.sh" ]]; then
    log "ERROR" "helpers.sh bulunamadı!"
    exit 1
fi

source ./scripts/helpers.sh

# Sabit değişkenler
DEPENDENCIES_FILE="dependencies.json"
SELECTED_APPS=()

# Gerekli komutların varlığını kontrol et
for cmd in jq gum yay; do
    if ! command -v "$cmd" &> /dev/null; then
        log "ERROR" "$cmd komutu bulunamadı!"
        exit 1
    fi
done

# dependencies.json dosyasının varlığını kontrol et
if [[ ! -f "$DEPENDENCIES_FILE" ]]; then
    log "ERROR" "$DEPENDENCIES_FILE dosyası bulunamadı!"
    exit 1
fi

get_config_info() {
    local pkg="$1"
    if ! jq -r --arg pkg "$pkg" '
        to_entries[] | .value[] | select(.PackageName == $pkg) | 
        "\(.ConfigPath)|\(.SystemPath)"' "$DEPENDENCIES_FILE"; then
        log "ERROR" "Yapılandırma bilgisi alınamadı: $pkg"
        return 1
    fi
}

select_category() {
    local category
    if ! category=$(jq -r 'keys[] | select(. != "Zorunlu")' "$DEPENDENCIES_FILE" | gum choose --no-limit --header="🧩 Bir kategori seçin"); then
        log "ERROR" "Kategori seçimi başarısız!"
        return 1
    fi
    [[ -z "$category" ]] && return
    select_apps "$category"
}

select_apps() {
    local category="$1"
    local selected
    if ! selected=$(jq -r --arg cat "$category" '.[$cat][] | "\(.PackageName) | \(.DisplayName): \(.Description)"' "$DEPENDENCIES_FILE" | gum choose --no-limit --header="📦 $category kategorisinden uygulama seçin"); then
        log "ERROR" "Uygulama seçimi başarısız!"
        return 1
    fi

    while read -r item; do
        [[ -z "$item" ]] && continue
        app=$(echo "$item" | cut -d'|' -f1 | xargs)
        SELECTED_APPS+=("$app")
        log "INFO" "✅ $app seçildi"
    done <<< "$selected"
}

install_selected() {
    if [[ ${#SELECTED_APPS[@]} -eq 0 ]]; then
        log "WARNING" "Hiç uygulama seçilmedi!"
        return 1
    fi

    log "INFO" "🚀 Seçilen uygulamalar yükleniyor..."
    for app in "${SELECTED_APPS[@]}"; do
        log "INFO" "📦 $app yükleniyor..."
        
        if ! yay -S --noconfirm "$app"; then
            log "ERROR" "$app kurulumu başarısız!"
            continue
        fi

        config_info=$(get_config_info "$app")
        if [[ $? -ne 0 ]]; then
            continue
        fi

        config_path=$(echo "$config_info" | cut -d'|' -f1)
        system_path=$(echo "$config_info" | cut -d'|' -f2)

        if [[ "$config_path" != "null" && "$system_path" != "null" ]]; then
            log "INFO" "⚙️  Config uygulanıyor: $config_path → $system_path"
            
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
}

# Ana menü
show_menu() {
    clear
    log "INFO" "📦 Aşağıdaki menüyü kullanarak sisteminize yüklemek isteyeceğiniz uygulamaları seçebilir ve sisteminizi özelleştirebilirsiniz."
    echo
    log "INFO" "🛠️  Bu paketler sistemin stabil çalışması için gereklidir:"
    if ! jq -r '.["Zorunlu"][] | "- \(.DisplayName): \(.Description)"' "$DEPENDENCIES_FILE"; then
        log "ERROR" "Zorunlu paketler listelenemedi!"
        exit 1
    fi
    echo
    log "INFO" "⏬ Devam etmek için seçim menüsüne geçiliyor..."
    sleep 2

    while true; do
        if ! action=$(gum choose "📁 Kategori Seç" "🚀 Kurulumu Başlat" "❌ Çık"); then
            log "ERROR" "Menü seçimi başarısız!"
            exit 1
        fi

        case "$action" in
            "📁 Kategori Seç") 
                if ! select_category; then
                    log "ERROR" "Kategori seçimi başarısız!"
                fi
                ;;
            "🚀 Kurulumu Başlat") 
                if ! install_selected; then
                    log "ERROR" "Kurulum başarısız!"
                else
                    log "SUCCESS" "✅ Kurulum tamamlandı!"
                fi
                break 
                ;;
            "❌ Çık") 
                log "INFO" "👋 Program sonlandırılıyor..."
                exit 0 
                ;;
        esac
    done
}

# Ana programı başlat
show_menu


