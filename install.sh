#!/bin/bash

# Hata yönetimi ve güvenlik ayarları
set -euo pipefail
IFS=$'\n\t'

# Scriptin bulunduğu dizine git
cd "$(dirname "$(realpath "$0")")"

export PATH="/usr/local/sbin:/usr/local/bin:/usr/bin:$PATH"

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
for script in "./scripts/helpers.sh" "./menu.sh" "./scripts/hyprland-startup-configuration.sh"; do
    if [[ ! -f "$script" ]]; then
        log "ERROR" "${script} bulunamadı!"
        exit 1
    fi
done

# yay kontrolü ve kurulumu
if ! command -v yay &> /dev/null; then
    log "INFO" "📦 yay yüklü değil. Kuruluyor..."
    sudo pacman -S --needed --noconfirm git base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd -
    # YAY'ın kurulduğu dizini PATH'e ekle
    export PATH="$HOME/.local/bin:$PATH"
    if ! command -v yay &> /dev/null; then
        log "ERROR" "yay kurulumu başarısız veya PATH'e eklenemedi! Lütfen ~/.local/bin dizinini PATH'e ekleyin veya yeni bir terminal açın."
        exit 1
    fi
    log "SUCCESS" "✅ yay başarıyla kuruldu."
else
    log "INFO" "✅ yay zaten yüklü."
fi
# Gum kontrolü ve kurulumu
if ! command -v gum &> /dev/null; then
    log "INFO" "📦 gum yüklü değil. Binary olarak indiriliyor..."
    GUM_VERSION="0.14.0"
    ARCH=$(uname -m)
    if [[ $ARCH == "x86_64" ]]; then
        ARCH="x86_64"
    elif [[ $ARCH == "aarch64" ]]; then
        ARCH="arm64"
    else
        log "ERROR" "Bu mimari için otomatik gum kurulumu desteklenmiyor: $ARCH"
        exit 1
    fi

    curl -L -o /tmp/gum.tar.gz "https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_Linux_${ARCH}.tar.gz"
    tar -xzf /tmp/gum.tar.gz -C /tmp

    # Çıkan binary'nin tam yolunu bul
    if ! GUM_PATH=$(sudo find /tmp -type f -name gum -perm -u+x 2>/dev/null | head -n 1); then
        log "ERROR" "Gum pathi bulunamadı."
        exit 1
    fi

    if [[ -z "$GUM_PATH" ]]; then
        log "ERROR" "gum binary'si arşivden çıkarılamadı!"
        exit 1
    fi

    if ! sudo mv "$GUM_PATH" /usr/bin/gum; then
        log "ERROR" "gum binary'si /usr/bin dizinine taşınamadı! Yetki hatası."
        exit 1
    fi

    if ! sudo chmod +x /usr/bin/gum; then
        log "ERROR" "gum binary'sine çalıştırma izni verilemedi! Yetki hatası."
        exit 1
    fi

    if ! sudo rm /tmp/gum.tar.gz; then
        log "ERROR" "gum arşivi silinemedi!."
        exit 1
    fi
    
    log "SUCCESS" "✅ gum başarıyla kuruldu (binary olarak)."
else
    log "INFO" "✅ gum zaten yüklü."
fi

# Fish shell için PATH ayarı
if grep -q fish <<< "$SHELL"; then
    chmod +x scripts/setup_fish_path.fish
    fish scripts/setup_fish_path.fish
fi

# Bash/Zsh için PATH ayarı
if grep -qE 'bash|zsh' <<< "$SHELL"; then
    for shell_rc in ~/.bashrc ~/.zshrc; do
        if [[ -f "$shell_rc" ]]; then
            if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$shell_rc"; then
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_rc"
            fi
            if ! grep -q 'export PATH="$HOME/go/bin:$PATH"' "$shell_rc"; then
                echo 'export PATH="$HOME/go/bin:$PATH"' >> "$shell_rc"
            fi
        fi
    done
    export PATH="$HOME/.local/bin:$HOME/go/bin:$PATH"
    log "INFO" "Bash/Zsh için PATH ayarlandı."
