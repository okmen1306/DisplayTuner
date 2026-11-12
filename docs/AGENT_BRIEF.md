# DisplayTuner — Agent Brief (Uygulama Talimatı)

> Bu dosya, uygulamayı yazacak agent için **tek ve eksiksiz kaynaktır**. Kararlar alınmıştır; agent bunları yeniden tartışmaz, uygular.
> Bir karar uygulanamıyorsa agent durur, sebebini yazar ve kullanıcıya sorar. Kendi başına alternatif seçmez.

| | |
|---|---|
| Tarih | 11 Kasım 2026 |
| Proje klasörü | `~/Desktop/DisplayTuner/` |
| Hedef makine | MacBook Air M5 (arm64), macOS 27.2, Xcode kurulu, Swift 6.4.2 |
| Kullanıcı dili | Türkçe (arayüz metinleri Türkçe) |
| Ek belgeler | `SPEC.md` (genel tasarım), `baseline/display-baseline.json` (kayıtlı ekran ayarları), `~/Desktop/Coding Work/Second_Brain/BetterDisplay_RE_Spec.md` (RE sonucu) |

**Öncelik sırası (çelişki olursa):** Bu dosya > `SPEC.md` > RE dokümanı.

---

## 0. Agent için çalışma kuralları

| # | Kural |
|---|---|
| R1 | Fazları sırayla uygula (Bölüm 12). Bir faz derlenip kabul kriterleri sağlanmadan sonrakine geçme. |
| R2 | Her fazın sonunda: derle (`xcodebuild`), testleri çalıştır, uygulamayı başlat, kabul kriterlerini tek tek raporla. Doğrulanmayan maddeyi "doğrulanmadı" diye açıkça yaz. |
| R3 | **Donanıma yazma** (EQ, RGB, klavye, DDC yazma, bağlantı modu) içeren bir özelliğin ilk testinden önce kullanıcıya ne yazılacağını söyle ve onay al. Okuma sorguları serbesttir. |
| R4 | Sadece bu dosyada listelenen paket/komutları gönder. Bilinmeyen komut deneme (cihazı bozabilir). |
| R5 | Açık kaynak projelerden (GPL dahil) **kod kopyalama**. Mantık bu dosyada; sıfırdan yaz. |
| R6 | Git commit'lerinde ve PR'larda **hiçbir AI imzası olmasın** (`Co-Authored-By`, "Generated with" vb. yok). Commit'ler yalnızca kullanıcı adına görünür. Commit sadece kullanıcı isterse atılır. |
| R7 | Harici bağımlılık (SPM paketi, CocoaPods) ekleme. Sadece Apple framework'leri. |
| R8 | Private API kullanan her çağrı ayrı bir modülde, `dlsym`/`NSClassFromString` ile ve nil kontrolüyle yapılır. Yoksa özellik devre dışı kalır, uygulama çökmez. |
| R9 | Kullanıcının mevcut kurulumunu (`com.muhammed.dockapps` LaunchAgent, BetterDisplay, LinearMouse) **kendin kaldırma veya devre dışı bırakma**. Bunu uygulama, kullanıcı onayıyla yapar (Faz 6). |
| R10 | Belirsizlikte sor. Tahminle ilerleme. |

---

## 1. Ürün özeti

Tek bir macOS menü bar uygulaması. Şunların yerini alır: BetterDisplay (Pro), LinearMouse, Razer Synapse, ASUS Armoury Crate, Pusat klavye yazılımı ve `~/Library/Application Support/DockApps/dockapps.sh`.

- Dock takılınca bütün masa kurulumunu otomatik uygular.
- Harici monitörün rengini kullanıcının kaydettiği ayara getirir ve korur.
- Mouse, kulaklık ve klavyenin donanım ayarlarını yönetir, pillerini izler.
- macOS'un kendi uygulaması gibi görünür; bildirimleri iPhone tarzındadır.

---

## 2. Karar kaydı (Decision Log)

Her karar kesindir. Kod içinde ilgili yere `// D-xx` yorumu ekle.

