#!/usr/bin/env bash
# 用免费的 sslip.io 泛解析域名 + Let's Encrypt 给 MCP 反代加 HTTPS。
# 不需要自购域名；签发只走 80 端口（HTTP-01），对外提供服务需要 443 放行。
set -eu

DOMAIN="20-255-73-137.sslip.io"
WEBROOT="/var/www/mimic-dlp"

echo "=== 1. 安装 certbot ==="
if ! command -v certbot >/dev/null 2>&1; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq certbot
fi
certbot --version

echo "=== 2. 确认域名解析到本机 ==="
getent hosts "$DOMAIN" || { echo "域名解析失败"; exit 1; }

echo "=== 3. 申请证书（webroot / HTTP-01）==="
sudo certbot certonly \
  --webroot -w "$WEBROOT" \
  -d "$DOMAIN" \
  --agree-tos \
  --register-unsafely-without-email \
  --non-interactive \
  --keep-until-expiring

echo "=== 4. 证书文件 ==="
sudo ls -l "/etc/letsencrypt/live/$DOMAIN/" || true
echo "DOMAIN=$DOMAIN"
