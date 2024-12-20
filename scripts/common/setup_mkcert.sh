#!/bin/bash

# 设置 mkcert CA 目录
CAROOT="$HOME/.local/share/mkcert"
mkdir -p "$CAROOT"

# 设置环境变量
export CAROOT

# 生成 CA 证书
echo "Generating CA certificate..."
mkcert -install

# 生成一个有效期为 100 年的通配符证书，支持所有域名
echo "Generating wildcard certificate..."
mkcert -cert-file "$CAROOT/cert.pem" \
       -key-file "$CAROOT/key.pem" \
       -CAROOT "$CAROOT" \
       -validity 36500 \
       "*.localhost" "localhost" "127.0.0.1" "::1" \
       "*.test" "test" \
       "*.local" "local" \
       "*.internal" "internal" \
       "*.example" "example" \
       "*.dev" "dev" \
       "*.corp" "corp" \
       "*.lan" "lan" \
       "*.home" "home" \
       "*.private" "private" \
       "*.localdomain" "localdomain" \
       "*.intranet" "intranet" \
       "*.arpa" "arpa" \
       "*.invalid" "invalid" \
       "*.onion" "onion" \
       "*.exit" "exit" \
       "*.box" "box" \
       "*.vm" "vm" \
       "*.docker" "docker" \
       "*.k8s" "k8s" \
       "*.cluster" "cluster" \
       "*.svc" "svc" \
       "*.pod" "pod" \
       "*.cloud" "cloud" \
       "*.io" "io" \
       "*.app" "app" \
       "*.dev" "dev" \
       "*.ai" "ai" \
       "*.com" "com" \
       "*.net" "net" \
       "*.org" "org" \
       "*.edu" "edu" \
       "*.gov" "gov" \
       "*.mil" "mil" \
       "*.int" "int" \
       "*.eu" "eu" \
       "*.cn" "cn" \
       "*.us" "us" \
       "*.uk" "uk" \
       "*.jp" "jp" \
       "*.kr" "kr" \
       "*.ru" "ru" \
       "*.de" "de" \
       "*.fr" "fr" \
       "*.it" "it" \
       "*.es" "es" \
       "*.br" "br" \
       "*.in" "in" \
       "*.au" "au" \
       "*.ca" "ca"

# 创建符号链接到常用目录
mkdir -p "$HOME/.cert"
ln -sf "$CAROOT/cert.pem" "$HOME/.cert/cert.pem"
ln -sf "$CAROOT/key.pem" "$HOME/.cert/key.pem"

echo "mkcert setup completed!"
echo "CA Root: $CAROOT"
echo "Certificate: $CAROOT/cert.pem"
echo "Private Key: $CAROOT/key.pem"
echo "Symlinks created in: $HOME/.cert/"

# 输出证书信息
echo "Certificate details:"
openssl x509 -in "$CAROOT/cert.pem" -text -noout | grep "Subject Alternative Name" -A 1 