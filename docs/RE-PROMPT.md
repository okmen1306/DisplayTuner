# BetterDisplay RE Görevi (v2)

Bu dosyanın tamamını diğer AI'a ver.

````text
GÖREV: BetterDisplay 5.1.1 (macOS) uygulamasını tersine mühendislikle incele ve SADECE aşağıdaki
2 sorunun cevabını çıkar. Amaç, mantığı öğrenip kendi uygulamamda sıfırdan yazmak.

KURALLAR
- Kod kopyalama yok. Decompile edilmiş fonksiyonları uzun uzun yapıştırma; gerekirse en fazla 5-10
  satırlık kısa bir parça göster. Bana davranış, fonksiyon imzası ve parametre değerleri lazım.
- Lisans ve aktivasyon (Paddle.framework), Sentry ve Sparkle ile ilgilenme. Bunları tamamen atla.
- Bu 2 hedef dışında hiçbir şeyi analiz etme. İkisi de bitince dur.
- Emin olmadığın şeyi "TAHMİN" diye işaretle. Uydurma.

ORTAM
- MacBook Air M5 (Apple Silicon, arm64), macOS 27.2
- Binary: /Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay (universal). Sadece arm64 slice.
- Kurulu araçlar: Ghidra 12.2 (headless: /opt/homebrew/opt/ghidra/libexec/support/analyzeHeadless),
  radare2 6.2.6 (r2), dyld_info, otool, strings. Önce r2 ve dyld_info ile ucuz sorgular yap; Ghidra'yı
  sadece belirli fonksiyonları decompile etmek için kullan.
- Harici monitör: PR27R165QC, 2560x1440, USB-C dock üzerinden DP alt mode. DisplayLink yok.

══════════════════════════════════════════
ÖNCEDEN BULUNANLAR (bunları tekrar arama, buradan başla)

Import tablosunda (dyld_info -arch arm64 -imports) display ile ilgili olanlar:
  IOKit:      IOAVVideoInterfaceCreateWithService, IOAVVideoInterfaceGetLinkData,
              IOConnectCallMethod, IOConnectRelease, IORegistryEntrySetCFProperty,
              IOAVServiceCreateWithService, IOAVServiceReadI2C/WriteI2C, IOAVServiceCopyEDID,
              IOAVServiceSetVirtualEDIDMode, IOAVServiceGetLocation
  IOMobileFramebuffer: IOMobileFramebufferOpen, IOMobileFramebufferSetColorRemapMode
  CoreGraphics: CGSConfigureDisplayMode, CGSGetCurrentDisplayMode, CGSGetNumberOfDisplayModes,
              CGSGetDisplayModeDescriptionOfLength, CGSetDisplayTransferByTable,
              CGGetDisplayTransferByTable, CGShieldingWindowLevel, CGVirtualDisplay* (ObjC)
  SkyLight:   SLSDisplaySetActivePresetIndex, SLSDisplayGetActivePresetIndex, SLSDisplayCopyPreset,
              SLSDisplayGetPresetCount, SLSDisplaySetUnderscan, SLSDisplaySetHDRModeEnabled,
              SLSCopyDisplayInfoDictionary
  CoreDisplay: CoreDisplay_DisplayCreateInfoDictionary
  CoreBrightness: CBBlueLightClient, CBTrueToneClient (ObjC)
Binary'deki string'ler: "colorMode", "colorModeIsYCbCr", "colorModeMenuShowMixed",
  "colorModeMenuShowForcedHDR", "IOMFBMaxSrcPixels", "IOMFBBrightnessLevel", "IOMFBIndicatorNitsCap"

ELENENLER (BetterDisplay bunları KULLANMIYOR, vakit harcama):
  IOMobileFramebufferSetDigitalOutMode / GetDigitalOutMode / GetDigitalOutState (import'ta da string'de de yok)
  SLSDisplaySetColorMatrix, CGSSetDisplayColorMatrix (sistemde bile yok)

══════════════════════════════════════════
HEDEF 1: BAĞLANTI MODU (RGB/YCbCr, Full/Limited aralık, bit derinliği)
BetterDisplay CLI'da şu komut var:
  BetterDisplay set -name=PR27R165QC -connectionMode=bpc:8+range:full+encoding:rgb
Bu ayarı çalışma anında (yeniden başlatmadan) nasıl uyguluyor?

