#!/usr/bin/env fish

set LOG_FILE "$HOME/autostart-hyprland.log"
set BACKUP_DIR "$HOME/.hypr-autostart-backup"
set FISH_CONFIG "$HOME/.config/fish/config.fish"
set OVERRIDE_FILE "/etc/systemd/system/getty@tty1.service.d/override.conf"

echo "⏳ İşlem başlatılıyor... ($(date))" | tee -a "$LOG_FILE"

# Yedekleme
mkdir -p "$BACKUP_DIR"

if test -f "$FISH_CONFIG"
    cp "$FISH_CONFIG" "$BACKUP_DIR/config.fish.bak"
    echo "📦 config.fish yedeklendi." | tee -a "$LOG_FILE"
end

if test -f "$OVERRIDE_FILE"
    sudo cp "$OVERRIDE_FILE" "$BACKUP_DIR/override.conf.bak"
    echo "📦 systemd override.conf yedeklendi." | tee -a "$LOG_FILE"
end

# systemd override oluştur
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d

echo "[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USER --noclear %I \$TERM" | sudo tee "$OVERRIDE_FILE" >/dev/null

echo "🛠️ systemd override ayarlandı." | tee -a "$LOG_FILE"

# config.fish'e Hyprland autostart ekle
if not grep -q 'exec Hyprland' "$FISH_CONFIG"
    mkdir -p (dirname "$FISH_CONFIG")
    echo '' >> "$FISH_CONFIG"
    echo 'if test -z "$DISPLAY" -a (tty) = "/dev/tty1"' >> "$FISH_CONFIG"
    echo '    exec Hyprland' >> "$FISH_CONFIG"
    echo 'end' >> "$FISH_CONFIG"
    echo "✅ Hyprland autostart config.fish'e eklendi." | tee -a "$LOG_FILE"
else
    echo "ℹ️ Hyprland autostart zaten mevcut." | tee -a "$LOG_FILE"
end

# systemd yeniden başlat
sudo systemctl daemon-reexec
sudo systemctl restart getty@tty1

echo "✅ Kurulum tamamlandı. Hyprland artık tty1'de otomatik başlatılacak." | tee -a "$LOG_FILE"
