#!/bin/bash

BACKUP_DIR="$HOME/.hypr-autostart-backup"
LOG_FILE="$HOME/autostart-hyprland.log"

echo "⏪ Geri alma işlemi başlatılıyor... ($(date))" | tee -a "$LOG_FILE"

if [ -f "$BACKUP_DIR/bash_profile.bak" ]; then
  cp "$BACKUP_DIR/bash_profile.bak" "$HOME/.bash_profile"
  echo "🔁 ~/.bash_profile geri yüklendi." | tee -a "$LOG_FILE"
fi

if [ -f "$BACKUP_DIR/override.conf.bak" ]; then
  sudo cp "$BACKUP_DIR/override.conf.bak" /etc/systemd/system/getty@tty1.service.d/override.conf
  echo "🔁 systemd override.conf geri yüklendi." | tee -a "$LOG_FILE"
fi

sudo systemctl daemon-reexec
sudo systemctl restart getty@tty1

echo "✅ Geri alma tamamlandı." | tee -a "$LOG_FILE"
