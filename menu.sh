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

# Log fonksiyonu
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] [${level}] ${message}"
}

# Ana menü fonksiyonu
show_menu() {
    clear
    echo "\nAna Menü:"
    echo "1. 📁 Kategori Seç"
    echo "2. 🚀 Kurulumu Başlat"
    echo "0. ❌ Çıkış"

    read -p "Lütfen bir seçenek girin (0-2): " action

    case "$action" in
        0) log "INFO" "👋 Program sonlandırılıyor..."; exit 0 ;;
        1) select_category ;;
        2) install_selected ;;
        * ) log "WARNING" "Geçersiz seçenek! Lütfen 0-2 arasında bir sayı girin." ;;
    esac
done
}

# Kategori seçimi fonksiyonu
select_category() {
    clear
    echo "\nKategori Seçimi:"

    local categories=$(jq -r 'keys[] | select(. != \"Zorunlu\")' "$DEPENDENCIES_FILE")
    local i=1
    local category_array=()
    while IFS= read -r category; do
        echo "$i. 📁 $category"
        category_array+=("$category")
        ((i++))
    done <<< "$categories"
    echo "0. 🔙 Ana Menüye Dön"

    read -p "Lütfen bir kategori seçin (0-$((i-1))): " category_choice

    case "$category_choice" in
        0) show_menu ;;
        [1-9]*)
            local selected_category=${category_array[$(($category_choice - 1))]}
            if [[ -z "$selected_category" ]]; then
                log "WARNING" "Geçersiz kategori seçimi!"
            else
                select_apps "$selected_category"
            fi
            ;;
        *)
            log "WARNING" "Geçersiz seçenek! Lütfen 0-$((i-1)) arasında bir sayı girin.";;
    esac
}

# Uygulama seçimi fonksiyonu
select_apps() {
    clear
    local category="$1"
    echo "\nUygulama Seçimi ($category):"

    local apps_string=$(jq -r --arg cat "$category" '.[$cat][] | "\(.PackageName) | \(.DisplayName): \(.Description)"' "$DEPENDENCIES_FILE")
    if [[ -z "$apps_string" ]]; then
        log "WARNING" "$category kategorisi bulunamadı veya uygulama yok!"
        show_menu
        return
    fi

    local i=1
    local app_list=()
    while IFS= read -r app; do
        local app_name=$(echo "$app" | cut -d'|' -f2)
        echo "$i. 📦 $app_name"
        app_list+=("$app")
        ((i++))
    done <<< "$apps_string"
    echo "0. ✅ Seçimi Tamamla ve Ana Menüye Dön"

    read -p "Lütfen uygulamaları seçin (0-$((i-1)), virgülle ayırarak): " app_choices

    # Eğer seçim yapılmadıysa ana menüye dön
    if [[ -z "$app_choices" ]]; then
        show_menu
        return
    fi

    # Virgülle ayrılmış seçimleri işle
    local IFS=","
    local app_array=($app_choices)
    unset IFS

    for app_choice in "${app_array[@]}"; do
        app_choice=$(echo "$app_choice" | tr -d ' ' ) # Boşlukları temizle
        if [[ ! "$app_choice" =~ ^[0-9]+$ ]]; then
            log "WARNING" "Geçersiz uygulama seçimi: $app_choice"
            continue
        fi

        if [[ "$app_choice" -eq 0 ]]; then
            show_menu
            return
        elif [[ "$app_choice" -gt 0 && "$app_choice" -le $((i-1)) ]]; then
            local selected_app=${app_list[$(($app_choice - 1))]}
            local app_name=$(echo "$selected_app" | cut -d'|' -f1)
            SELECTED_APPS+=("$app_name")
            log "INFO" "✅ $app_name seçildi"
        else
            log "WARNING" "Geçersiz uygulama seçimi: $app_choice"
        fi
    done

    show_menu
}

# Kurulum fonksiyonu
install_selected() {
    if [[ ${#SELECTED_APPS[@]} -eq 0 ]]; then
        log "WARNING" "Hiç uygulama seçilmedi!"
        show_menu
        return
    fi

    echo "\nSeçilen Uygulamalar Kuruluyor:"
    for app in "${SELECTED_APPS[@]}"; do
        echo "- $app"
    done

    # Burada kurulum işlemleri yapılacak
    echo "\nKurulum tamamlandı!"
    SELECTED_APPS=()
    show_menu
}

# Ana menüyü başlat
show_menu
