#!/bin/bash

LOG_FILE="$HOME/autostart-hyprland.log"
BACKUP_DIR="$HOME/.hypr-autostart-backup"
BASH_PROFILE="$HOME/.bash_profile"
OVERRIDE_FILE="/etc/systemd/system/getty@tty1.service.d/override.conf"

echo "⏳ İşlem başlatılıyor... ($(date))" | tee -a "$LOG_FILE"

# Yedekleme
mkdir -p "$BACKUP_DIR"

if [ -f "$BASH_PROFILE" ]; then
  cp "$BASH_PROFILE" "$BACKUP_DIR/bash_profile.bak"
  echo "📦 ~/.bash_profile yedeklendi." | tee -a "$LOG_FILE"
fi

if [ -f "$OVERRIDE_FILE" ]; then
  sudo cp "$OVERRIDE_FILE" "$BACKUP_DIR/override.conf.bak"
  echo "📦 systemd override.conf yedeklendi." | tee -a "$LOG_FILE"
fi

# systemd override oluştur
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d

sudo tee "$OVERRIDE_FILE" >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USER --noclear %I \$TERM
EOF

echo "🛠️ systemd override ayarlandı." | tee -a "$LOG_FILE"

# ~/.bash_profile'a Hyprland autostart ekle
if ! grep -q 'exec Hyprland' "$BASH_PROFILE"; then
  echo '' >> "$BASH_PROFILE"
  echo 'if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then' >> "$BASH_PROFILE"
  echo '  exec Hyprland' >> "$BASH_PROFILE"
  echo 'fi' >> "$BASH_PROFILE"
  echo "✅ Hyprland autostart ~/.bash_profile'a eklendi." | tee -a "$LOG_FILE"
else
  echo "ℹ️ Hyprland autostart zaten mevcut." | tee -a "$LOG_FILE"
fi

# systemd yeniden başlat
sudo systemctl daemon-reexec
sudo systemctl restart getty@tty1

echo "✅ Kurulum tamamlandı. Hyprland artık tty1'de otomatik başlatılacak." | tee -a "$LOG_FILE"