fi

# Zorunlu kurulumları yap
if [[ ! -x "./required.sh" ]]; then
    chmod +x "./required.sh"
fi

# Zorunlu kurulumları çalıştır
bash ./required.sh || { 
    log "ERROR" "Zorunlu kurulumlar başarısız!"
    exit 1
}

# Konfigürasyon dosyalarını kopyala
copy_configs() {
    log "INFO" "📁 Seçili uygulamaların konfigürasyon dosyaları kopyalanıyor..."
    
    # AppConfig dosyasını oku
    local appconfig
    appconfig=$(cat data/appconfig.json)
    
    # SELECTED_PACKAGES dizisinin varlığını kontrol et
    if [[ -z "${SELECTED_PACKAGES+x}" ]]; then
        log "ERROR" "SELECTED_PACKAGES değişkeni tanımlı değil!"
        return 1
    fi

    # Debug için array içeriğini göster
    log "DEBUG" "Kopyalanacak paketler: ${SELECTED_PACKAGES[*]}"
    
    for package in "${SELECTED_PACKAGES[@]}"; do
        # Paketi appconfig.json'da ara
        if echo "$appconfig" | jq -e --arg pkg "$package" '.[$pkg]' >/dev/null 2>&1; then
            local config_path
            local system_path
            
            # ConfigPath ve SystemPath değerlerini al
            config_path=$(echo "$appconfig" | jq -r --arg pkg "$package" '.[$pkg].ConfigPath')
            system_path=$(echo "$appconfig" | jq -r --arg pkg "$package" '.[$pkg].SystemPath')
            
            # ~ karakterini $HOME ile değiştir
            system_path="${system_path/#\~/$HOME}"
            
            if [[ -d "$config_path" ]]; then
                log "INFO" "📦 $package için konfigürasyon dosyaları kopyalanıyor..."
                mkdir -p "$system_path"
                cp -r "$config_path"/* "$system_path/"
                chmod -R u+rw "$system_path"
                log "INFO" "✅ $package konfigürasyonları kopyalandı"
            fi
        fi
    done
    
    log "INFO" "✅ Seçili uygulamaların konfigürasyon dosyaları başarıyla kopyalandı"
}

# Yardımcı betikleri yükle
source ./scripts/helpers.sh

log "INFO" "🔧 Yardımcı araçlar kontrol ediliyor..."

# Menü ve kullanıcı seçimi
if [[ ! -x "menu.sh" ]]; then
    chmod +x menu.sh
fi

# Menü scriptini çalıştır
source ./menu.sh
show_menu

# Debug: Seçili paketleri kontrol et
if [[ -z "${SELECTED_PACKAGES+x}" ]]; then
    log "ERROR" "SELECTED_PACKAGES değişkeni tanımlı değil!"
    exit 1
fi

log "INFO" "Dizi içeriği kontrol ediliyor..."
declare -p SELECTED_PACKAGES || {
    log "ERROR" "SELECTED_PACKAGES dizi olarak tanımlı değil!"
    exit 1
}

# Seçili paketleri göster
log "INFO" "Seçili paketler:"
for package in "${SELECTED_PACKAGES[@]}"; do
    log "INFO" "- $package"
done

# Config dosyalarını kopyala
copy_configs || handle_error $LINENO $?

# Config dosyaları kopyalandıktan sonra Hyprland otomatik başlatma
if [[ ! -x "scripts/hyprland-startup-configuration.sh" ]]; then
    chmod +x scripts/hyprland-startup-configuration.sh
fi

if ! ./scripts/hyprland-startup-configuration.sh; then
    log "ERROR" "Hyprland otomatik başlatma yapılandırması başarısız!"
    exit 1
fi

log "SUCCESS" "✅ Kurulum tamamlandı! Sisteminiz artık özelleştirilmiş durumda."
log "INFO" "Lütfen stabil çalışması için gerekli olan uygulamaları kontrol edin ve sisteminizi yeniden başlatın."