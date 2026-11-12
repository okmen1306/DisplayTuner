#!/bin/zsh
# DisplayTuner için yerel kod imzalama sertifikası oluşturur (bir kez çalıştırılır).
# Anahtar Zinciri'ne "DisplayTuner Local Signing" ekler ve imza için güvenilir yapar (şifre ister).
set -euo pipefail
NAME="DisplayTuner Local Signing"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cfg.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -nodes -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -days 3650 -config "$TMP/cfg.cnf"
openssl pkcs12 -export -legacy -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -out "$TMP/id.p12" -passout pass:dtlocal 2>/dev/null \
  || openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -out "$TMP/id.p12" -passout pass:dtlocal
security import "$TMP/id.p12" -k ~/Library/Keychains/login.keychain-db -P dtlocal -T /usr/bin/codesign
security add-trusted-cert -p codeSign -k ~/Library/Keychains/login.keychain-db "$TMP/cert.pem"
echo "Hazır: $NAME"
