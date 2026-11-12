# DisplayTuner — Uygulama Spesifikasyonu

> Masaüstü kurulumunu tek bir yerden yöneten, macOS'a ait gibi görünen kişisel bir menü bar uygulaması.
> BetterDisplay, LinearMouse, Razer Synapse, ASUS Armoury Crate, Pusat yazılımı ve eski `dockapps.sh` script'inin yerini alır.

| | |
|---|---|
| **Sürüm** | Spec v1.0 — 11 Kasım 2026 |
| **Hedef sistem** | MacBook Air M5, macOS 27.2 (Apple Silicon) |
| **Dağıtım** | Kişisel kullanım, yerel imza, sandbox yok, App Store yok |
| **Durum** | Protokoller test edildi, kod yazılmadı |

---

## İçindekiler
1. [Amaç ve Kapsam](#1-amaç-ve-kapsam)
2. [Donanım Envanteri](#2-donanım-envanteri)
3. [Tech Stack](#3-tech-stack)
4. [Mimari](#4-mimari)
5. [Tasarım Dili (Apple-native)](#5-tasarım-dili-apple-native)
6. [Arayüz](#6-arayüz)
7. [Özellikler](#7-özellikler)
8. [Bildirimler](#8-bildirimler)
9. [Otomasyonlar](#9-otomasyonlar)
10. [Cihaz Protokolleri](#10-cihaz-protokolleri)
11. [İzinler](#11-izinler)
12. [Veri ve Ayarlar](#12-veri-ve-ayarlar)
13. [Yol Haritası](#13-yol-haritası)
14. [Riskler](#14-riskler)
15. [Açık İşler (RE)](#15-açık-işler-re)
16. [Kapsam Dışı](#16-kapsam-dışı)

---

## 1. Amaç ve Kapsam

**Problem:** Dock takıldığında ekran, mouse, kulaklık ve klavye için 5 ayrı uygulama gerekiyor. Bunların bir kısmı ücretli (BetterDisplay Pro), bir kısmı sadece Windows'ta çalışıyor (Synapse, Armoury Crate, Pusat).

**Çözüm:** Tek bir menü bar uygulaması:
- Dock takılınca bütün kurulumu otomatik uygular.
- Monitörün renklerini MacBook ekranına yaklaştırır.
- Mouse, kulaklık ve klavyenin donanım ayarlarını macOS'tan yönetir.
- Pil azalınca iPhone'daki gibi uyarı verir.
- macOS'un kendi uygulamalarından biri gibi görünür ve hissettirir.

---

## 2. Donanım Envanteri

| Cihaz | USB ID | Bağlantı | Kontrol kanalı | Test durumu |
|---|---|---|---|---|
| Ugreen dock | `17E9:6000` (DisplayLink "DL-Dock") ve VIA Labs hub `2109:*` | USB-C | — | ✅ Algılama |
| PR27R165QC monitör (27", 2560×1440) | — | Dock üzerinden DP alt mode | DDC (IOAVService) | ✅ Parlaklık okundu |
| ASUS ROG Gladius II Wireless | `0B05:18A0` | 2.4 GHz dongle | HID, usage page `0xFF01` | ✅ Pil %75, RGB okundu |
| Razer BlackShark V2 HyperSpeed | `1532:0565` | 2.4 GHz dongle (MediaTek) | HID, usage page `0xFF13`/`0xFF14`, report ID 2 | ✅ Pil %8, firmware 1.7 |
| PUSAT K3 Pro klavye | `0C45:5004` (SONiX, Redragon K556 ailesi) | USB, dock üzerinden | HID, usage page `0xFF1C`, report ID 4 | ✅ Profil ve LED okundu |

**Monitörle ilgili bilinenler:**
- Sunulan yenileme hızları: 60 / 75 / 120 Hz. 165 Hz dock'un bant genişliği yüzünden yok.
- Mevcut mod: HiDPI 2048×1152 (4096×2304 framebuffer) @ 120 Hz
- Gamma tablosu kapasitesi: 1024
- macOS, dock takılınca monitörü YCbCr Limited moduna alıyor. Bu yüzden RGB Full'a zorlamak gerekiyor.

---

## 3. Tech Stack

| Katman | Teknoloji | Neden |
|---|---|---|
| Dil | **Swift 6** (strict concurrency) | Kurulu: Swift 6.4.2 |
| UI | **SwiftUI** + AppKit köprüleri | Ana pencere SwiftUI, menü bar ve özel pencereler AppKit |
| Menü bar | `NSStatusItem` + `NSPopover` | Tek tık ve çift tık ayrımı için `MenuBarExtra` yetersiz kalıyor |
| Durum yönetimi | `@Observable` (Observation framework) | |
| Eşzamanlılık | Swift Concurrency: her cihaz için bir `actor` | HID istekleri sıraya girmeli; aynı anda iki istek gitmemeli |
| Ekran | CoreGraphics (`CGDisplay*`, `CGSetDisplayTransferByTable`, `CGConfigureDisplayOrigin`) | Public API |
| DDC | IOKit + private `IOAVService*` | Apple Silicon'da tek yol |
| Bağlantı modu | private `CADisplay` / `CADisplayMode` (QuartzCore): `availableModes` + `setCurrentMode:` | RE ile bulundu, `availableModes` Mac'te doğrulandı |
| Renk motoru (matris) | Tam ekran saydam `NSWindow` + private `CABackdropLayer` + `CIFilter` zinciri | RE ile bulundu; doygunluk, ton, canlılık, sepya burada |
| Link telemetrisi | `IOAVVideoInterfaceGetLinkData` (gerçek bpc, DSC durumu) | RE ile bulundu |
| HID cihazlar | `IOHIDManager` / `IOHIDDevice` | Ek sürücü gerekmez |
| USB olayları | `IOServiceAddMatchingNotification` | Dock algılama, polling yok |
| Mouse | `CGEventTap` (scroll), `IOHIDEventSystemClient` (hız ve ivme) | LinearMouse'taki yöntem |
| İmleç | private `CGSSetCursorScale` | |
| Ses | CoreAudio (`AudioObjectSetPropertyData`) | Otomatik ses çıkışı |
| Ortam ışığı | `IOHIDEventSystemClient` ALS servisi | Parlaklık senkronu |
| Bildirimler | `UserNotifications` + özel HUD penceresi | Bkz. [Bildirimler](#8-bildirimler) |
| Açılışta başlatma | `SMAppService.mainApp` | |
| Kısayollar | Carbon `RegisterEventHotKey` | Erişilebilirlik izni gerektirmez |
| Kalıcılık | JSON dosyaları (`Application Support/DisplayTuner/`) + `UserDefaults` | |
| Grafikler | Swift Charts | Pil geçmişi |
| Şarj limiti | `batt` CLI (`/usr/local/bin/batt`) | Zaten kurulu |
| Proje | Xcode projesi, minimum macOS 15, sadece arm64 | |
| Test | Swift Testing; protokoller için sahte (mock) HID cihazı | Paket kodlama ve çözme testleri |

**Harici bağımlılık:** Yok. Bütün protokoller sıfırdan yazılacak. Açık kaynak projelerden (GPL olanlar dahil) sadece mantık öğrenildi, kod kopyalanmayacak.

---

## 4. Mimari

```
DisplayTuner.app
├── App/
│   ├── DisplayTunerApp.swift        Uygulama girişi, AppDelegate
│   ├── StatusItemController.swift   Menü bar ikonu: tek tık, çift tık, sağ tık
│   ├── QuickPopover/                Tek tıkla açılan popover
│   └── MainWindow/                  Ana pencere: sidebar ve sekmeler
│
├── Core/
│   ├── DeviceRegistry.swift         Bağlı cihazların listesi (@Observable)
│   ├── DockWatcher.swift            USB takma/çıkarma olayları
│   ├── AutomationEngine.swift       Dock takılınca/çıkarılınca çalışan senaryolar
│   ├── SystemEvents.swift           Uyanma, ekran değişimi, kilit, uygulama değişimi
│   ├── ProfileStore.swift           Profillerin kaydı ve yüklenmesi
│   ├── HotkeyManager.swift
│   └── Notifier/                    Bildirim ve HUD sistemi
│
├── Display/
│   ├── DDCService.swift             VCP okuma ve yazma, yetenek listesi
│   ├── GammaEngine.swift            Renk eğrisi hesaplama ve uygulama
│   ├── ColorGuard.swift             Sıfırlanan gamma ayarlarını yeniden uygulama
│   ├── ModeService.swift            Çözünürlük, HiDPI, Hz
│   ├── ArrangementService.swift     Ana ekran ve yerleşim
│   ├── ConnectionModeService.swift  RGB Full / YCbCr (RE'ye bağlı)
│   ├── AmbientSync.swift            Ortam ışığına göre parlaklık
│   └── NightMode.swift
│
├── Input/
│   ├── ScrollReverser.swift
│   ├── PointerSettings.swift
│   ├── CursorService.swift
│   └── BrightnessKeys.swift         Parlaklık tuşlarını DDC'ye yönlendirme
│
├── Audio/
│   └── OutputSwitcher.swift
│
└── Devices/
    ├── HID/                         Ortak HID katmanı (IOHIDDevice sarmalayıcı, istek kuyruğu)
    ├── Razer/BlackSharkV2HS.swift
    ├── Asus/GladiusIIWireless.swift
    ├── Pusat/K3Pro.swift
    └── Battery/
        ├── BatteryMonitor.swift     Sorgu zamanlaması, eşikler
        └── BatteryHistory.swift     Geçmiş ve kalan süre tahmini
```

**İlkeler:**
- Her cihaz sürücüsü ortak bir `PeripheralDevice` protokolünü uygular: `battery()`, `capabilities`, `settingsView`.
- Private API kullanan her modül izole edilir. API bulunamazsa ya da başarısız olursa sadece o özellik devre dışı kalır, uygulama çökmez.
- Donanıma yazan her komutun önünde bir **debounce** vardır (slider sürüklerken flash belleği yıpratmamak için).
- Donanım ayarı değiştirmeden önce mevcut değer okunur ve "Geri al" için saklanır.

---

## 5. Tasarım Dili (Apple-native)

**Hedef:** Uygulama, macOS'un Sistem Ayarları'ndan ya da Apple'ın kendi uygulamalarından biri gibi görünmeli. Apple logosu ve marka adları kullanılmaz; "Apple'a ait gibi" hissi, Apple'ın kendi tasarım dili ve bileşenleriyle sağlanır.

### Görsel kurallar
| Öğe | Kural |
|---|---|
| Malzeme | macOS 26+ **Liquid Glass**: `.glassEffect()`, popover ve HUD'larda cam görünüm. Eski sürümlerde `.ultraThinMaterial` |
| Pencere | `NavigationSplitView`, saydam sidebar, birleşik başlık çubuğu. Sistem Ayarları ile aynı yapı |
| Formlar | `Form` + `.formStyle(.grouped)`: Sistem Ayarları'ndaki yuvarlatılmış gruplar |
| İkonlar | Sadece **SF Symbols** (`display`, `computermouse.fill`, `headphones`, `keyboard`, `battery.25percent`…), hiyerarşik ve çok renkli render modları |
| Sidebar ikonları | Sistem Ayarları'ndaki gibi renkli yuvarlak kare arka plan üzerinde beyaz sembol |
| Renk | Sistem vurgu rengi (`.tint`), sabit renk kodu yok. Açık ve koyu mod otomatik |
| Yazı | SF Pro (sistem fontu), Dynamic Type boyutları: `.title2`, `.headline`, `.callout` |
| Kontroller | Native `Slider`, `Toggle` (switch stili), `Picker` (segmented), `Stepper` |
| Animasyon | `.spring` ve `.smooth`, değer değişimlerinde `.contentTransition(.numericText())` |
| Boşluklar | 8 pt ızgara, Apple HIG'deki kenar boşlukları |
| Uygulama ikonu | macOS ikon şablonu: yuvarlatılmış kare (squircle), katmanlı ve cam efektli. Monitör ve parlaklık güneşi motifi |

### Referans alınacak Apple ekranları
- **Popover:** Kontrol Merkezi'ndeki Ekran ve Ses modülleri
- **Ana pencere:** Sistem Ayarları → Ekranlar, Bluetooth, Fare
- **Pil göstergeleri:** iPhone'daki Piller widget'ı (halka göstergeler)
- **EQ:** iOS Müzik → Ekolayzır görünümü ama sürüklenebilir eğri
- **Klavye RGB:** Sistem Ayarları → Klavye düzeninin görsel stili
- **HUD'lar:** macOS ses ve parlaklık HUD'ı, iPhone Dynamic Island

### Erişilebilirlik
- Bütün kontrollerde VoiceOver etiketleri
- "Hareketi azalt" açıkken animasyonlar kapanır
- Renk ayarlarında sadece renge dayalı bilgi verilmez; değer her zaman yazıyla da gösterilir

---

## 6. Arayüz

### 6.1 Menü bar ikonu
- **İkon:** SF Symbol `sun.max.fill` (monitör bağlı değilken `display`). Pil kritikse sağ üstünde kırmızı nokta.
- **Tek tık:** Hızlı popover (6.2)
- **Çift tık:** Ana pencere (6.3)
- **Sağ tık:** Menü → Profiller ▸, Ana pencereyi aç, Ayarlar, Çık

> Tek tık ile çift tık ayrımı: Tıklamadan sonra `NSEvent.doubleClickInterval` kadar beklenir. Bu süre içinde ikinci tık gelmezse popover açılır.

### 6.2 Hızlı popover (Kontrol Merkezi stili)
```
┌──────────────────────────────────────┐
│  ☀︎  Dahili Ekran          ━━━━━●━━━  │
│  ☀︎  PR27R165QC            ━━━━━━━●━  │
├──────────────────────────────────────┤
│  Profil   [ Gündüz | Gece | Film ]   │
├──────────────────────────────────────┤
│   ◔ 75%       ◔ 8%        ⌨︎ Prof. 1  │
│   Mouse      Kulaklık     Klavye     │
└──────────────────────────────────────┘
```
- Parlaklık slider'ları: Harici monitör DDC ile, dahili ekran DisplayServices ile
- Pil halkaları: iPhone Piller widget'ı stilinde, renkler yeşil → sarı → kırmızı

### 6.3 Ana pencere (Sistem Ayarları stili)
**Sidebar:**
```
🔍 Ara
─────────────
🖥  Ekran
🖱  Mouse
🔌  Bağlı Cihazlar
     ├ 🎧 BlackShark V2 HyperSpeed   8% ⚠︎
     ├ 🖱 ROG Gladius II             75%
     ├ ⌨︎ PUSAT K3 Pro
     ├ 🖥 PR27R165QC
     └ 🔌 Ugreen Dock
─────────────
⚙︎  Otomasyon
🔔  Bildirimler
```
Bağlı cihazlar sidebar'da alt öğe olarak görünür. Birine tıklayınca o cihazın ayar sayfası açılır.

---

## 7. Özellikler

### 7.1 🖥 Ekran

**Seçim:** Üstte ekran seçici (Dahili / PR27R165QC). Sistem Ayarları → Ekranlar'daki gibi ekran küçük resimleriyle.

#### Parlaklık ve donanım ayarları (DDC)
| Ayar | VCP | Not |
|---|---|---|
| Parlaklık | `0x10` | ✅ Test edildi (100/100) |
| Kontrast | `0x12` | |
| RGB kazanç (donanım beyaz dengesi) | `0x16` / `0x18` / `0x1A` | Monitör destekliyorsa |
| Renk ön ayarı | `0x14` | sRGB, 6500K vb. |
| Ses | `0x62` | Monitör hoparlörü varsa |

İlk bağlantıda monitörden yetenek listesi (`0xF3`) okunur; desteklenmeyen ayarlar gizlenir.

#### Renk ayarları (yazılım, gamma tablosu)
| Grup | Ayarlar |
|---|---|
| Ton | Kontrast, Gama, Kazanç, Parlak alanlar, Gölge |
| Renk | Renk sıcaklığı (K), Kuantizasyon |
| Kanallar | Gama R/G/B, Kazanç R/G/B |
| Matris (Faz 6) | Doygunluk, Canlılık, Ton (hue), Sepya |

- Her slider'ın yanında sıfırlama düğmesi (↺) bulunur.
- Önizleme eğrisi: R, G ve B eğrilerinin küçük grafiği.
- **Test desenleri:** Tam ekran gri skala, ten rengi, doygun renk ve siyah seviyesi desenleri. MacBook ekranında da aynısı açılır, yan yana karşılaştırılır.
- **"MacBook'a yaklaştır" hazır profili:** Başlangıç noktası olarak.

#### Bağlantı modu
- RGB / YCbCr 4:4:4 / 4:2:2 / 4:2:0
- Aralık: Full / Limited
- Bit derinliği: 8 / 10 bpc
- Varsayılan ve otomatik: **RGB Full 8 bpc**

#### Çözünürlük ve yenileme hızı
- Çözünürlük listesi: HiDPI modlar işaretli, "Önerilen" etiketiyle
- Hz seçici: o çözünürlükte mevcut olanlar (60 / 75 / 120)
- Bilgi notu: "165 Hz bu bağlantıda kullanılamıyor (dock bant genişliği)"

#### Yerleşim
- Ana ekran seçimi (menü bar ve Dock hangi ekranda olacak)
- Ekranların konumu: Sistem Ayarları'ndaki gibi sürükle-bırak önizleme
- "Bu yerleşimi kaydet": Dock takılınca otomatik geri yüklenir

#### Otomatik parlaklık
- **Parlaklık senkronu:** MacBook'un ışık sensörüne göre monitör parlaklığı. Ayarlanabilir eğri ve tepki hızı
- **Gece modu:** Gün batımında renk sıcaklığını yavaşça düşürür ve parlaklığı azaltır. Konum veya saat tabanlı

#### Renk profilleri
- Bir profil şunları içerir: renk ayarları, DDC değerleri, bağlantı modu, çözünürlük ve Hz
- Hazır profiller: Gündüz, Gece, Film, Kodlama
- Profiller kısayol tuşu ve popover'dan değiştirilebilir

### 7.2 🖱 Mouse (macOS tarafı)
| Ayar | Detay |
|---|---|
| Scroll yönü | Trackpad doğal kalır, harici mouse ters döner. "Sadece harici mouse takılıyken" seçeneği |
| Scroll hızı | Satır başına kaydırma miktarı, yumuşak kaydırma aç/kapa |
| İmleç hızı | Doğrusal hız ayarı |
| İvme | Kapalı (oyun için) / macOS varsayılanı / özel eğri |
| İmleç boyutu | 1x – 4x |
| Özel imleç | Hazır imleç paketleri (ileride) |
| Uygulamaya göre profil | Örneğin oyun açılınca hız yüksek ve ivme kapalı; çıkınca normale dönüş |

### 7.3 🔌 Bağlı Cihazlar

#### 🎧 Razer BlackShark V2 HyperSpeed
| Bölüm | İçerik |
|---|---|
| Başlık kartı | Büyük pil halkası, şarj durumu, tahmini kalan süre, firmware sürümü |
| **Ekolayzır** | 10 bant (31 Hz – 16 kHz), -9 ile +6 dB arası, sürüklenebilir eğri. Hazır ayarlar: Flat, Game, Music, Movie, Custom. EQ açma/kapama |
| Uygulamaya göre EQ | Uygulama → preset eşleştirme listesi (örneğin Steam oyunları → Game, Spotify → Music) |
| Mikrofon | Mikrofon monitörleme (sidetone) aç/kapa ve seviye 0–15. Mute durumu göstergesi |
| Güç | Otomatik kapanma: Kapalı, 5–255 dakika |
| Dongle LED | Kapalı / Bağlantı durumu / Pil durumu / Sadece düşük pil uyarısı |
| Diğer | Rahatsız etmeyin (2.4 GHz'teyken Bluetooth aramalarını engelle), ses iyileştirme (bas genişletici) |
| Pil geçmişi | Son 7 günün grafiği (Swift Charts) |

#### 🖱 ASUS ROG Gladius II Wireless
| Bölüm | İçerik |
|---|---|
| Başlık kartı | Pil (%25'lik adımlarla), şarj durumu, kalan süre |
| RGB | Logo ve tekerlek için ayrı ayrı: Sabit, Nefes, Renk döngüsü, Tepki, Pil durumu, Kapalı. Renk seçici ve parlaklık (0–4) |
| Performans | DPI (100'lük adımlarla, 16.000'e kadar, 2 profil), polling rate (125 / 250 / 500 / 1000 Hz) |
| Gelişmiş | Açı yakalama (angle snapping), debounce, otomatik kapanma, düşük pil uyarı eşiği |
| Kısayol | "macOS mouse ayarları" → Mouse sekmesine geçer |

#### ⌨︎ PUSAT K3 Pro
| Bölüm | İçerik |
|---|---|
| Profil | 3 donanım profili, aktif profil seçimi |
| Efekt | 20 yerleşik efekt (aşağıda), parlaklık (0–5), hız (0–3), renk ya da gökkuşağı |
| Yön | Soldan sağa / sağdan sola. Sadece hareketli efektlerde görünür |
| **Tuş başına renk** | Klavye görseli; tuşlara tıklayarak ya da seçerek renk verme. Hazır düzenler: FPS (WASD), Kodlama, Gece |
| Tuş atama | Bir tuşa başka tuş, medya işlevi ya da makro atama |
| Tuş haritası kalibrasyonu | Tuşlar sırayla yanar, kullanıcı hangisinin yandığını tıklar (ilk kurulumda bir kez) |

**Yerleşik efektler:** Yatay dalga, Nabız, Kasırga, Renkli nefes, Nefes, Sabit, Tepki (tek tuş), Tepki (dalgalanma), Tepki (yatay), Şelale, Girdap, Dikey dalga, Sinüs, Vorteks, Yağmur, Çapraz dalga, Renkli tepki, Dalgalanma, Kapalı, Özel.

#### 🖥 PR27R165QC (cihaz sayfası)
Model, bağlantı tipi, mevcut mod, desteklenen DDC özellikleri ve "Ekran sekmesinde aç" kısayolu.

#### 🔌 Ugreen Dock
Takılı/çıkarılmış durumu, dock'a bağlı cihazlar ve otomasyon ayarlarına kısayol.

### 7.4 🔊 Ses
- **Otomatik ses çıkışı:** Kulaklık açılınca (bağlantı durumu `1`) ses çıkışı kulaklığa geçer. Kapanınca önceki çıkışa (MacBook hoparlörü) döner.
- Ses çıkışı değişince küçük bir HUD gösterilir: "🎧 BlackShark V2'ye geçildi"

### 7.5 ⌨︎ Kısayollar
| Kısayol | İşlev |
|---|---|
| ⌃⌥1 / 2 / 3 / 4 | Renk profilleri |
| Parlaklık tuşları | İmlecin bulunduğu ekranın parlaklığı (DDC) |
| ⌃⌥E | Kulaklık EQ preset'ini döngüyle değiştir |
| ⌃⌥K | Klavye profilini değiştir |

Hepsi ayarlardan değiştirilebilir.

---

## 8. Bildirimler

**Hedef:** Uyarılar iPhone'dakiler gibi görünmeli ve hissettirmeli: sade, yuvarlatılmış, cam görünümlü ve sistemle bütünleşik.

### 8.1 İki katman
| Katman | Ne zaman | Görünüm |
|---|---|---|
| **Sistem bildirimi** (`UserNotifications`) | Normal uyarılar | macOS'un kendi bildirim balonu. Bildirim Merkezi'nde kalır. Odak modlarına uyar |
| **Kritik uyarı** (özel pencere) | %5 ve altı | iPhone'daki **"Düşük Pil"** uyarısının birebir stili: ekranın ortasında, cam arka planlı, kendiliğinden kapanmaz |
| **HUD** (özel pencere) | Anlık geri bildirim (ses çıkışı değişti, profil değişti, mikrofon kapalı) | Ekranın üst ortasında, **Dynamic Island** gibi kapsül şeklinde. 2 saniye sonra kaybolur |

### 8.2 Pil eşikleri
| Cihaz | Eşikler | Bildirim tipi |
|---|---|---|
| 🖱 Mouse | %25 → sistem bildirimi; %0 (kritik) → kritik uyarı | Mouse pili %25'lik adımlarla raporluyor |
| 🎧 Kulaklık | %20 → bildirim; %10 → bildirim; %5 → kritik uyarı; %3 → kritik uyarı ve ses | |

**Kurallar:**
- Her eşik için **bir kez** uyarı verilir.
- Cihaz şarja takılınca ya da pil eşiğin 5 puan üstüne çıkınca uyarılar sıfırlanır.
- Kritik uyarı çıkınca mouse LED'i (isteğe bağlı) kırmızı nefes moduna geçer; pil yükselince eski ayarına döner.
- Şarj tamamlanınca bildirim: "🎧 Kulaklık tamamen şarj oldu"
- Eşikler Bildirimler sekmesinden cihaz başına değiştirilebilir.

### 8.3 Bildirim metinleri (iOS tonu)
| Durum | Başlık | Metin |
|---|---|---|
| Kulaklık %20 | **Kulaklık Pili Azalıyor** | BlackShark V2'de %20 pil kaldı. |
| Kulaklık %10 | **Kulaklık Pili Azalıyor** | BlackShark V2'de %10 pil kaldı. Yaklaşık 7 saat kullanılabilir. |
| Kulaklık %5 (kritik) | **Düşük Pil** | BlackShark V2'de %5 pil kaldı. Kulaklığınızı şarj edin. `[Tamam]` |
| Mouse %25 | **Mouse Pili Azalıyor** | ROG Gladius II'de %25 pil kaldı. |
| Şarj tamam | **Şarj Tamamlandı** | BlackShark V2 tamamen şarj oldu. |
| Mikrofon (HUD) | 🎙̸ Mikrofon Kapalı | |
| Ses çıkışı (HUD) | 🎧 BlackShark V2 | |

Bildirimlerde cihazın SF Symbol ikonu ve pil halkası küçük resim olarak gösterilir.

### 8.4 Kritik uyarı tasarımı
```
        ┌───────────────────────────┐
        │                           │
        │        ▭ (kırmızı pil)    │
        │                           │
        │        Düşük Pil          │
        │  BlackShark V2'de %5 pil  │
        │         kaldı.            │
        │ ───────────────────────── │
        │           Tamam           │
        └───────────────────────────┘
```
- `NSPanel`, `.floating` seviyesinde, Liquid Glass arka plan, 270 pt genişlik, 14 pt köşe yarıçapı
- Açılırken `.spring` ölçek animasyonu (0.9 → 1.0), sistem uyarı sesi
- Tam ekran uygulamaların üstünde de görünür

### 8.5 Sorgu zamanlaması
| Cihaz | Sıklık | Not |
|---|---|---|
| Kulaklık | 60 sn (pil %10 altındayken 30 sn) | Önce bağlantı durumu (`0x20`) sorgulanır; kulaklık kapalıysa pil sorgusu gönderilmez |
| Mouse | 60 sn | Mouse uykudaysa (`FF AA` hatası) bir sonraki tura bırakılır |
| Mikrofon mute | 1 sn | Sadece kulaklık bağlıyken |

---

## 9. Otomasyonlar

### 9.1 Dock takılınca (sırayla)
1. Monitörün gelmesini bekle (en fazla 10 sn)
2. Bağlantı modunu **RGB Full**'a al ve doğrula
3. Monitörü ana ekran yap, kayıtlı yerleşimi uygula
4. Kayıtlı çözünürlüğü, Hz'i ve renk profilini uygula
5. Şarj limitini **%80**'e çek (`batt limit 80`)
6. Harici mouse varsa scroll yönünü ters çevir
7. Masa modu sahnesi (isteğe bağlı): seçili uygulamaları aç, uykuyu engelle
8. HUD: "🖥 Masa modu"

### 9.2 Dock çıkarılınca
1. Şarj limitini **%100**'e çıkar
2. Scroll yönünü varsayılana döndür
3. Masa modu uygulamalarını kapat (isteğe bağlı)

### 9.3 Ayarları koruma (ColorGuard)
macOS gamma tablosunu birçok olayda sıfırlıyor. Şu olaylarda renk ayarları ve bağlantı modu yeniden uygulanır:
- Uykudan uyanma (`NSWorkspace.didWakeNotification`)
- Ekran yeniden yapılandırma (`CGDisplayRegisterReconfigurationCallback`)
- Ekran kilidinin açılması
- Night Shift durum değişikliği
- Renk profili değişikliği
- Ek güvenlik: 10 sn'de bir mevcut gamma tablosu okunur ve beklenenden farklıysa yeniden uygulanır

### 9.4 Uygulamaya göre geçişler
Öndeki uygulama değişince (`NSWorkspace.didActivateApplicationNotification`) kulaklık EQ preset'i ve mouse profili uygulanır. Hazır ayara yazmak flash'ı yıpratmaz, ama yine de 2 sn debounce uygulanır.

---

## 10. Cihaz Protokolleri

> Bu bölümdeki bilgiler Mac'te **gerçek donanım üzerinde okuma sorgularıyla doğrulandı** (11 Kasım 2026). Yazma komutları kaynaklardan alındı, ilk kullanımda dikkatle test edilecek.

### 10.1 DDC (monitör)
- Servis: IOKit sınıfı `DCPAVServiceProxy`, `Location = "External"` → `IOAVServiceCreateWithService`
- I²C: adres `0x37`, offset `0x51`
- **Okuma (Get VCP):** `82 01 <vcp> <chk>` yaz, 50 ms bekle, 12 byte oku
  - `chk = 0x6E ^ 0x51 ^ 0x82 ^ 0x01 ^ vcp`
  - Cevap: `[2]=0x02`, `[4]=vcp`, `[6..7]=max`, `[8..9]=mevcut` (big endian)
- **Yazma (Set VCP):** `84 03 <vcp> <hi> <lo> <chk>`
- ✅ Doğrulandı: `6e 88 02 00 10 00 00 64 00 64` → parlaklık 100/100

### 10.2 Razer BlackShark V2 HyperSpeed (MediaTek)
- Cihaz: `1532:0565`, primary usage page `0xFF13` (report ID 2 aynı cihazdaki `0xFF14` koleksiyonunda)
- **İstek:** 64 byte output report, report ID `0x02`

| Byte | Değer |
|---|---|
| 0 | `0x02` (report ID) |
| 2 | `0x60 \| seq` (seq: 5 bit sayaç) |
| 6 | `4 + parametre sayısı` |
| 9 | Hedef: `0x80` kulaklık, `0x00` dongle |
| 10 | Komut |
| 12 | Parametre sayısı |
| 13… | Parametreler |
| 62 | Byte 0–61'in XOR'u |

- **Cevap:** Input report ID 2. `[1]` durum, `[8]=0x80`, `[9]` hedef, `[10]` komut, `[11]=1` (ACK), `[12]` sayı, `[13…]` veri
- **Durum kodları:** `02` OK · `01` meşgul · `04` kulaklık cevap vermedi · `05` desteklenmiyor · `09` bu hedefte yok

| Komut (okuma) | Yazma | Hedef | Anlam |
|---|---|---|---|
| `0x00` | | 80/00 | Seri numarası |
| `0x02` | | 80/00 | Firmware (✅ 1.7) |
| `0x20` | | 00 | Kulaklık bağlı mı (✅ 0/1) |
| `0x21` | | 80 | **Pil %** (✅ 8) |
| `0x2A` | | 80 | **Şarj** (✅ 0) |
| `0x13` | `0x93` | 80 | EQ preset: `00` Flat, `07` Game, `08` Music, `09` Movie, `FF` Custom |
| `0x15` | `0x95` | 80 | 10 bant EQ. Yazarken `dB + 5`, aralık -9…+6 |
| `0x1E` | `0x9E` | 80 | EQ açık/kapalı |
| `0x1D` | `0x9D` | 80 | Ses iyileştirme |
| `0x18` | `0x98` | 80 | Sidetone açık/kapalı |
| `0x19` | `0x99` | 80 | Sidetone seviyesi 0–15 |
| `0x2C` | `0xAC` | 80 | Otomatik kapanma (dakika, 0 = kapalı) |
| `0x27` | `0xA7` | 80 | Rahatsız etmeyin |
| `0x55` | | 80 | Mikrofon mute durumu |
| `0x66` | `0xE6` | 00 | Dongle LED modu 0–3 |

- ⚠️ `0x95` (EQ eğrisi) flash'a yazar: slider sürüklenirken 250 ms debounce.

### 10.3 ASUS ROG Gladius II Wireless
- Cihaz: `0B05:18A0`, usage page `0xFF01`, report ID yok (0), 64 byte output report
- Cevap input report olarak gelir; ilk iki byte komutu tekrarlar. `FF AA` = hata (desteklenmiyor ya da mouse uykuda)

| Komut | Yön | Anlam |
|---|---|---|
| `12 07` | Okuma | **Durum:** `[4]` pil (×25 = %) ✅ 75, `[5]` otomatik kapanma, `[9]` şarj |
| `12 03 <bölge>` | Okuma | **Aydınlatma:** `[4]` mod, `[5]` parlaklık, `[6..8]` RGB ✅ |
| `51 28 <bölge> 00 <mod> <parlaklık> <R> <G> <B> <yön> <rastgele> <hız>` | Yazma | Aydınlatma ayarı |
| `50 03` | Yazma | Ayarları mouse hafızasına kaydet |
| `51 31 04 00 <oran>` | Yazma | Polling rate (doğrulanacak) |
| `51 31 06 00 <0/1>` | Yazma | Açı yakalama (doğrulanacak) |
| `51 37 00 00 <kapanma> 00 <düşük pil>` | Yazma | Güç ayarları (doğrulanacak) |

(Byte indeksleri report ID olmadan, cevabın kendisine göre verilmiştir.)

- Bölgeler: `00` Logo, `01` Tekerlek, `03` Hepsi
- Modlar: `00` Sabit, `01` Nefes, `02` Renk döngüsü, `04` Tepki, `06` Pil durumu, `F0` Kapalı
- Okunan değer: Her iki bölge Sabit, parlaklık 2/4, `#FF00FD`

### 10.4 PUSAT K3 Pro (Redragon K556 protokolü)
- Cihaz: `0C45:5004`, usage page `0xFF1C`, usage `0x92`, report ID `0x04`, 64 byte
- **Checksum:** Byte 1–2 = byte 3–63 toplamının 16 bitlik değeri (little endian)
- Yazma işlemleri **başlat** (`04 01 00 01`) ve **bitir** (`04 02 00 02`) paketleri arasında gönderilir

| Komut | Paket (byte 0, 3, 4, 5) | Anlam |
|---|---|---|
| Aktif profili oku | `04 · 03 2C 00` | Cevap `[18]` = profil - 1 ✅ (Profil 1) |
| LED ayarlarını oku | `04 · 05 38 <00/2A/54>` | Profil 1/2/3. `[8]` mod, `[9]` parlaklık, `[10]` 3 - hız, `[11]` yön (`FF` sol, `00` sağ), `[12]` gökkuşağı, `[13..15]` RGB ✅ |
| Yön ayarla | `04 · 06 01 <03/2D/57>`, `[8]=FF/00` | Profil 1/2/3 |
| Diğer ayarlar | `04 · 06 01 <offset>` | Mod, parlaklık, hız, renk; profil başına offset |

- Mod kodları: `01` Yatay dalga … `13` Kapalı, `14` Özel (tam liste 7.3'te)
- Okunan değerler: Profil 1 aktif (yatay dalga, gökkuşağı, parlaklık 5, hız 2, sağa). Profil 2 ve 3 özel moda ayarlı.
- Tuş başına renk, tuş atama ve makro paketleri: referans olarak [dokutan/rgb_keyboard](https://github.com/dokutan/rgb_keyboard) mantığı (GPL; kod kopyalanmayacak)

### 10.5 Kaynaklar (sadece mantık için)
| Konu | Kaynak |
|---|---|
| Razer HyperSpeed protokolü | [justik13/razer-blackshark-v2-hyperspeed-webhid](https://github.com/justik13/razer-blackshark-v2-hyperspeed-webhid), [Ar4ikov/openrazer-win](https://github.com/Ar4ikov/openrazer-win) |
| ASUS ROG mouse protokolü | [seerge/g-helper](https://github.com/seerge/g-helper) |
| Redragon/SONiX klavye | [dokutan/rgb_keyboard](https://github.com/dokutan/rgb_keyboard) |
| DDC | MonitorControl, m1ddc |
| Scroll ve ivme | LinearMouse |
| Dithering | Stillcolor |

---

## 11. İzinler

| İzin | Neden | Ne zaman istenir |
|---|---|---|
| Erişilebilirlik | Scroll ters çevirme (`CGEventTap`), parlaklık tuşlarını yakalama | Mouse sekmesi ilk açıldığında |
| Bildirimler | Pil uyarıları | İlk açılışta |
| Konum (isteğe bağlı) | Gün doğumu ve batımına göre gece modu | Gece modu "konuma göre" seçilirse |
| Yönetici (bir kez) | `batt` zaten kurulu ve yetkili, yeni izin gerekmez | — |

HID cihazlarının üreticiye özel kanalları (`0xFF**`) Giriş İzleme izni **gerektirmez**; testlerde izinsiz çalıştı.

İzin ekranları Apple'ın kendi onboarding stilinde olur: büyük SF Symbol, kısa açıklama ve "Sistem Ayarları'nı Aç" düğmesi.

---

## 12. Veri ve Ayarlar

```
~/Library/Application Support/DisplayTuner/
├── profiles.json         Renk profilleri
├── layout.json           Ekran yerleşimi
├── devices.json          Cihaz ayarları ve bildirim eşikleri
├── app-rules.json        Uygulamaya göre EQ ve mouse profilleri
├── keyboard-map.json     Tuş → LED indeks haritası (kalibrasyon)
├── battery-history.sqlite  Pil geçmişi (7 gün)
└── backups/              Donanıma yazmadan önceki ayarların yedekleri
```
- **Dışa ve içe aktarma:** Tek bir `.displaytuner` dosyası (JSON zip)
- **Eski kurulumdan geçiş:** İlk açılışta `com.muhammed.dockapps` LaunchAgent'ı tespit edilir ve devre dışı bırakmak için onay istenir.

---

## 13. Yol Haritası

| Faz | İçerik | Tamamlanma kriteri |
|---|---|---|
| **1. İskelet** | Xcode projesi, menü bar ikonu (tek tık, çift tık, sağ tık), popover, ana pencere ve sidebar, tasarım sistemi bileşenleri, DockWatcher, DDC parlaklık | Uygulama açılıyor, iki ekranın parlaklığı popover'dan değişiyor |
| **2. Cihazlar ve bildirimler** | Ortak HID katmanı; Razer, ASUS ve Pusat sürücüleri (okuma); pil izleme; **bildirimler, kritik uyarı ve HUD**; otomatik ses çıkışı; mikrofon göstergesi | Üç cihazın pili ve ayarları görünüyor, eşiklerde uyarılar geliyor |
| **3. Cihaz ayarları** | Kulaklık EQ, sidetone, güç ve LED; mouse RGB, DPI ve polling; klavye efektleri, yön, parlaklık ve profiller; uygulamaya göre EQ | Synapse, Armoury Crate ve Pusat yazılımına gerek kalmıyor |
| **4. Mouse** | Scroll ters çevirme, hız, ivme, imleç boyutu, uygulamaya göre mouse profili, parlaklık tuşları | **LinearMouse kaldırılabilir** |
| **5. Ekran** | Gamma renk ayarları, ColorGuard, profiller, çözünürlük ve Hz, ana ekran ve yerleşim, test desenleri, parlaklık senkronu, gece modu, kısayollar | |
| **6. Bağlantı modu** | RGB Full (RE sonucuyla) | **BetterDisplay ve `dockapps.sh` kaldırılabilir** 🎉 |
| **7. Matris ve klavye** | Doygunluk, ton, canlılık, sepya (RE sonucuyla); tuş başına renk editörü ve kalibrasyon; tuş atama ve makro | |
| **8. Cilalama** | Pil geçmişi grafikleri, kalan süre tahmini, masa modu sahnesi, dışa/içe aktarma, uygulama ikonu | |

---

## 14. Riskler

| Risk | Etki | Önlem |
|---|---|---|
| RGB Full RE'si başarısız olur | Monitör soluk kalır | Geçici çözüm: BetterDisplay'in ücretsiz CLI'ını sadece bu iş için çağırmak |
| macOS güncellemesi private API'leri bozar | İlgili özellik çalışmaz | Modüller izole; açılışta API kontrolü; özellik gri gösterilir |
| Donanım flash'ının yıpranması | Kulaklık EQ ve klavye ayarları | Debounce, sadece değer değişince yazma |
| Yanlış paket cihazı bozar | Düşük ama mümkün | Yazmadan önce yedek alma, bilinen paketler dışında komut göndermeme, checksum doğrulama |
| Klavye tuş haritası farklı | Tuş başına renkler yanlış tuşlara gider | Kalibrasyon ekranı |
| Mouse uykudayken sorgu cevapsız kalır | Pil "bilinmiyor" görünür | Son bilinen değeri zaman damgasıyla göster |
| 165 Hz yok | — | Yazılımla çözülemez; bilgi notu |

---

## 15. Açık İşler (RE)

✅ **Tamamlandı (11 Kasım 2026).** Ayrıntılar: `~/Desktop/Coding Work/Second_Brain/BetterDisplay_RE_Spec.md`

1. **Bağlantı modu:** `CADisplay.availableModes` içinde her renk modu ayrı bir `CADisplayMode`; istenen mod bulunup `setCurrentMode:` ile uygulanıyor. Mac'te doğrulanan PR27R165QC modları (2560×1440):
   - 120 Hz: `RGBFullRange` 8 bpc · `YCbCr444LimitedRange` 8 bpc (**şu an aktif olan, soluk mod**) · `HDR10_422LimitedRange` 12 bpc
   - 60 Hz: `RGBFullRange` 8/10 bpc · `YCbCr444LimitedRange` 8/10 bpc · `HDR10_RGBFullRange` 10/12 bpc · HDR10 4:4:4/4:2:2
   - Not: `colorMode` değerleri RE dokümanındaki örneklerden farklı (`"rgb_full"` değil `"RGBFullRange"`). `otherAttributes` bu macOS'ta yok.
2. **Doygunluk ve ton:** Overlay pencere (`CGShieldingWindowLevel`, `ignoresMouseEvents`, arka plan alpha 0.001) + `CABackdropLayer` (`allowsInPlaceFiltering`) + `CIFilter` zinciri: `CIColorMatrix` (kazanç, sıcaklık) → `CIGammaAdjust` → `CIColorPolynomial` (kanal gama) → `CIHighlightShadowAdjust` → `CIColorControls` (kontrast, doygunluk) → `CIVibrance` → `CIHueAdjust` → `CISepiaTone` → `CIColorPosterize`. Gamma tablosu (`CGSetDisplayTransferByTable`) bundan sonra, donanımda uygulanıyor.
3. **Ek bulgular:** `enableDither` / `uniformity2D` anahtarları (`IORegistryEntrySetCFProperty`, `AppleCLCD2`) ile dithering kapatma; `IOAVVideoInterfaceGetLinkData` ile gerçek bpc ve DSC durumu.

Not: Matematik ve offset'ler RE dokümanından alındı. Bağlantı modu listesi Mac'te doğrulandı; overlay ve offset'ler uygulama yazılırken test edilecek.

Pusat, Razer ve ASUS yazılımları için RE **gerekmiyor**; protokoller açık kaynakta mevcut ve donanımda doğrulandı.

---

## 16. Kapsam Dışı

- **Pencere düzenini geri yükleme:** Kullanıcı istemedi.
- **Kendi ölçekleyicimiz** (sanal ekran ve Metal ile küçültme): Gerek görülmedi.
- **Kolorimetre ile kalibrasyon:** Cihaz yok; test desenleriyle gözle eşleştirme yapılacak.
- **THX Spatial ve mikrofon gürültü filtresi:** Synapse'te Windows yazılımıyla yapılıyor, kulaklıkta değil.
- **App Store dağıtımı:** Private API'ler yüzünden mümkün değil; kişisel kullanım.
