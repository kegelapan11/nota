#!/bin/bash
# ======================================================
# CASAOS AUTO INSTALLER + SUBDOMAIN + SSL
# Domain: casa.celengstore.my.id (tidak bentrok dengan Xray)
# Port internal: 110400
# Tested on Ubuntu 22.04 + Xray + Nginx
# ======================================================

SUBDOMAIN="casa.celengstore.my.id"
PORT=110400

set -e

echo -e "\n🔧 Update sistem..."
apt update -y && apt upgrade -y

echo -e "\n📦 Install dependency..."
apt install -y curl jq nginx certbot python3-certbot-nginx ufw

# ======================================================
# 1️⃣ Install CasaOS
# ======================================================
echo -e "\n⬇️ Install CasaOS..."
curl -fsSL https://get.casaos.io | bash || {
    echo "❌ Gagal menginstall CasaOS."
    exit 1
}

# ======================================================
# 2️⃣ Deteksi konfigurasi CasaOS
# ======================================================
echo -e "\n🔍 Mendeteksi lokasi konfigurasi CasaOS..."
CONF_PATH=""
for path in \
    "/etc/casaos/gateway.conf" \
    "/var/lib/casaos/gateway/conf/gateway.conf" \
    "/usr/local/etc/casaos/gateway.conf" \
    "/opt/casaos/gateway/conf/gateway.conf"; do
    if [ -f "$path" ]; then
        CONF_PATH="$path"
        break
    fi
done

if [ -n "$CONF_PATH" ]; then
    echo "✅ Konfigurasi ditemukan: $CONF_PATH"
    sed -i "s/\"port\": *[0-9]\+/\"port\": ${PORT}/" "$CONF_PATH"
else
    echo "⚙️ Menambahkan environment service CASA_PORT=${PORT}"
    mkdir -p /etc/systemd/system/casaos-gateway.service.d
    cat >/etc/systemd/system/casaos-gateway.service.d/override.conf <<EOF
[Service]
Environment="CASA_PORT=${PORT}"
EOF
    systemctl daemon-reexec
    systemctl daemon-reload
fi

# ======================================================
# 3️⃣ Restart CasaOS
# ======================================================
echo -e "\n🔁 Restart CasaOS..."
systemctl restart casaos-gateway || true
systemctl restart casaos || true

# ======================================================
# 4️⃣ Nginx Reverse Proxy untuk subdomain
# ======================================================
echo -e "\n🌐 Konfigurasi Nginx untuk subdomain ${SUBDOMAIN}..."
cat >/etc/nginx/sites-available/casaos.conf <<EOF
server {
    listen 80;
    server_name ${SUBDOMAIN};

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

# ======================================================
# 5️⃣ Firewall & SSL
# ======================================================
echo -e "\n🧱 Membuka firewall dan pasang SSL..."
ufw allow ${PORT}/tcp || true
ufw allow 'Nginx Full' || true

certbot --nginx -d ${SUBDOMAIN} --non-interactive --agree-tos -m admin@${SUBDOMAIN} || {
    echo "⚠️ SSL gagal dipasang. Coba manual dengan: certbot --nginx -d ${SUBDOMAIN}"
}

# ======================================================
# 6️⃣ Selesai
# ======================================================
echo -e "\n✅ Instalasi CasaOS selesai!"
echo "-----------------------------------------------------"
echo "🌍 Akses CasaOS di: https://${SUBDOMAIN}"
echo "Port internal CasaOS: ${PORT}"
echo "SSL: /etc/letsencrypt/live/${SUBDOMAIN}/"
echo "-----------------------------------------------------"
