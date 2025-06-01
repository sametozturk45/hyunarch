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
    if ! git clone https://aur.archlinux.org/yay.git /tmp/yay; then
        log "ERROR" "yay kaynak kodu indirilemedi!"
        exit 1
    fi
    if ! (cd /tmp/yay && makepkg -si --noconfirm); then
        log "ERROR" "yay kurulumu başarısız!"
        exit 1
    fi
    log "SUCCESS" "✅ yay başarıyla kuruldu."
else
    log "INFO" "✅ yay zaten yüklü."
fi

# gum kontrolü ve kurulumu
if ! command -v gum &> /dev/null; then
    log "INFO" "📦 gum yüklü değil. Kuruluyor..."
    if ! command -v go &> /dev/null; then
        log "INFO" "📦 Go yüklü değil. Kuruluyor..."
        if ! sudo pacman -S --noconfirm go; then
            log "ERROR" "Go kurulumu başarısız!"
            exit 1
        fi
    fi
    
    # Go kurulumu için gerekli ortam değişkenlerini ayarla
    export GOPATH="$HOME/go"
    export PATH="$GOPATH/bin:$PATH"
    
    if ! go install github.com/charmbracelet/gum@latest; then
        log "ERROR" "gum kurulumu başarısız!"
        exit 1
    fi
    
    # Shell yapılandırma dosyalarına PATH ekle
    for shell_rc in ~/.bashrc ~/.zshrc ~/.config/fish/config.fish; do
        if [[ -f "$shell_rc" ]]; then
            if ! grep -q "export GOPATH=\"\$HOME/go\"" "$shell_rc"; then
                echo 'export GOPATH="$HOME/go"' >> "$shell_rc"
            fi
            if ! grep -q "export PATH=\"\$GOPATH/bin:\$PATH\"" "$shell_rc"; then
                echo 'export PATH="$GOPATH/bin:$PATH"' >> "$shell_rc"
            fi
        fi
    done
    
    # Mevcut oturum için PATH'i güncelle
    export PATH="$GOPATH/bin:$PATH"
    
    # Shell'i yeniden yükle
    if [[ -n "$SHELL" ]]; then
        case "$SHELL" in
            */bash) source ~/.bashrc ;;
            */zsh) source ~/.zshrc ;;
            */fish) source ~/.config/fish/config.fish ;;
        esac
    fi
    
    log "SUCCESS" "✅ gum başarıyla kuruldu."
    log "INFO" "Lütfen terminal oturumunuzu yeniden başlatın veya 'source ~/.bashrc' (bash için) veya 'source ~/.zshrc' (zsh için) komutunu çalıştırın."
else
    log "INFO" "✅ gum zaten yüklü."
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