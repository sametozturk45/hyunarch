# Proje Genel Bakış

## Amaç

Bu projenin amacı, Linux üzerinde çalışan, kullanıcıyı adım adım yönlendiren ve seçilen distro ile masaüstü ortamına göre özelleştirilmiş kurulum akışları sunan modüler bir Bash script sistemi oluşturmaktır.

## Hedefler

- Kullanıcıdan distro bilgisini almak
- Geçerli paket yöneticilerini göstermek
- İlk büyük seçim olarak masaüstü ortamını almak
- Masaüstü ortamına göre ilgili seçenekleri filtrelemek
- Preset kurulumları desteklemek
- Tema kurulum scriptlerini tetiklemek
- Kategorili uygulama kurulumlarını desteklemek
- Her uygulama için `Hyunarch config ile kur` veya `temiz kurulum` seçeneklerini sunmak
- Seçimlerden bir execution plan üretmek
- Doğrulanmış scriptleri çalıştırmak

## Neden Bash?

Bash bu proje için doğal bir tercih çünkü:
- Linux üzerinde yerel çalışır
- Paket yöneticileriyle doğrudan konuşur
- Dosya sistemi, servis, symlink ve config işlemleri için uygundur
- Ek çalışma zamanı bağımlılığı getirmez

## Neden Config-Driven Tasarım?

Seçenekler zamanla büyüyeceği için veri ile mantığı ayırmak gerekir.

Bu yüzden:
- distro tanımları
- paket yöneticileri
- masaüstü ortamı seçenekleri
- presetler
- temalar
- uygulama kategorileri
- Hyunarch script eşleşmeleri

kod içine gömülmek yerine YAML/JSON içinde tutulmalıdır.