Güçlü adaylar (öncelik sırasıyla):
  (A) IOAVVideoInterfaceGetLinkData ile mevcut link bilgisi okunuyor, IOConnectCallMethod ile
      DCP/AV user client'ına doğrudan bir selector çağrılıyor.
  (B) IORegistryEntrySetCFProperty ile bir IOKit servisine özellik yazılıyor.
  (C) Renk modları display mode listesinin içinde: CGSGetDisplayModeDescriptionOfLength ile okunan
      mode struct'ında encoding/range/bpc alanları var ve CGSConfigureDisplayMode ile seçiliyor.

Cevaplanacaklar:
1a. Hangisi (A/B/C ya da başka)? "colorModeIsYCbCr" string'inin kullanıldığı yerden geriye doğru git.
1b. (A) ise: hangi servis sınıfına IOServiceOpen yapılıyor (tip numarası), selector numarası,
    input/output scalar ve struct boyutları, struct alanlarının anlamı.
1c. (B) ise: hangi servis (IOKit sınıf adı), özellik anahtarı (key) ve değerin formatı.
1d. (C) ise: mode description struct'ının boyutu ve encoding/range/bpc alanlarının offset'leri.
1e. Değer tablosu:
    | encoding (RGB / YCbCr444 / YCbCr422 / YCbCr420) | range (full / limited) | bpc (6/8/10/12) | → gönderilen değer(ler) |
1f. Mevcut modu okuma: IOAVVideoInterfaceGetLinkData çıktısının yapısı (alanlar ve offset'ler).
1g. Ön koşullar ve sıralama: yeniden yapılandırma, bekleme süresi, tekrar deneme, doğrulama.
1h. Desteklenen modların listesi nereden geliyor?

══════════════════════════════════════════
HEDEF 2: DOYGUNLUK / TON / CANLILIK / SEPYA
Sistemde renk matrisi API'si olmadığını biliyoruz. Bu ayarlar kanalları birbirine karıştırıyor.
BetterDisplay bunları nasıl uyguluyor?

Güçlü adaylar:
  (A) IOMobileFramebufferSetColorRemapMode (tek renk-ilgili IOMFB import'u)
  (B) Overlay pencere: CGShieldingWindowLevel import'u var. Ekranın üstüne Metal/CoreImage ile
      çizilen ve mouse olaylarını geçiren bir pencere olabilir. Metal, CoreImage veya
      ScreenCaptureKit import'larına da bak.
  (C) CGVirtualDisplay + yakalama ve shader ile streaming
  (D) Gamma tablosuyla (CGSetDisplayTransferByTable) yapılan bir yaklaşık hesap

Cevaplanacaklar:
2a. Mekanizma hangisi? Doygunluk slider'ının handler'ından başlayıp hangi API'ye ulaştığını izle.
2b. (A) ise: IOMobileFramebufferSetColorRemapMode'un imzası ve parametrelerinin anlamı. Matris veya
    LUT alıyor mu, formatı ne (boyut, float/fixed-point, sıra)? IOMobileFramebufferOpen ile
    framebuffer nasıl açılıyor (servis eşleştirme, harici ekranın seçimi)?
2c. (B) veya (C) ise: Pencere seviyesi, olayların geçmesi, kullanılan shader formülü (kısaca matematik).
2d. Doygunluk, ton ve sepya için kullanılan matematik (luma katsayıları, matris değerleri).
2e. Bu ayarlar gamma tablosu ayarlarıyla (kontrast, gama, renk sıcaklığı) nasıl birleştiriliyor?
    Hangi sırayla uygulanıyor?

══════════════════════════════════════════
YÖNTEM (token tasarrufu için ucuzdan pahalıya)
1. r2 ile string referansları: "colorModeIsYCbCr" ve "colorMode" string'lerine xref (axt) bul.
2. Yukarıdaki import'ların her birine xref bul; hangi fonksiyonların çağırdığını listele.
3. Sadece bu fonksiyonları Ghidra'da decompile et (headless, tek tek; tüm binary'yi analiz etme).
4. Hedef 1 için kara kutu doğrulaması önerebilirsin: CLI ile modu değiştir, ardından
   IOAVVideoInterfaceGetLinkData veya ioreg çıktısındaki değişikliği göster.

ÇIKTI FORMATI (sadece bu, başka bir şey yazma)
# BetterDisplay RE Spec
## Hedef 1: Bağlantı Modu
- Mekanizma (A/B/C/başka):
- Fonksiyonlar, imzalar, selector'lar veya anahtarlar:
- Servisi bulma:
- Değer tablosu:
- Okuma yapısı:
- Çağrı sırası ve ön koşullar:
- Belirsizlikler (TAHMİN olanlar):
## Hedef 2: Doygunluk / Ton
- Mekanizma:
- API, imza ve veri formatı (veya overlay detayları):
- Matematik:
- Gamma ile birleştirme sırası:
- Belirsizlikler:
````