### Genel
| ID | Karar |
|---|---|
| D-01 | Uygulama adı **DisplayTuner**. Bundle ID `com.muhammed.DisplayTuner`. |
| D-02 | Platform: macOS 15+ minimum, **sadece arm64**. |
| D-03 | Dil Swift 6 (strict concurrency açık). UI SwiftUI; menü bar ve özel pencereler AppKit. |
| D-04 | **Sandbox kapalı**, Hardened Runtime kapalı, yerel ad-hoc imza. App Store hedefi yok. |
| D-05 | Harici bağımlılık yok (R7). |
| D-06 | Proje yapısı: Xcode projesi (`DisplayTuner.xcodeproj`), tek app target + bir test target (Swift Testing). |
| D-07 | Uygulama `LSUIElement = YES` (Dock'ta ikon yok). Ana pencere açıkken de Dock'ta görünmez. |
| D-08 | Açılışta başlatma `SMAppService.mainApp` ile, varsayılan **açık**. |
| D-09 | Arayüz dili Türkçe. Metinler `Localizable.xcstrings` içinde (ileride İngilizce eklenebilsin). |

### Kapsam
| ID | Karar |
|---|---|
| D-10 | **Kapsam dışı:** pencere düzenini geri yükleme, kendi ölçekleyicimiz (sanal ekran + Metal), kolorimetre kalibrasyonu, THX Spatial, mikrofon gürültü filtresi, App Store. |
| D-11 | Desteklenen cihazlar sadece Bölüm 3'tekiler. Genel "her cihazı destekle" mimarisi kurulur ama başka cihaz sürücüsü yazılmaz. |

### Arayüz
| ID | Karar |
|---|---|
| D-20 | Menü bar: `NSStatusItem` (MenuBarExtra değil). |
| D-21 | **Tek tık** → hızlı popover. **Çift tık** → ana pencere. **Sağ tık** → menü. Tek/çift tık ayrımı: ilk tıktan sonra `NSEvent.doubleClickInterval` beklenir. |
| D-22 | Ana pencere `NavigationSplitView`, Sistem Ayarları yapısında. Sidebar: **Ekran, Mouse, Bağlı Cihazlar** (alt öğeleri cihazlar), ayraç, **Otomasyon, Bildirimler**. |
| D-23 | Bağlı Cihazlar'da bir cihaza tıklayınca o cihazın sayfası açılır. Mouse sayfasında "macOS mouse ayarları" düğmesi Mouse sekmesine götürür. |
| D-24 | Tasarım Apple-native (Bölüm 9). Apple logosu ve Apple marka adları kullanılmaz. |

### Ekran
| ID | Karar |
|---|---|
| D-30 | Bağlantı modu: private `CADisplay` / `CADisplayMode` (QuartzCore). `availableModes` içinden eşleşen mod bulunur, `setCurrentMode:` çağrılır. **Mac'te doğrulandı.** |
| D-31 | Varsayılan ve otomatik bağlantı modu: **`RGBFullRange`, 8 bpc, SDR**, mevcut çözünürlük ve Hz korunarak. Eşleştirme anahtarları: `width, height, refreshRate, isVRR, preferredScale, hdrMode` aynı + `colorMode == "RGBFullRange"` + `bitDepth == 8`. |
| D-32 | `colorMode` değerleri gerçek isimlerle eşleştirilir: `RGBFullRange`, `YCbCr444LimitedRange`, `HDR10_RGBFullRange`, `HDR10_422LimitedRange`, `HDR10_444LimitedRange` vb. (RE dokümanındaki `"rgb_full"` örnekleri **yanlış**.) `CADisplay.otherAttributes` bu macOS'ta **yok**, kullanılmaz. |
| D-33 | Renk ayarları **iki hatta** uygulanır (BetterDisplay ile aynı): (1) Donanım LUT: `CGSetDisplayTransferByTable` (kontrast, gama, kazanç, R/G/B gama ve kazanç, renk sıcaklığı, kuantizasyon, parlak alan/gölge eğrisi). (2) Compositor filtreleri: overlay pencere + `CABackdropLayer` + `CIFilter` (doygunluk, canlılık, ton, sepya). |
| D-34 | Compositor hattı **sadece** doygunluk/canlılık/ton/sepya varsayılandan farklıysa açılır. Hepsi varsayılandaysa overlay pencere hiç oluşturulmaz. |
| D-35 | Gamma tablosu boyutu: `CGDisplayGammaTableCapacity` (bu makinede 1024). Değerler [0,1] dışına çıkabilir (kayıtlı ayarda -0.0785…1.0785); bu bilinçli kontrast davranışıdır, **clamp etme**. |
| D-36 | ColorGuard: uyanma, ekran yeniden yapılandırma, kilit açma, Night Shift değişimi ve renk profili değişiminde gamma ve bağlantı modu yeniden uygulanır. Ek olarak 10 sn'de bir gamma tablosu okunur; beklenenden sapma > 0.002 ise yeniden uygulanır. |
| D-37 | DDC: `IOAVService` (private), servis `DCPAVServiceProxy` + `Location == "External"`. Her DDC yazmasından sonra en az 50 ms beklenir; okuma 3 kez denenir. |
| D-38 | **Kullanıcının kayıtlı ayarı** (`baseline/display-baseline.json`) uygulamanın ilk profili olarak içe aktarılır: adı **"Masa (Kayıtlı)"**, varsayılan profil budur. Gamma tablosu birebir (1024 değer) yüklenir; DDC değerleri birebir yazılır. |
| D-39 | Dithering (`enableDither`) ve `uniformity2D` anahtarları Ekran → Gelişmiş altında gösterilir, **varsayılan olarak dokunulmaz**. |
| D-40 | 165 Hz yoktur (dock bant genişliği). Hz listesi sadece `availableModes`'tan gelir; bilgi notu gösterilir. |
| D-41 | Ana ekran ve yerleşim `CGBeginDisplayConfiguration` + `CGConfigureDisplayOrigin` ile. Kayıtlı yerleşim: monitör ana ekran `(0,0)`, dahili ekran `(2048,196)`. |

### Mouse / Input
| ID | Karar |
|---|---|
| D-50 | Scroll ters çevirme `CGEventTap` ile; sadece **kesintili** (continuous olmayan, yani tekerlek) scroll olayları ters çevrilir. Trackpad'e dokunulmaz. |
| D-51 | Ters çevirme sadece harici bir mouse bağlıyken aktif (varsayılan). |
| D-52 | İmleç hızı ve ivme `IOHIDEventSystemClient` ile (`HIDPointerAcceleration` vb.). İvme kapatma seçeneği var. |
| D-53 | İmleç boyutu `CGSSetCursorScale` (private). Özel imleç görselleri **Faz 8'e** ertelendi. |
| D-54 | Parlaklık tuşları: imlecin bulunduğu ekranın parlaklığını değiştirir (harici ekranda DDC). Erişilebilirlik izni gerekir. |

### Cihazlar
| ID | Karar |
|---|---|
| D-60 | Her cihaz bir `actor`. Aynı cihaza aynı anda tek istek gider (FIFO kuyruk). |
| D-61 | HID erişimi `IOHIDManager`/`IOHIDDevice`. Üreticiye özel usage page'ler (`0xFF**`) Giriş İzleme izni gerektirmez (doğrulandı). |
| D-62 | Pil sorgu aralığı: 60 sn. Kulaklık pili %10 altındaysa 30 sn. Mikrofon mute durumu 1 sn (sadece kulaklık bağlıyken). |
| D-63 | Kulaklıkta önce bağlantı durumu (`0x20`, hedef `0x00`) sorgulanır; `0` ise pil sorgusu gönderilmez, cihaz "Kapalı" gösterilir. |
| D-64 | Mouse `FF AA` dönerse (uyku/desteklenmiyor) son bilinen değer zaman damgasıyla gösterilir. |
| D-65 | Flash'a yazan ayarlar (kulaklık EQ eğrisi `0x95`, klavye ayarları, mouse `50 03` kaydı) **debounce** ile: kulaklık EQ 250 ms, diğerleri 500 ms. Değer değişmediyse yazılmaz. |
| D-66 | Donanıma yazmadan önce mevcut değer okunur ve `backups/` altına zaman damgalı JSON olarak kaydedilir. Her cihaz sayfasında "Son değişikliği geri al" düğmesi. |
| D-67 | Kulaklık EQ: 10 bant, aralık -9…+6 dB, yazarken `dB + 5`. Hazır ayar değiştirme (`0x93`) eğri yazmaz; uygulamaya göre EQ sadece hazır ayar değiştirir. |
| D-68 | Klavye tuş haritası kalibrasyonla çıkarılır (Faz 7). Kalibrasyon yapılmadan tuş başına renk editörü kapalı. |

### Bildirimler
| ID | Karar |
|---|---|
| D-70 | Üç katman: sistem bildirimi (`UserNotifications`), kritik uyarı (özel `NSPanel`, iPhone "Düşük Pil" stili), HUD (Dynamic Island tarzı kapsül). |
| D-71 | Eşikler — Mouse: **%25** (bildirim), **%0** (kritik). Kulaklık: **%20, %10** (bildirim), **%5, %3** (kritik; %3'te ses de çalar). |
| D-72 | Her eşik bir kez tetiklenir. Şarja takılınca ya da pil eşiğin 5 puan üstüne çıkınca sıfırlanır. |
| D-73 | Kritik uyarıda (isteğe bağlı, varsayılan **açık**) mouse LED'i kırmızı nefes moduna geçer; pil yükselince önceki ayar geri yüklenir. |
| D-74 | Şarj tamamlanınca bildirim gönderilir. |
| D-75 | Eşikler Bildirimler sekmesinden cihaz başına değiştirilebilir. |

### Ses
| ID | Karar |
|---|---|
| D-80 | Kulaklık bağlanınca (`0x20 == 1`) varsayılan ses çıkışı kulaklığın ses cihazına geçer; bağlantı kopunca **önceki** çıkışa döner. CoreAudio ile. Ayarlardan kapatılabilir (varsayılan açık). |
| D-81 | Kulaklığın CoreAudio cihazı, USB `1532:0565` ile eşleşen ses cihazıdır (cihaz adı yerine transport + vendor/product ile eşleştir). |

### Otomasyon
| ID | Karar |
|---|---|
| D-90 | Dock algılama: `IOServiceAddMatchingNotification`, USB ürün adı **`DL-Dock`** (DisplayLink `17E9:6000`). Polling yok. |
| D-91 | Dock takılınca sırayla: monitörü bekle (en fazla 10 sn) → bağlantı modu RGB Full → ana ekran ve yerleşim → "Masa (Kayıtlı)" profili (gamma + DDC) → `batt limit 80` → mouse varsa scroll ters → HUD "Masa modu". |
| D-92 | Dock çıkınca: `batt limit 100` → scroll varsayılana. |
| D-93 | Şarj limiti `/usr/local/bin/batt` CLI ile (kurulu ve yetkili). Bulunamazsa adım atlanır ve uyarı loglanır. |
| D-94 | Masa modu sahnesi (uygulama açma, uykuyu engelleme) Faz 8'de; varsayılan kapalı. Eski script'in açtığı uygulamalar (BetterDisplay, LinearMouse, DisplayLink) **artık açılmaz**. |

### Veri
| ID | Karar |
|---|---|
| D-100 | Ayarlar `~/Library/Application Support/DisplayTuner/` altında JSON. Pil geçmişi SQLite (Foundation'daki `sqlite3` C API'si; bağımlılık yok), 7 gün tutulur. |
| D-101 | Loglama `os.Logger`, subsystem `com.muhammed.DisplayTuner`, kategori modül adı. |

---

## 3. Donanım envanteri (doğrulandı)

| Cihaz | ID | Kanal | Doğrulanan |
|---|---|---|---|
| Ugreen dock | DisplayLink `17E9:6000` "DL-Dock", VIA Labs hub `2109:*` | USB-C | Algılama |
| PR27R165QC monitör | vendor 13924, model 9984 | DP alt mode, `DCPAVServiceProxy` External | DDC okuma, CADisplay modları, RGB Full geçişi |
| ASUS ROG Gladius II Wireless | `0B05:18A0` | HID usage page `0xFF01`, report ID 0, 64 B | Pil %75, RGB okuma |
| Razer BlackShark V2 HyperSpeed | `1532:0565` | HID primary page `0xFF13`, report ID 2 (`0xFF14` koleksiyonu), 64 B | Bağlantı, pil %8, şarj, firmware 1.7 |
| PUSAT K3 Pro | `0C45:5004` (Redragon K556 ailesi) | HID usage page `0xFF1C` usage `0x92`, report ID 4, 64 B | Aktif profil, 3 profilin LED ayarları |
| Dahili ekran | displayId 1 | DisplayServices | Parlaklık okuma |

---

## 4. Kayıtlı ekran ayarı (kullanıcı onaylı)

Dosya: `baseline/display-baseline.json`. Kullanıcı bu görüntüyü "bayağı iyi" olarak onayladı; uygulamanın varsayılan profili budur (D-38).

| Alan | Değer |
|---|---|
| Bağlantı modu | `RGBFullRange`, 8 bpc, SDR, 2560×1440 @ 120 Hz |
| Çözünürlük | HiDPI 2048×1152 (framebuffer 4096×2304), ioDisplayModeID 52 |
| Ana ekran | Monitör, origin (0,0). Dahili ekran origin (2048,196) |
| DDC | Parlaklık 100/100, Kontrast 60/100, Renk preset 5, R/G/B kazanç 50/44/39, Siyah seviyesi (R) 46/255, Giriş 6, Resim modu 5. Keskinlik desteklenmiyor |
| Gamma tablosu | 1024 değer, R=G=B, doğrusal kontrast eğrisi (-0.0785 → 1.0785). BetterDisplay `contrast-ColorController = 0.157` ile üretilmiş |
| Compositor filtreleri | Hepsi varsayılan (doygunluk 1, diğerleri 0) → overlay gerekmez (D-34) |
| Dahili ekran parlaklığı | 0.455 |
| Dithering | `enableDither = Yes` (dokunma, D-39) |

**Uygulama nasıl yükler:**
1. `connectionMode` → D-31.
2. `displayMode` → `CGDisplayCopyAllDisplayModes` içinden aynı `width/height/pixelWidth/refreshRate` olan mod, `CGConfigureDisplayWithDisplayMode`.
3. `ddc` → her VCP için yaz (`0x10, 0x12, 0x14, 0x16, 0x18, 0x1A, 0x6C`). Sıra: preset (`0x14`) önce, sonra kazançlar, sonra parlaklık ve kontrast.
4. `gammaTable` → `CGSetDisplayTransferByTable(id, 1024, red, green, blue)` (D-35).

---

## 5. Tech stack

| Katman | Teknoloji |
|---|---|
| Dil / UI | Swift 6, SwiftUI, AppKit |
| Durum | `@Observable`; cihazlar `actor` |
| Menü bar | `NSStatusItem` + `NSPopover` |
| Ekran | CoreGraphics; private `CADisplay` (QuartzCore); private `IOAVService*`; `IOAVVideoInterfaceGetLinkData` |
| Compositor filtreleri | `NSWindow` + private `CABackdropLayer` + CoreImage |
| HID | IOKit `IOHIDManager` |
| USB olayları | `IOServiceAddMatchingNotification` |
| Input | `CGEventTap`, `IOHIDEventSystemClient`, private `CGSSetCursorScale` |
| Ses | CoreAudio |
| Ortam ışığı | `IOHIDEventSystemClient` ALS |
| Bildirim | UserNotifications + özel `NSPanel` |
| Başlatma | ServiceManagement (`SMAppService`) |
| Kısayol | Carbon `RegisterEventHotKey` |
| Grafik | Swift Charts |
| Depolama | JSON + SQLite (C API) |
| Test | Swift Testing |
| Log | `os.Logger` |

---

## 6. Mimari

```
DisplayTuner/
├── App/              DisplayTunerApp, AppDelegate, StatusItemController, QuickPopover/, MainWindow/
├── DesignSystem/     Ortak bileşenler: SidebarIcon, BatteryRing, GlassCard, SettingRow, HUDView, CriticalAlertView
├── Core/             DeviceRegistry, DockWatcher, AutomationEngine, SystemEvents, ProfileStore, HotkeyManager, Notifier/
├── Display/          DDCService, GammaEngine, ColorGuard, CompositorFilter, ModeService,
│                     ConnectionModeService, ArrangementService, LinkInfo, AmbientSync, NightMode
├── Input/            ScrollReverser, PointerSettings, CursorService, BrightnessKeys
├── Audio/            OutputSwitcher
├── Devices/
│   ├── HID/          HIDTransport (IOHIDDevice sarmalayıcı, istek/cevap eşleme, timeout), HIDRequestQueue
│   ├── Razer/        BlackSharkV2HS (+ Packet, Registers)
│   ├── Asus/         GladiusIIWireless (+ Packet)
│   ├── Pusat/        K3Pro (+ Packet, Checksum, KeyMap)
│   └── Battery/      BatteryMonitor, BatteryHistory, ThresholdTracker
├── Private/          Bütün private API köprüleri (dlsym / NSClassFromString) — R8
└── Resources/        Localizable.xcstrings, Assets (ikon), baseline profil
Tests/                Paket kodlama/çözme, checksum, eşik mantığı, gamma hesapları
```

**İskelet hazır (11 Kasım 2026):** `DisplayTuner.xcodeproj` ve yukarıdaki yapının tamamı oluşturuldu (114 kaynak dosyası, 7 test dosyası). Her dosyanın başında görevi, fazı ve ilgili karar numaraları yazılı. Proje Xcode'un **senkronize klasör** yapısını kullanıyor: `DisplayTuner/` ve `DisplayTunerTests/` altına eklenen her dosya otomatik olarak projeye dahil olur, `project.pbxproj`'u elle düzenleme. Boş iskelet `xcodebuild build` ve `build-for-testing` ile derleniyor. Baseline profil `DisplayTuner/Resources/BaselineProfile.json` olarak kopyalandı. Agent dosya isimlerini değiştirmez; yeni dosya gerekirse ilgili klasöre ekler.

Ortak protokol:
```swift
protocol PeripheralDevice: Actor, Identifiable {
    var kind: DeviceKind { get }            // .headset, .mouse, .keyboard, .monitor, .dock
    var displayName: String { get }
    func refresh() async                    // durum ve pil okuma
    var battery: BatteryState? { get }      // percent, isCharging, updatedAt
}
```

---

## 7. Özellikler (her ekran için tam liste)

### 7.1 Hızlı popover (tek tık)
- Her ekran için parlaklık slider'ı (harici: DDC `0x10`, dahili: `DisplayServicesSetBrightness`)
- Profil seçici (segmented): Masa (Kayıtlı), Gündüz, Gece, Film
- Pil halkaları: Mouse, Kulaklık; klavye için aktif profil
- Alt satır: "Ayarlar…" düğmesi (ana pencereyi açar)

### 7.2 Ekran sekmesi
- Ekran seçici (küçük resimli)
- **Donanım (DDC):** parlaklık, kontrast, renk preset, R/G/B kazanç, siyah seviyesi, ses. Desteklenmeyen VCP gizlenir (okuma cevabında `result != 0`).
- **Renk (LUT):** Kontrast, Gama, Kazanç, Parlak alanlar, Gölge, Renk sıcaklığı, Kuantizasyon, Gama R/G/B, Kazanç R/G/B. Her birinde ↺. Canlı R/G/B eğri önizlemesi.
- **Renk (filtre):** Doygunluk, Canlılık, Ton, Sepya (D-33, D-34).
- **Bağlantı:** renk modu, aralık, bit derinliği listesi (`availableModes`'tan, mevcut çözünürlük/Hz için); "Gerçek bağlantı" satırı (`IOAVVideoInterfaceGetLinkData`: bpc, DSC açık mı).
- **Çözünürlük ve Hz:** HiDPI işaretli liste; Hz seçici; 165 Hz notu (D-40).
- **Yerleşim:** ana ekran seçimi; sürükle-bırak yerleşim önizlemesi; "Bu yerleşimi kaydet".
- **Otomatik:** Parlaklık senkronu (ALS → DDC, eğri ve tepki hızı), Gece modu (saat veya konum, sıcaklık + parlaklık).
- **Profiller:** kaydet/yükle/sil/yeniden adlandır; profil = LUT + filtre + DDC + bağlantı modu + çözünürlük/Hz.
- **Test desenleri:** gri skala (11 kademe), siyah seviyesi (0–10), beyaz seviyesi (245–255), ten tonları, doygun renkler, gradyan. Tam ekran, ESC ile çıkış.
- **Gelişmiş:** `enableDither`, `uniformity2D` (D-39).

### 7.3 Mouse sekmesi
Scroll yönü (D-50, D-51), scroll hızı, yumuşak kaydırma, imleç hızı, ivme (kapalı / sistem / özel), imleç boyutu (1x–4x), uygulamaya göre mouse profili (hız + ivme).

### 7.4 Bağlı Cihazlar
**Kulaklık sayfası:** pil halkası, şarj, tahmini kalan süre, firmware; EQ (sürüklenebilir 10 bant eğri, Flat/Game/Music/Movie/Custom, EQ aç/kapa); uygulamaya göre EQ listesi; sidetone aç/kapa + seviye 0–15; mute göstergesi; otomatik kapanma (kapalı, 1–255 dk; hızlı seçimler 5/10/15/30/60); dongle LED (kapalı / bağlantı / pil / sadece uyarı); rahatsız etmeyin; ses iyileştirme; 7 günlük pil grafiği.

**Mouse sayfası:** pil (%25 adım), şarj, kalan süre; RGB (logo ve tekerlek ayrı: mod, renk, parlaklık 0–4); DPI (100 adım, 16.000'e kadar, 2 profil); polling (125/250/500/1000); açı yakalama; otomatik kapanma; düşük pil uyarı eşiği; "macOS mouse ayarları" düğmesi.

**Klavye sayfası:** 3 profil + aktif profil; 20 efekt; parlaklık 0–5; hız 0–3; renk / gökkuşağı; yön (sadece hareketli efektlerde); tuş başına renk editörü (klavye görseli, hazır düzenler: FPS, Kodlama, Gece); tuş atama ve makro (Faz 7); kalibrasyon sihirbazı.

**Monitör sayfası:** model, bağlantı, mevcut mod, desteklenen DDC özellikleri, "Ekran sekmesinde aç".

**Dock sayfası:** durum, bağlı cihazlar, "Otomasyon ayarları".

### 7.5 Otomasyon sekmesi
Dock takılınca/çıkınca adımlarının listesi (D-91, D-92), her adım aç/kapa; uygulamaya göre kurallar (EQ preset, mouse profili); kısayollar (D-110).

### 7.6 Bildirimler sekmesi
Cihaz başına eşikler (D-71), kritik uyarıda mouse LED'i (D-73), şarj tamamlandı bildirimi, HUD'lar aç/kapa.

### 7.7 Kısayollar (varsayılan)
| ID | Kısayol | İşlev |
|---|---|---|
| D-110 | ⌃⌥1…4 | Ekran profilleri |
| | ⌃⌥E | Kulaklık EQ preset döngüsü |
| | ⌃⌥K | Klavye profil döngüsü |
| | Parlaklık tuşları | İmlecin olduğu ekran (D-54) |

---

## 8. Bildirimler (tasarım ve metin)

### 8.1 Metinler
| Durum | Katman | Başlık | Metin |
|---|---|---|---|
| Kulaklık %20 / %10 | Sistem | Kulaklık Pili Azalıyor | BlackShark V2'de %{n} pil kaldı.{ Yaklaşık X saat kullanılabilir.} |
| Kulaklık %5 / %3 | Kritik | Düşük Pil | BlackShark V2'de %{n} pil kaldı. Kulaklığınızı şarj edin. [Tamam] |
| Mouse %25 | Sistem | Mouse Pili Azalıyor | ROG Gladius II'de %25 pil kaldı. |
| Mouse %0 | Kritik | Düşük Pil | ROG Gladius II'nin pili bitmek üzere. [Tamam] |
| Şarj tamam | Sistem | Şarj Tamamlandı | {cihaz} tamamen şarj oldu. |
| Mikrofon | HUD | Mikrofon Kapalı | (SF Symbol `mic.slash.fill`) |
| Ses çıkışı | HUD | {cihaz adı} | (`headphones`) |
| Profil | HUD | {profil adı} | (`sun.max.fill`) |
| Dock | HUD | Masa Modu | (`display`) |

"Yaklaşık X saat": son 24 saatlik düşüş hızından; veri yetersizse cümle gösterilmez.

### 8.2 Kritik uyarı (iPhone "Düşük Pil" stili)
- `NSPanel`, `.nonactivatingPanel`, seviye `.floating` (tam ekran uygulamaların üstünde: `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`)
- 270 pt genişlik, 14 pt köşe, Liquid Glass (`.glassEffect()`; yoksa `.ultraThinMaterial`)
- İçerik: üstte kırmızı pil SF Symbol (`battery.0percent`, 44 pt), başlık (`.headline`), metin (`.callout`, ortalı), ince ayraç, tam genişlik "Tamam" düğmesi
- Açılış: ölçek 0.9→1.0 + opaklık, `.spring(duration: 0.35)`; sistem uyarı sesi (`NSSound.beep` değil, `NSSound(named: "Funk")`)
- Kendiliğinden kapanmaz.

### 8.3 HUD (Dynamic Island tarzı)
- Ekranın üst ortasında, menü bar'ın hemen altında, siyah kapsül (koyu modda da siyah), yükseklik 36 pt, köşe yarıçapı 18
- Solda SF Symbol, ortada metin, gerekirse sağda küçük ilerleme/pil halkası
- Açılış: genişlikten büyüyerek (`.spring`), 2 sn sonra küçülerek kapanır
- `ignoresMouseEvents = true`

### 8.4 Sistem bildirimleri
- `UNUserNotificationCenter`, kategori `battery`; thread identifier cihaz ID'si (aynı cihazın bildirimleri gruplanır)
- Ek resim olarak pil halkası (`UNNotificationAttachment`, PNG, çalışma anında çizilir)
- Kritik seviyeler hem sistem bildirimi hem kritik uyarı olarak gider (Bildirim Merkezi'nde iz kalsın)

---

## 9. Tasarım sistemi (Apple-native)

| Öğe | Kural |
|---|---|
| Malzeme | macOS 26+: `.glassEffect()` (popover, HUD, kritik uyarı). Eski sürüm: `.ultraThinMaterial` |
| Pencere | `NavigationSplitView`, `.toolbar(removing: .title)` değil; Sistem Ayarları gibi başlık sağ panelde. Minimum boyut 720×520 |
| Formlar | `Form` + `.formStyle(.grouped)` |
| İkonlar | Sadece SF Symbols. Sidebar ikonları: 20×20 renkli yuvarlatılmış kare (köşe 5) üzerinde beyaz sembol — Ekran mavi `display`, Mouse gri `computermouse.fill`, Bağlı Cihazlar yeşil `cable.connector`, Otomasyon mor `gearshape.2.fill`, Bildirimler kırmızı `bell.badge.fill` |
| Renk | Sistem vurgu rengi; pil: >%20 yeşil, %10–20 sarı, <%10 kırmızı (`.green/.yellow/.red`) |
| Yazı | Sistem fontu (SF Pro), metin stilleri; sabit punto yok |
| Kontroller | Native `Slider`, `Toggle` (switch), segmented `Picker`, `Stepper`, `ColorPicker` |
| Animasyon | `.spring`, `.smooth`; sayılarda `.contentTransition(.numericText())`; "Hareketi azalt" açıkken kapalı |
| Boşluk | 8 pt ızgara |
| Pil halkası | iPhone Piller widget'ı: 4 pt kalınlıkta halka, ortada cihaz SF Symbol'ü, altında yüzde |
| Uygulama ikonu | macOS squircle şablonu, katmanlı: koyu lacivert zemin, ortada monitör, üstünde parlaklık güneşi; cam vurgu. (Faz 8; o zamana kadar SF Symbol tabanlı geçici ikon) |
| Erişilebilirlik | Bütün kontrollerde VoiceOver etiketi; renk bilgisi her zaman yazıyla da |

Referans ekranlar: Kontrol Merkezi (popover), Sistem Ayarları → Ekranlar / Bluetooth / Fare (pencere), iPhone Piller widget'ı, iOS Düşük Pil uyarısı, Dynamic Island.

---

## 10. Protokoller (doğrulanmış)

> ✅ = Mac'te gerçek donanımda okuma ile doğrulandı. ⚠️ = kaynaktan alındı, ilk kullanımda R3'e göre test edilecek.

### 10.1 DDC/CI
- Servis: `IOServiceMatching("DCPAVServiceProxy")`, `Location == "External"` → `IOAVServiceCreateWithService(kCFAllocatorDefault, service)`
- `IOAVServiceWriteI2C(av, 0x37, 0x51, buf, len)` / `IOAVServiceReadI2C(av, 0x37, 0x51, buf, len)`
- **Get VCP:** `[0x82, 0x01, vcp, chk]`, `chk = 0x6E ^ 0x51 ^ 0x82 ^ 0x01 ^ vcp`. 50 ms bekle, 12 B oku. Cevap: `[2]=0x02`, `[3]=sonuç (0 OK)`, `[4]=vcp`, `[6..7]=max`, `[8..9]=mevcut` (big endian). ✅
- **Set VCP:** `[0x84, 0x03, vcp, hi, lo, chk]`, `chk = 0x6E ^ 0x51 ^ (diğer byte'ların XOR'u)`. ⚠️
- Kullanılan VCP'ler: `0x10` parlaklık, `0x12` kontrast, `0x14` preset, `0x16/0x18/0x1A` R/G/B kazanç, `0x6C` siyah seviyesi R, `0x62` ses, `0x60` giriş (sadece oku), `0xDC` resim modu (sadece oku). `0x87` keskinlik desteklenmiyor.

### 10.2 Bağlantı modu (CADisplay) ✅
```
cls = NSClassFromString("CADisplay"); displays = [cls displays]
d = displays.first { d.productName == "PR27R165QC" }  // veya displayId == CGDirectDisplayID
cur = d.currentMode; modes = d.availableModes          // bu monitörde 258 mod
pick = modes.first { aynı width,height,refreshRate,isVRR,preferredScale,hdrMode
                     && colorMode == "RGBFullRange" && bitDepth == 8 }
[d setCurrentMode: pick]                               // ~3 sn içinde uygulanır, çözünürlük ve Hz korunur
```
CADisplayMode özellikleri (KVC ile okunur, önce `responds(to:)` kontrolü): `width, height, refreshRate, isVRR, bitDepth, colorMode, colorModeIsYCbCr, hdrMode, colorGamut, preferredScale`.
Bu monitörde 2560×1440 için mevcut: 120 Hz `RGBFullRange` 8, `YCbCr444LimitedRange` 8, `HDR10_422LimitedRange` 12; 60 Hz `RGBFullRange` 8/10, `YCbCr444LimitedRange` 8/10, `HDR10_RGBFullRange` 10/12, `HDR10_444LimitedRange` 10, `HDR10_422LimitedRange` 12.

### 10.3 Link bilgisi ⚠️
`IOAVVideoInterfaceCreateWithService` (servis: monitörün `IOMobileFramebuffer`/`AppleCLCD2` düğümünün `DCPAVVideoInterfaceProxy` çocuğu) → `IOAVVideoInterfaceGetLinkData(vi, buf512)`. Offsetler (RE dokümanından): `+0x08` u32 bpc, `+0x30` u32 genişlik, `+0x50` u32 yükseklik, `+0x62` u8 Hz, `+0x80..+0xFF` DSC PPS (hepsi 0 ise DSC kapalı). Sadece okuma; offset'ler ilk çalıştırmada mantık kontrolünden geçmeli (bpc ∈ {6,8,10,12}, genişlik 2560).

### 10.4 Compositor filtreleri ⚠️
- Ekran başına bir `NSWindow`: `.borderless`, `level = CGShieldingWindowLevel()`, `ignoresMouseEvents = true`, `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]`, `isOpaque = false`, `hasShadow = false`, `backgroundColor = NSColor(white: 0, alpha: 0.001)` (0 olursa WindowServer pencereyi atlar).
- İçerik katmanı: `NSClassFromString("CABackdropLayer")`; KVC: `enabled=true, windowServerAware=true, allowsInPlaceFiltering=true, ignoresScreenClip=true, captureOnly=false, reducesCaptureBitDepth=false, disableFilterCache=true, bleedAmount=0, marginWidth=0, scale=backingScaleFactor`, `filters = [CIFilter]`.
- Filtre sırası: `CIColorControls` (inputSaturation = doygunluk, varsayılan 1; inputContrast 1; inputBrightness 0) → `CIVibrance` (inputAmount) → `CIHueAdjust` (inputAngle, radyan) → `CISepiaTone` (inputIntensity).
- Kontrast, gama, kazanç, sıcaklık bu hatta **değil**, LUT hattında (D-33).

### 10.5 LUT (gamma) hesapları
Giriş `x ∈ [0,1]`, kanal başına:
1. Kazanç: `x * (1 + gain + cGain)`
2. Kontrast `c ∈ [-1,1]`: `(x - 0.5) * (1 + c) + 0.5`. Kayıtlı tablo bu formülle `c = 0.15708` için birebir tutuyor (x=0 → -0.0785, x=1 → 1.0785). Yine de **kayıtlı profil tablosu dosyadan yüklenir**; formül yeni ayarlar ve slider gösterimi için (slider'da kayıtlı profil "Kontrast 0.157" olarak görünür).
3. Gama `g ∈ [-1,1]`: `x ^ (1 / max(g + 1, 0.01))`; kanal gaması aynı formül.
4. Parlak alan / gölge: `x < 0.5` için gölge eğrisi `x + s * x * (1 - 2x)`, `x ≥ 0.5` için parlak alan `x + h * (1 - x) * (2x - 1)`.
5. Renk sıcaklığı `t ∈ [-1,1]`: çarpanlar `R = min(t,0) + 1`, `G = 1 - |0.5 t|`, `B = 1 - max(t,0)`.
6. Kuantizasyon `q ∈ [0,1]` (1 = kapalı): seviye `L = floor(254 * q^3) + 2`, `round(x * (L-1)) / (L-1)`.
Kayıtlı profilin dışındaki her değişiklikte tablo bu sırayla yeniden üretilir; [0,1] dışı değerler clamp edilmez (D-35).

### 10.6 Razer BlackShark V2 HyperSpeed
- `IOHIDManager` eşleme: `1532:0565`, primary usage page `0xFF13`.
- **İstek** — output report ID 2, 64 B:

| Byte | Değer |
|---|---|
| 0 | `0x02` |
| 2 | `0x60 \| (seq & 0x1F)` |
| 6 | `4 + n` (n = parametre sayısı) |
| 9 | hedef: `0x80` kulaklık, `0x00` dongle |
| 10 | komut |
| 12 | n |
| 13… | parametreler |
| 62 | byte 0–61 XOR |

- **Cevap** — input report ID 2 (`IOHIDDeviceRegisterInputReportCallback`): `[1]` durum, `[2]` seq (5 bit eşleşmeli), `[8]=0x80`, `[9]` hedef, `[10]` komut, `[11]=1`, `[12]` n, `[13…]` veri. Timeout 800 ms.
- Durum: `02` OK, `01` meşgul (tekrar dene), `04` kulaklık cevap vermedi, `05` desteklenmiyor, `09` bu hedefte yok.
- Yazma cevabında veri `00` ise kabul edildi.

| Oku | Yaz | Hedef | Anlam | |
|---|---|---|---|---|
| `0x02` | | 00/80 | firmware (4 B) | ✅ 1.7 |
| `0x20` | | 00 | kulaklık bağlı (0/1) | ✅ |
| `0x21` | | 80 | pil % (min 100) | ✅ |
| `0x2A` | | 80 | şarj (0/1+) | ✅ |
| `0x13` | `0x93` | 80 | EQ preset `00/07/08/09/FF` | ⚠️ |
| `0x15` | `0x95` | 80 | 10 bant; yazma `dB+5`, okuma dB (işaretli byte) | ⚠️ |
| `0x1E` | `0x9E` | 80 | EQ aç/kapa | ⚠️ |
| `0x1D` | `0x9D` | 80 | ses iyileştirme | ⚠️ |
| `0x18` | `0x98` | 80 | sidetone aç/kapa | ⚠️ |
| `0x19` | `0x99` | 80 | sidetone 0–15 | ⚠️ |
| `0x2C` | `0xAC` | 80 | otomatik kapanma dk | ⚠️ |
| `0x27` | `0xA7` | 80 | rahatsız etmeyin | ⚠️ |
| `0x55` | | 80 | mikrofon mute | ⚠️ |
| `0x66` | `0xE6` | 00 | dongle LED 0–3 | ⚠️ |

### 10.7 ASUS ROG Gladius II Wireless
- Eşleme `0B05:18A0`, usage page `0xFF01`. Output report ID **0**, 64 B (buffer report ID içermez). Cevap input report; ilk 2 byte komutu tekrarlar. `FF AA` = hata.
- İndeksler cevap buffer'ının kendisine göredir (report ID yok).

| Komut | Yön | Cevap / anlam | |
|---|---|---|---|
| `12 07` | oku | `[4]` pil adımı (×25 = %), `[5]` otomatik kapanma, `[9]` şarj (>0) | ✅ %75 |
| `12 03 <bölge>` | oku | `[4]` mod, `[5]` parlaklık 0–4, `[6..8]` RGB | ✅ |
| `51 28 <bölge> 00 <mod> <parl> <R> <G> <B> <yön> <rastgele> <hız>` | yaz | aydınlatma | ⚠️ |
| `50 03` | yaz | ayarları kaydet | ⚠️ |
| `51 31 04 00 <oran>` | yaz | polling | ⚠️ |
| `51 31 06 00 <0/1>` | yaz | açı yakalama | ⚠️ |
| `51 37 00 00 <kapanma> 00 <düşük pil>` | yaz | güç | ⚠️ |
| `12 04 00` | oku | DPI/ayarlar | ⚠️ |

Bölgeler `00` logo, `01` tekerlek, `03` hepsi. Modlar `00` sabit, `01` nefes, `02` renk döngüsü, `04` tepki, `06` pil durumu, `F0` kapalı. Mevcut: iki bölge sabit, parlaklık 2, `#FF00FD`.

### 10.8 PUSAT K3 Pro (Redragon K556 protokolü)
- Eşleme `0C45:5004`, 64 B output report olan arayüz (usage page `0xFF1C`). Report ID **4** (buffer'ın ilk byte'ı `0x04`). Cevap input report ID 4.
- **Checksum:** byte 1 (düşük) ve byte 2 (yüksek) = byte 3…63 toplamı (16 bit, little endian). Örnek: `04 2f 00 03 2c` (0x03+0x2C = 0x2F). ✅
- Yazmalar `04 01 00 01` (başlat) ve `04 02 00 02` (bitir) arasında. ⚠️

| İşlem | Byte 3, 4, 5 | Cevap | |
|---|---|---|---|
| Aktif profil oku | `03 2C 00` | `[18]` = profil − 1 | ✅ (1) |
| LED oku (profil 1/2/3) | `05 38 00` / `05 38 2A` / `05 38 54` | `[8]` mod, `[9]` parlaklık 0–5, `[10]` 3−hız, `[11]` yön (`FF` sol, `00` sağ), `[12]` gökkuşağı, `[13..15]` RGB | ✅ |
| Ayar yaz | `06 01 <offset>` + veri `[8]…` | yön offsetleri: profil 1 `03`, 2 `2D`, 3 `57` | ⚠️ |

Mod kodları: `01` yatay dalga, `02` nabız, `03` kasırga, `04` renkli nefes, `05` nefes, `06` sabit, `07` tepki tek, `08` tepki dalgalanma, `09` tepki yatay, `0A` şelale, `0B` girdap, `0C` dikey dalga, `0D` sinüs, `0E` vorteks, `0F` yağmur, `10` çapraz dalga, `11` renkli tepki, `12` dalgalanma, `13` kapalı, `14` özel.
Mevcut: profil 1 aktif (yatay dalga, gökkuşağı, parlaklık 5, hız 2, sağ); profil 2–3 özel.
Mod/parlaklık/hız/renk offsetleri ile tuş başına renk, tuş atama, makro paket düzeni: referans `github.com/dokutan/rgb_keyboard` (`writers.cpp`, `data.cpp`) — **mantığı oku, kodu kopyalama** (R5). Yazmadan önce aynı alanı oku-karşılaştır ile doğrula.

---

## 11. İzinler ve ilk açılış

| Sıra | İzin | Ne zaman | Yoksa |
|---|---|---|---|
| 1 | Bildirimler | İlk açılış | Sadece HUD ve kritik uyarı çalışır |
| 2 | Erişilebilirlik | Mouse sekmesi ilk açılışında veya scroll ters çevirme açılınca | Scroll ve parlaklık tuşları kapalı |
| 3 | Konum (isteğe bağlı) | Gece modu "konuma göre" seçilince | Saat tabanlı gece modu |

İlk açılış sihirbazı (Apple onboarding stili, 3 sayfa): hoş geldin → izinler → eski kurulumu tespit (LaunchAgent `com.muhammed.dockapps` çalışıyorsa "Devre dışı bırakılsın mı?" — onaylanırsa `launchctl bootout gui/$UID/com.muhammed.dockapps` ve plist `~/Library/LaunchAgents/disabled/` altına taşınır; silinmez).

---

## 12. Fazlar ve kabul kriterleri

| Faz | Kapsam | Kabul kriterleri |
|---|---|---|
| **1. İskelet** | Proje, D-01…D-09; status item (D-20, D-21); popover; ana pencere + sidebar boş sayfalar; DesignSystem bileşenleri; DockWatcher; DDCService (oku + parlaklık yaz); dahili parlaklık | Derleniyor; tek tık popover, çift tık pencere, sağ tık menü çalışıyor; dock tak/çıkar logda görünüyor; popover'dan iki ekranın parlaklığı değişiyor |
| **2. Cihaz okuma + bildirimler** | HIDTransport; Razer/ASUS/Pusat okuma; BatteryMonitor + ThresholdTracker (birim testli); 3 bildirim katmanı; OutputSwitcher (D-80); mikrofon HUD | Üç cihaz sayfasında canlı veri; eşik testleri geçiyor; test düğmesiyle (Bildirimler sekmesinde "Örnek göster") üç katman da görülüyor; kulaklık aç/kapa ile ses çıkışı değişiyor |
| **3. Cihaz yazma** | Kulaklık EQ/sidetone/güç/LED; mouse RGB/DPI/polling/güç; klavye profil/efekt/yön/parlaklık/renk; yedek + geri al (D-66); uygulamaya göre EQ | Her yazma R3 onayıyla test edildi ve tekrar okunarak doğrulandı; geri al çalışıyor |
| **4. Input** | ScrollReverser, PointerSettings, CursorService, BrightnessKeys, uygulamaya göre mouse profili | Mouse tekerleği ters, trackpad doğal; hız/ivme ayarı hissediliyor; parlaklık tuşları imlecin ekranında çalışıyor |
| **5. Ekran** | ConnectionModeService (D-30, D-31); ModeService; Arrangement; GammaEngine + ColorGuard; CompositorFilter; profiller + **"Masa (Kayıtlı)" baseline içe aktarma** (D-38); test desenleri; LinkInfo; AmbientSync; NightMode; kısayollar | Baseline yüklenince gamma tablosu dosyayla birebir (max sapma < 0.001), DDC değerleri aynı, mod RGBFullRange; uyku/uyanma sonrası korunuyor; doygunluk filtresi görünür ve mouse olayları geçiyor |
| **6. Otomasyon** | AutomationEngine (D-91…D-93); Otomasyon sekmesi; ilk açılış sihirbazı ve eski kurulum devre dışı bırakma | Dock takınca tüm adımlar sırayla ve < 15 sn'de; çıkarınca batt %100; eski LaunchAgent kullanıcı onayıyla devre dışı |
| **7. Klavye ileri** | Kalibrasyon; tuş başına renk editörü; tuş atama ve makro | Kalibrasyon kaydı; seçilen tuşlar doğru renkte |
| **8. Cilalama** | Pil geçmişi grafikleri; kalan süre; masa modu sahnesi; özel imleçler; dışa/içe aktarma; uygulama ikonu; erişilebilirlik turu | VoiceOver ile tüm sayfalar gezilebiliyor; dışa aktarılan dosya içe aktarılınca aynı durum |

Her faz sonunda raporda: değişen dosyalar, kabul kriterleri ✅/❌, doğrulanamayanlar, kullanıcının yapması gereken testler.

---

## 13. Test stratejisi

- **Birim testleri (zorunlu):** Razer paket kodlama + XOR; Razer cevap eşleme (seq, hedef, komut); ASUS cevap çözme; Pusat checksum (örnek `04 2f 00 03 2c` ve `04 09 01 06 01 03 … ff` → byte1-2 = `09 01`); DDC checksum; ThresholdTracker (eşik bir kez, şarjda sıfırlama, +5 histerezis); LUT hesapları (kimlik, kontrast, kuantizasyon); EQ `dB+5` dönüşümü.
- **Donanım testleri:** okuma testleri serbest; yazma testleri R3.
- **Manuel kontrol listesi** her faz raporunda.

---

## 14. Riskler ve önlemler

| Risk | Önlem |
|---|---|
| Private API macOS güncellemesinde değişir | R8; açılışta API varlık kontrolü; özellik gri gösterilir |
| `setCurrentMode:` sonrası çözünürlük kayar | Uygulama sonrası CG modu kontrol edilir; değiştiyse kayıtlı mod yeniden uygulanır |
| Overlay filtre performansı / DRM içerik | Sadece gerekirse açılır (D-34); kapatma düğmesi |
| Flash yıpranması | D-65 |
| Yanlış paket | R4, D-66, yazmadan önce okuma |
| Klavye düzeni farklı | D-68 |
| `batt` yok | D-93 |

---

## 15. Kullanıcıya sorulacaklar (agent kendi karar vermez)

1. Tasarımda Liquid Glass görünümünün beğenilip beğenilmediği (Faz 1 sonunda ekran görüntüsüyle).
2. Her donanım yazmasının ilk testi (R3).
3. Eski LaunchAgent'ın devre dışı bırakılması (Faz 6).
4. Kalibrasyon sırasında tuş işaretleme (Faz 7).
5. Renk profillerinin (Gündüz/Gece/Film) değerleri: varsayılan olarak "Masa (Kayıtlı)" kopyalanır, kullanıcı kendisi ayarlar.

---

## 16. Kaynaklar (sadece mantık)

| Konu | Kaynak |
|---|---|
| Razer HyperSpeed | github.com/justik13/razer-blackshark-v2-hyperspeed-webhid, github.com/Ar4ikov/openrazer-win |
| ASUS ROG | github.com/seerge/g-helper |
| Redragon/SONiX | github.com/dokutan/rgb_keyboard |
| BetterDisplay RE | `~/Desktop/Coding Work/Second_Brain/BetterDisplay_RE_Spec.md` (D-32'deki düzeltmelerle) |
| DDC | MonitorControl, m1ddc |
| Scroll/ivme | LinearMouse |

---

## 17. İlerleme (12 Kasım 2026)

**Derleme:** `xcodebuild build` ✅ · `xcodebuild test` ✅ (22 test). Uygulama gerçek donanımda çalıştırıldı.

| Faz | Durum | Yapılanlar | Kalan |
|---|---|---|---|
| 1 | ✅ | Status item (tek/çift/sağ tık), popover (iki ekran parlaklığı), ana pencere + sidebar, tasarım bileşenleri, DockWatcher (dock algılandı ✅), DDCService, dahili parlaklık, açılışta başlatma | Kullanıcının tık davranışını ve görünümü elle kontrol etmesi |
| 2 | 🟡 Büyük kısmı | HIDTransport + istek kuyruğu; Razer/ASUS/Pusat sürücüleri (okuma); BatteryMonitor (gerçek okuma: kulaklık %48, mouse %75 ✅); ThresholdTracker; bildirim katmanları (sistem, kritik uyarı, HUD); popover pil halkaları; OutputSwitcher; cihaz sayfaları (Bağlı Cihazlar, Kulaklık, Mouse, Klavye) ve Bildirimler sayfası ("Örnek Göster"); sağ tık menüsünde "Örnek Bildirimleri Göster" | Mikrofon mute HUD'ı (1 sn sorgu, D-62); bildirimlerin görsel kontrolü; kulaklık aç/kapa ile ses çıkışı geçişinin elle testi |
| 3 | 🟡 Kulaklık + mouse ✅ | Kullanıcı onayı alındı. Aynı değerle yazma testi gerçek donanımda ✅ (sidetone 15, EQ preset Film, mouse logo ışığı). Kulaklık sayfası: EQ hazır ayarı + 10 bant (Özel'de, 250 ms debounce), sidetone aç/kapa + seviye, otomatik kapanma, dongle ışığı. Mouse sayfası: logo/tekerlek efekti, renk, parlaklık (canlı + 500 ms sonra `50 03` kayıt) | Klavye yazma (Giriş İzleme izni gerekli; offset'ler: mod 00/2A/54, parlaklık 01/2B/55, hız 02/2C/56, yön 03/2D/57 — `04 chk 00 06 01 <offset> 00 00 <değer>`); mouse DPI/polling; yedek + geri al (D-66); uygulamaya göre EQ; kritikte mouse LED'i (D-73) |
| 4 | 🟡 Çekirdek | ScrollReverser (CGEventTap, sadece continuous=0 tekerlek olayları), Mouse sekmesi (anahtar varsayılan kapalı, LinearMouse açıkken kilitli + "LinearMouse'u Kapat", Erişilebilirlik izni durumu) | Gerçek testte doğrulanmadı (izin + LinearMouse kapatma kullanıcıda); imleç hızı/ivme, imleç boyutu, parlaklık tuşları, uygulamaya göre mouse profili |
| 5 | 🟡 Büyük kısmı | CADisplayBridge, ConnectionModeService (+ yardımcı süreç, D-130), LUTMath (baseline formülle < 0.001 ✅), GammaEngine, DisplayProfile, BaselineImporter, ProfileStore, ColorGuard, ModeService (Hz seçici popover + Ekran sekmesi, D-126), **Ekran sekmesi** (renk yönetimi anahtarı, renk modu, Hz, DDC slider'ları, LUT slider'ları canlı) | CompositorFilter (doygunluk/ton/canlılık/sepya), Arrangement (ana ekran — şu an macOS kendisi yapıyor), test desenleri, AmbientSync, NightMode, kısayollar, profil ekle/sil arayüzü. Not: Ekran sekmesindeki renk modu listesi süreç içi CADisplay'den gelir (bayat olabilir, D-127) |
| 6 | 🟡 Çekirdek | AutomationEngine (dock → DDC/pil yenileme, "Masa Modu" HUD); dock tak/çıkar testi ✅; mikrofon HUD'ı (D-62) | Otomasyon sekmesi, ilk açılış sihirbazı, eski LaunchAgent'ı uygulamadan devre dışı bırakma (şu an elle `launchctl bootout` ile durduruldu, silinmedi) |
| 7–8 | 🟡 | Uygulama ikonu, `/Applications` kurulumu (`scripts/install.sh`), Otomasyon sekmesi (eski script durdur/başlat), profiller (seç/kopyala/yeniden adlandır/sil, popover seçici), test desenleri, kısayollar (⌃⌥1–4, ⌃⌥E), klavye efekt/parlaklık/hız/yön, mouse hızı/ivme/imleç boyutu, doygunluk/canlılık/ton/sepya filtresi | Tuş başına renk + kalibrasyon (Faz 7), klavye rengi, mouse DPI/polling, pil geçmişi grafiği ve kalan süre, gece modu, ortam ışığı senkronu, parlaklık tuşları, uygulamaya göre EQ/mouse profili, ilk açılış sihirbazı, yedek + geri al (D-66), dışa/içe aktarma |

**D-136:** Ters kaydırma açıkken LinearMouse otomatik kapatılır (3 sn'lik bekçi) ve izin gelince dinleyici kendiliğinden başlar. **D-137:** Ana pencere açıkken uygulama Dock ve ⌘Tab'da görünür (`.regular`), kapanınca `.accessory` (D-07'yi günceller). **D-138:** İmleç hızı 0–10 (macOS'un kendi sınırı 3). **D-139:** Cihaz sayfaları açıkken pil/bağlantı durumu 5 sn'de bir yenilenir. Çözünürlük/ölçek seçici + çözünürlük başına Hz (popover ve Ekran sekmesi, `DisplayModeControls`).

**D-140:** Scroll ters çevirmede alanlar **önce hepsi okunur, sonra yazılır**. `DeltaAxis` yazılınca CG `PointDelta`/`FixedPtDelta`'yı yeniden hesaplar; tek tek oku-yaz yapınca piksel değerleri iki kez çevrilip eski haline dönüyordu (satır değeri ters, uygulamaların kullandığı piksel değeri düz → "çalışmıyor"). Gerçek tekerlek kaydı ile teşhis edildi.

**D-141:** Yerel imza sertifikası: kullanıcı `scripts/create-signing-cert.sh`'ı bir kez çalıştırır (agent'ın Anahtar Zinciri'ne yazması güvenlik kuralıyla engellendi). `install.sh` sertifika varsa onunla imzalar; izinler güncellemelerde korunur. **D-142:** "Ana ekran" anahtarı (popover + Ekran sekmesi; `ArrangementService.makeMain`, varsayılan açık, profil uygulanırken de çalışır). **D-143:** HiDPI 2048×1152'de bu bağlantıda gerçek kare hızı 60 (CADisplay bağlantıyı 120'ye alabilse de `NSScreen.maximumFramesPerSecond` = 60 ölçüldü). BetterDisplay'in HiDPI@120'si büyük ihtimalle sanal EDID (`IOAVServiceSetVirtualEDIDMode`) ile; ayrı RE işi. Gerçek 120 Hz: 2560×1440 (HiDPI değil).

**D-144:** Hz seçici monitörün herhangi bir masaüstü çözünürlüğünde sunduğu **bütün** Hz'leri gösterir (bu bağlantıda 60/75/120). Mevcut ölçekte olmayan Hz seçilirse `ModeService.bestResolution` ile önce aynı görünür boyuta (HiDPI önce), yoksa en büyük uygun çözünürlüğe geçilir ve alt satırda açıklanır.

**D-145:** Popover'da monitör modu kartı yok (sadece Ekran sekmesinde); pil halkalarına tıklayınca ana pencere ilgili cihaz sekmesinde açılır. **D-146:** İmleç görünümü (Mouse sekmesi): şekil (Sistem/Ok/Kalın ok/Nokta) + dolgu/kenar rengi; `CGSRegisterCursorWithImages` ile `com.apple.coregraphics.Arrow` ve `ArrowCtx` değiştirilir (Mousecape yöntemi; kayıt dönüşü 0 doğrulandı), "Sistem" = `CGSRemoveRegisteredCursor`. Diğer imleçler (I-beam, el) henüz değişmiyor.

**D-147:** Renk seçimi sistem `ColorPicker` yerine `InlineColorPicker` (düğmenin sağında popover: 20'lik palet + ton/doygunluk/parlaklık). **D-148:** Pil uyarı eşikleri Bildirimler sekmesinden cihaz başına seçilir (UserDefaults `alerts.<kind>`; kulaklık seçenekleri 50…3, mouse 75/50/25/0); %5 ve altı kritik. D-71 artık varsayılan değerdir.

**D-149:** Popover renk paleti yerine pencere içi renk paneli: renk kutusuna tıklayınca ana pencere sağa 300 pt genişler, `ColorSidePanel` (ton/doygunluk çarkı, parlaklık, HEX, RGB, ekrandan seç `NSColorSampler`, hazır renkler, son kullanılanlar) açılır; kapanınca pencere eski genişliğe döner. Durum `MainWindowState.colorPanel` (`ColorPanelHost`), ortamdan `\.colorPanel` ile okunur; sayfa değişince panel kapanır. **D-150:** Ekran sekmesinin üstünde ekran seçici (BetterDisplay gibi): PR27R165QC seçiliyse eski sayfa; MacBook ekranı/diğer ekran seçiliyse parlaklık (dahili) + çözünürlük/Hz + "Ana ekran". `ArrangementService.setMain` tercihi `monitorIsMain`'e yazar (dahili ana yapılırsa monitör takılınca ana yapılmaz). Diğer ekranların modları profile kaydedilmez.

**D-151:** Ayarlar sayfası (sidebar): tema Sistem/Açık/Koyu (`NSApp.appearance`, `appAppearance`), dil Sistem/Türkçe/English. İlk açılış İngilizce (`AppleLanguages=["en"]` uygulama alanına, `languageChosen` yoksa); kullanıcı seçimi kalıcı, değişince uygulama yeniden başlar. Çeviriler `Localizable.xcstrings` (kaynak tr, en çeviri; `xcodebuild -exportLocalizations/-importLocalizations`). **D-152:** Kulaklık EQ hazır ayarları uygulama tarafında (`HeadsetEQStore`, 14 eğri + kullanıcı ayarları, UserDefaults `eq.*`): seçim her zaman `0x93 FF` (Özel) + `0x95` eğri yazar, böylece her ayar düzenlenebilir ve Sıfırla ile döner. Eğriler RTINGS ölçümüne göre (parlak, bas ≈ -2 dB). Okuma işaretli dB, yazma dB+5 donanımda doğrulandı (00 yaz → 05 gönder → 00 oku). Eski döndürülmüş dikey Slider'lar dokunma alanı çakışmasıyla 16K'yı kilitliyordu → `EQCurveView` (tek DragGesture, en yakın bant). Sidetone seviyesi donanımda 0–15 (16+ → durum 05 unsupported), arayüzde %0–100. **D-153:** Premium görünüm: sayfa rengine göre `PageBackground` ışıması, cihaz sayfalarında `DeviceHero` kartı. Geliştirici bayrakları: `--args -DTOpenPage <sayfa> -DTSnapshot <png>` (README görselleri; ekran kaydı izni gerektirmez). **D-154:** Menü bar popover'ı ilk tıkta (mouse down) hemen açılır; eskiden çift tıkı ayırt etmek için `doubleClickInterval` (~0,5 sn) bekleniyordu. Çift tıkta popover kapanır, ana pencere açılır. Parlaklık değerleri açılışta önceden okunur.

**Kurulum ve izinler (D-135):** Uygulama `./scripts/install.sh` ile `/Applications/DisplayTuner.app`'e kurulur. İmza ad-hoc olduğu için (geliştirici sertifikası yok) macOS Erişilebilirlik iznini kendiliğinden listelemez ve **her yeni kurulumda izin geçersiz olur**: `tccutil reset Accessibility com.muhammed.DisplayTuner` → Sistem Ayarları → Erişilebilirlik → "+" ile `/Applications/DisplayTuner.app` ekle → uygulamayı yeniden başlat. Kalıcı çözüm: yerel bir kod imzalama sertifikası (kullanıcı onayıyla). Klavye için Giriş İzleme izni de aynı şekilde.

**Eski kurulumun durumu (12 Kasım):** `com.muhammed.dockapps` LaunchAgent'ı durduruldu (plist yerinde; geri açmak için `launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.muhammed.dockapps.plist`). BetterDisplay kapalı. LinearMouse açık (Faz 4 bitene kadar gerekli).

**Yeni bulgular ve kararlar (önceki kararlara ek):**
| ID | Karar / bulgu |
|---|---|
| D-120 | **Klavye (PUSAT) arayüzü Giriş İzleme izni ister** (`IOHIDDeviceOpen` → `kIOReturnNotPermitted`). Kulaklık ve mouse istemez. Klavye sayfası izin yoksa "Sistem Ayarları'nı Aç" gösterir. 11. bölümdeki izin listesine **Giriş İzleme** eklenir (klavye sayfası ilk açıldığında). |
| D-121 | `ProfileStore.isColorManagementEnabled` (UserDefaults `colorManagementEnabled`, varsayılan **false**). Kullanıcı ilk uygulamayı onaylayana kadar (R3) uygulama monitöre gamma/DDC/bağlantı modu **yazmaz**; ColorGuard da pasif kalır. Onaydan sonra açılır ve Ekran sekmesinde bir anahtar olarak görünür. |
| D-122 | Renk sıcaklığı işareti: **pozitif = sıcak** (mavi azalır), **negatif = soğuk** (kırmızı azalır). 10.5'teki formül doğru; slider etiketleri buna göre. |
| D-123 | Kulaklık kapalıyken (`0x20 == 0`) pil durumu kaldırılır ("Kapalı"); mouse cevap vermezse son değer soluk gösterilir (D-64). Ses çıkışı geçişi bu varlık değişimine bağlı; gecikme en fazla bir sorgu aralığı (60 sn). |
| D-124 | Swift Testing testleri uygulama hostunda çalışır; `BaselineProfile.json` uygulama paketinden okunur. |
| D-125 | Teşhis: `log` zsh'de yerleşik komuttur; sistem logları için **`/usr/bin/log`** kullan. |
| D-126 | **Hz kullanıcının elle seçimidir, varsayılan 60 Hz.** Popover'da monitörün o an sunduğu Hz değerleri segmented seçici olarak gösterilir (`ModeService.refreshRates`). Seçim aktif profile kaydedilir ve dock takılınca geri yüklenir. ColorGuard Hz'i zorlamaz. (Not: 11 Kasım'daki USB-C kopmasından sonra 2048×1152 HiDPI'de sadece 60 Hz sunuluyor; dock bağlantısı daha düşük bant genişliğiyle kurulmuş.) |
| D-127 | **CADisplay uzun çalışan süreçte bayat kalır:** başka bir süreç modu değiştirse de `currentMode` eski değeri döndürür (test edildi). Bu yüzden bağlantı modu periyodik olarak izlenmez; açılışta ve olaylarda (uyanma, kilit açma, ekran değişimi, dock) **koşulsuz** (`force: true`) uygulanır. Periyodik kontrol sadece gamma sapmasına bakar. |
| D-128 | macOS uygulanan gamma tablosunu geri okurken [0,1] dışını kırpar. Sapma kontrolü kırpılmış değerlerle yapılır (`LUTMath.clamped`); aksi halde 0.0785'lik sonsuz yeniden uygulama döngüsü oluşur. |
| D-130 | **Bağlantı modu yardımcı süreçte uygulanır.** Dock testinde uygulama içindeki bayat CADisplay yeni ekranın modlarını göremedi ("Uygun mod yok"). Uygulama kendi programını `--apply-connection-mode <colorMode> <bitDepth>` ile çalıştırır (`DisplayTunerApp.init` bu bayrağı yakalar, modu değiştirip çıkar); başarısızsa 2 sn arayla 3 deneme. Açılış testi ✅; **dock tak/çıkar testi ✅** (BetterDisplay ve eski script kapalıyken, takıldıktan ~4 sn sonra ilk denemede RGB Full + profil). Dock çıkarılırken gelen ekran değişimi olayında 3 deneme boşa gider; zararsız, ileride monitör yokken atlanabilir. |
| D-131 | **`batt` bu Mac'te şarj kontrolünü desteklemiyor** (`batt limit 80` → "charging control is not supported on this Mac"; `batt status` → Control mode: unsupported). Eski script'in şarj limiti de hiç çalışmıyordu. D-91/D-92'deki şarj adımı devre dışı; `BattCLI` destek gelirse diye duruyor. |
| D-132 | Uygulama test hostu olarak açıldığında (`XCTestConfigurationFilePath` ortam değişkeni) `applicationDidFinishLaunching` hiçbir servisi başlatmaz; testler donanıma dokunmaz. |
| D-133 | Monitör tespiti `CGGetOnlineDisplayList` + vendor 13924 / model 9984 ile (CADisplay değil). Monitör yokken profil uygulanmaz, boş denemeler olmaz. |
| D-129 | Renk yönetimi kullanıcı onayıyla **açıldı** (12 Kasım 2026). Test: Limited moddan açılışta RGB Full'a dönüş ✅, döngü yok ✅, 60 Hz korunuyor ✅. |

## 18. Bekleyen istekler (kullanıcıdan)

- **Mouse makroları / yan tuşlar (13 Kasım 2026):** ROG Gladius II'nin yanındaki iki tuş Windows'ta ileri/geri yapıyordu; macOS'ta da aynısı istenir (tarayıcı, Finder, Xcode vb. her yerde Geri/İleri). İleride genel makro desteği: her tuşa kısayol, uygulamaya göre farklı atama. Uygulama fikri: `CGEventTap` ile `otherMouseDown` (buttonNumber 3 = geri, 4 = ileri) yakalanır, ön plandaki uygulamaya ⌘[ / ⌘] gönderilir ve orijinal olay yutulur; Mouse sekmesine "Yan tuşlar" bölümü (atama seçici + açık/kapa). Tuş numaraları donanımda doğrulanmalı (okuma serbest). Mevcut `ScrollReverser` event tap'i ve Erişilebilirlik izni yeniden kullanılabilir.
- **Göz konforu / gece modu (13 Kasım 2026):** Android'deki "göz konforu" gibi mavi ışığı azaltan sıcak renk modu. İstekler: her iki ekran için (MacBook ekranı + PR27R165QC) ayrı ayrı aç/kapa; elle açma, **otomatik** (gün batımı → gün doğumu, konum izniyle; `NSLocationUsageDescription` metni zaten var) ve **zamanlama** (ör. 22:00–07:00); yoğunluk ayarı; geçişte yumuşak solma. Fikir: macOS Night Shift DisplayLink ekranında çalışmayabilir, bu yüzden mevcut gamma LUT'taki renk sıcaklığı (`ColorAdjustments.temperature`, `GammaEngine`) ekran başına üstüne bindirilir; renk yönetimi profiliyle çakışmaması için profil LUT'u × gece katsayısı birlikte hesaplanır. Popover'a hızlı aç/kapa, kısayol (ör. ⌃⌥N) ve Ekran sekmesine "Göz konforu" bölümü.
