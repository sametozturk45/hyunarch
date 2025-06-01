# Hyprland + CachyOS Otomatik Kurulum

Bu betik, CachyOS üzerinde Hyprland ortamını tam donanımlı şekilde kurar. Tüm yapılandırmalar `~/.config/hypr` altına yerleştirilir ve sistem bileşenleri (bluetooth, pipewire, vs) hazır hale getirilir.

## Proje Yapısı

```
.
├── scripts/
│   ├── helpers.sh                           # Yardımcı fonksiyonlar
│   ├── hyprland-startup-configuration.sh     # Hyprland otomatik başlatma yapılandırması
│   └── undo-hyprland-startup-configuration.sh # Hyprland otomatik başlatma yapılandırmasını geri alma
├── configs/                                  # Uygulama yapılandırma dosyaları
├── data/                                     # Veri dosyaları
├── install.sh                               # Ana kurulum betiği
├── menu.sh                                  # Kullanıcı arayüzü menüsü
├── required.sh                              # Zorunlu bağımlılıkların kurulumu
├── dependencies.json                        # Uygulama bağımlılıkları ve kategorileri
└── appconfig.json                           # Uygulama yapılandırma haritası
```

## İçerik
- Hyprland pencere yöneticisi
- Kitty terminali
- Dolphin dosya yöneticisi
- Brave tarayıcı (Flatpak)
- Bitwarden şifre yöneticisi (Flatpak)
- Spotify müzik çalar (Flatpak)
- Vesktop Discord istemcisi (Flatpak + plugin desteği)
- Waybar, dunst, blueman gibi yardımcı uygulamalar
- Xbox Gamepad ve Bluetooth kulaklık desteği

## Kurulum
```bash
git clone https://github.com/kullanici/benim-hyprland-konfig.git
cd benim-hyprland-konfig
chmod +x install.sh
./install.sh
```

## Yapılandırma Dosyaları

### dependencies.json
Uygulamaların kategorilere göre gruplandırıldığı ve bağımlılıkların tanımlandığı JSON dosyası. Her uygulama için:
- Paket adı
- Görünen ad
- Açıklama
- Yapılandırma yolu
- Sistem yolu

### appconfig.json
Uygulamaların yapılandırma dosyalarının haritasını içeren JSON dosyası. Her uygulama için:
- Yapılandırma dosyalarının kaynak konumu
- Hedef sistem konumu
- Özel yapılandırma seçenekleri

## Son Adımlar
- Oturum yöneticiniz yoksa `.zprofile` içine `exec Hyprland` satırını ekleyin.
- Bluetooth bağlantılar için `blueman-applet` ve `pavucontrol` kullanın.
- Giriş yaptıktan sonra Bitwarden ve Vesktop otomatik başlayacaktır.

## Sorun Giderme

### Bluetooth Sorunları
1. `bluetoothctl` ile cihazları tarayın
2. `blueman-applet` ile cihazları eşleştirin
3. `pavucontrol` ile ses çıkışını kontrol edin

### MIME Türleri
MIME türleri sorunları için:
1. `xdg-mime default` komutunu kullanın
2. `~/.config/mimeapps.list` dosyasını düzenleyin
3. `update-desktop-database` komutunu çalıştırın

### Hyprland Başlatma Sorunları
1. `hyprland-startup-configuration.sh` betiğini çalıştırın
2. `.zprofile` dosyasını kontrol edin
3. Gerekirse `undo-hyprland-startup-configuration.sh` ile yapılandırmayı geri alın

## Notlar
- Flatpak uygulamaları için `flatpak override --user --filesystem=home` gibi izin ayarları gerekebilir.
- Wayland uyumlu uygulamalar kullanılmalı (örneğin Firefox yerine Brave).
- Sistem güncellemelerinden sonra yapılandırma dosyalarını kontrol edin.

---
Bu yapılandırma `stabilite`, `otomasyon` ve `minimum müdahale` ilkeleriyle hazırlanmıştır.
