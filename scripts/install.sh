#!/bin/zsh
# DisplayTuner'ı derleyip /Applications'a kurar ve yeniden başlatır.
# Kullanım: ./scripts/install.sh
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_DIR="$PWD/build"
xcodebuild -project DisplayTuner.xcodeproj -scheme DisplayTuner -configuration Release \
  -derivedDataPath "$BUILD_DIR" build | grep -E 'error:|BUILD (SUCCEEDED|FAILED)'

pkill -f 'DisplayTuner.app/Contents/MacOS/DisplayTuner' || true
sleep 1
rsync -a --delete "$BUILD_DIR/Build/Products/Release/DisplayTuner.app/" /Applications/DisplayTuner.app/

# D-141: Yerel imza sertifikası varsa onunla imzala; böylece macOS izinleri güncellemelerde korunur.
IDENTITY="DisplayTuner Local Signing"
if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
  codesign --force --deep --sign "$IDENTITY" /Applications/DisplayTuner.app && echo "İmzalandı: $IDENTITY"
else
  echo "Uyarı: '$IDENTITY' sertifikası yok; ad-hoc imza (izinler her güncellemede sıfırlanır)."
fi
# Derleme kopyaları uygulama listelerinde (⌘Tab, Spotlight, Launchpad) görünmesin; sadece /Applications kayıtlı kalsın.
LSR=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
touch "$BUILD_DIR/.metadata_never_index"
for app in "$BUILD_DIR"/Build/Products/*/DisplayTuner.app; do "$LSR" -u "$app" 2>/dev/null || true; done
"$LSR" -f /Applications/DisplayTuner.app

open /Applications/DisplayTuner.app
echo "Kuruldu: /Applications/DisplayTuner.app"
