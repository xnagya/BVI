#!/bin/bash

echo "[*] Reverting Apache hardening changes..."

if [ -f /etc/apache2/apache2.conf.bak ]; then
    echo "[*] Restoring apache2.conf from backup..."
    cp /etc/apache2/apache2.conf.bak /etc/apache2/apache2.conf
else
    echo "[!] Backup not found, removing hardening settings manually..."

    sed -i '/TraceEnable off/d' /etc/apache2/apache2.conf
    sed -i '/RequestReadTimeout/d' /etc/apache2/apache2.conf
    sed -i '/ServerTokens Prod/d' /etc/apache2/apache2.conf
    sed -i '/ServerSignature Off/d' /etc/apache2/apache2.conf
    sed -i '/SetEnvIfNoCase User-Agent/d' /etc/apache2/apache2.conf
    sed -i '/<Directory \/>/,/Deny from env=bad_bot/d' /etc/apache2/apache2.conf
    sed -i '/ErrorDocument 404 \/404.html/d' /etc/apache2/apache2.conf
fi

echo "[*] Disabling header and .git security configs..."
a2disconf security-headers
a2disconf block-git
rm -f /etc/apache2/conf-available/security-headers.conf
rm -f /etc/apache2/conf-available/block-git.conf

echo "[*] Disabling modules..."
a2dismod reqtimeout
a2dismod headers
a2dismod rewrite
a2dismod security2

echo "[*] Re-enabling proxy modules (optional)..."
a2enmod proxy
a2enmod proxy_http
a2enmod proxy_ftp

echo "[*] Cleaning mod_security configs..."
apt remove -y libapache2-mod-security2

echo "[*] Restarting Apache..."
apachectl configtest && systemctl restart apache2 && echo "✅ Revert complete."
