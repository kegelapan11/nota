#!/bin/bash
# ======================================================
# CASAOS AUTO INSTALLER + NGINX REVERSE PROXY (SSL)
# Domain: celengstore.my.id
# Port internal: 110400
# Tested on Ubuntu 22.04
# ======================================================

DOMAIN="celengstore.my.id"
PORT=110400

set -e

echo -e "\n🔧 Update sistem..."
apt update -y && apt upgrade -y

echo -e "\n📦 Install dependency..."
apt install -y curl jq nginx certbot python3-certbot-nginx ufw

echo -e "\n⬇️ Install CasaOS..."
curl -fsSL https://get.casaos.io | bash

echo -e "\n⚙️ Ubah port CasaOS menjadi ${PORT}..."
CONFIG_FILE="/etc/casaos/gateway.conf"
if [ -f "$CONFIG_FILE" ]; then
    sed -i "s/\"port\": *[0-9]\+/\"port\": ${PORT}/" "$CONFIG_FILE"
else
    echo "❌ File konfigurasi tidak ditemukan: $CONFIG_FILE"
    exit 1
fi

echo -e "\n🔁 Restart CasaOS..."
systemctl restart casaos-gateway
systemctl restart casaos

echo -e "\n🌐 Membuka port ${PORT} di firewall..."
ufw allow ${PORT}/tcp || true
ufw allow 'Nginx Full' || true

echo -e "\n🧱 Konfigurasi Nginx reverse proxy..."
cat >/etc/nginx/sites-available/casaos.conf <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf /etc/nginx/sites-available/casaos.conf /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

echo -e "\n🔐 Pasang sertifikat SSL dari Let's Encrypt..."
certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos -m admin@${DOMAIN}

echo -e "\n✅ Instalasi selesai!"
echo "-----------------------------------------------------"
echo "🌍 Akses CasaOS di: https://${DOMAIN}"
echo "Port internal CasaOS: ${PORT}"
echo "Konfigurasi Nginx: /etc/nginx/sites-available/casaos.conf"
echo "-----------------------------------------------------"
