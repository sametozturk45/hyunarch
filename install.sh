#!/bin/bash

# Hata yönetimi ve güvenlik ayarları
set -euo pipefail
IFS=$'\n\t'
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

# Yardımcı betikleri yükle
source ./scripts/helpers.sh
source ./menu.sh

log "INFO" "🔧 Yardımcı araçlar kontrol ediliyor..."

# yay kontrolü ve kurulumu
if ! command -v yay &> /dev/null; then
    log "INFO" "📦 yay yüklü değil. Kuruluyor..."
    sudo pacman -S --needed --noconfirm git base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd -
    log "SUCCESS" "✅ yay başarıyla kuruldu."
else
    log "INFO" "✅ yay zaten yüklü."
fi

# gum kontrolü ve kurulumu
if ! command -v gum &> /dev/null; then
    log "INFO" "📦 gum yüklü değil. Kuruluyor..."
    yay -S --noconfirm gum-bin || yay -S --noconfirm gum
    export PATH="/usr/bin:$PATH"
    if ! command -v gum &> /dev/null; then
        log "ERROR" "gum kurulumu başarısız veya PATH'e eklenemedi!"
        exit 1
    fi
    log "SUCCESS" "✅ gum başarıyla kuruldu."
else
    log "INFO" "✅ gum zaten yüklü."
fi

# Fish shell için PATH ayarı
if grep -q fish <<< "$SHELL"; then
    if ! string match -q -- "$HOME/.local/bin" $PATH; 
        set -Ux PATH $HOME/.local/bin $PATH
    end
    if ! string match -q -- "/usr/local/bin" $PATH;
        set -Ux PATH /usr/local/bin $PATH
    end
    if ! string match -q -- "/usr/bin" $PATH;
        set -Ux PATH /usr/bin $PATH
    end
    if ! string match -q -- "$HOME/go/bin" $PATH;
        set -Ux PATH $HOME/go/bin $PATH
    end
    log "INFO" "Fish shell için PATH ayarlandı."
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
if [[ ! -x "scripts/required.sh" ]]; then
    chmod +x scripts/required.sh
fi

if ! ./scripts/required.sh; then
    log "ERROR" "Zorunlu kurulumlar başarısız!"
    exit 1
fi

# Menü ve kullanıcı seçimi
if [[ ! -x "menu.sh" ]]; then
    chmod +x menu.sh
fi

if ! ./menu.sh; then
    log "ERROR" "Menü işlemi başarısız!"
    exit 1
fi

# Hyprland otomatik başlatma
if [[ ! -x "scripts/hyprland-startup-configuration.sh" ]]; then
    chmod +x scripts/hyprland-startup-configuration.sh
fi

if ! ./scripts/hyprland-startup-configuration.sh; then
    log "ERROR" "Hyprland otomatik başlatma yapılandırması başarısız!"
    exit 1
fi

log "SUCCESS" "✅ Kurulum tamamlandı! Sisteminiz artık özelleştirilmiş durumda."
log "INFO" "Lütfen stabil çalışması için gerekli olan uygulamaları kontrol edin ve sisteminizi yeniden başlatın."