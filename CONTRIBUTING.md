# Contributing · Katkı

**English** — Thanks for your interest! DisplayTuner started as a personal tool, so it only knows the hardware it was built on. Help is welcome, especially:

- **New devices**: other monitors (DDC/CI, connection modes), Razer/ASUS/other headsets, mice and keyboards
- **Making hardware configurable** instead of hard-coded vendor and product IDs
- Bug fixes, translations and design polish

How to help:

1. Open an issue first for larger changes, so we can agree on the approach.
2. Fork, create a branch, and keep each pull request focused on one thing.
3. Run the tests: `xcodebuild -project DisplayTuner.xcodeproj -scheme DisplayTuner test`
4. If you add a device, document its protocol (report IDs, commands, checksums) in the pull request, and say which hardware you tested on.
5. **Be careful with hardware writes.** Test with values you can restore, and never write firmware or flash regions you don't understand.

Please don't add code that bypasses DRM, licenses or security features.

---

**Türkçe** — İlgin için teşekkürler! DisplayTuner kişisel bir araç olarak başladı; bu yüzden sadece yazıldığı donanımı tanıyor. Özellikle şu konularda yardıma açığız:

- **Yeni cihazlar**: başka monitörler (DDC/CI, bağlantı modları), Razer/ASUS/diğer kulaklık, mouse ve klavyeler
- Sabit yazılmış cihaz kimlikleri yerine **ayarlanabilir donanım desteği**
- Hata düzeltmeleri, çeviriler ve tasarım iyileştirmeleri

Nasıl katkı verilir:

1. Büyük değişikliklerde önce bir issue aç, yaklaşımı birlikte belirleyelim.
2. Fork'la, bir dal aç ve her pull request'i tek bir konuya odakla.
3. Testleri çalıştır: `xcodebuild -project DisplayTuner.xcodeproj -scheme DisplayTuner test`
4. Cihaz ekliyorsan protokolünü (rapor kimlikleri, komutlar, checksum) pull request'te açıkla ve hangi donanımda test ettiğini yaz.
5. **Donanıma yazarken dikkatli ol.** Geri alabileceğin değerlerle test et; anlamadığın firmware ya da flash alanlarına asla yazma.

DRM, lisans veya güvenlik özelliklerini atlatan kod eklemeyelim.
