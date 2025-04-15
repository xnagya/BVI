#!/bin/bash

echo "[*] Backing up current Apache configuration..."
cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.bak

echo "[*] Disabling TRACE method..."
echo "TraceEnable off" >> /etc/apache2/apache2.conf

echo "[*] Setting Request Timeouts to mitigate Slowloris..."
a2enmod reqtimeout
echo "<IfModule reqtimeout_module>
    RequestReadTimeout header=20-40,MinRate=500 body=20,MinRate=500
</IfModule>" >> /etc/apache2/apache2.conf

echo "[*] Disabling open proxy (mod_proxy)..."
a2dismod proxy
a2dismod proxy_http
a2dismod proxy_ftp

echo "[*] Hiding server version (banner)..."
echo "ServerTokens Prod" >> /etc/apache2/apache2.conf
echo "ServerSignature Off" >> /etc/apache2/apache2.conf

echo "[*] Enabling security headers..."
a2enmod headers
cat <<EOL >> /etc/apache2/conf-available/security-headers.conf
<IfModule mod_headers.c>
    Header always set X-Frame-Options "DENY"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "no-referrer"
    Header always set Content-Security-Policy "default-src 'self';"
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
</IfModule>
EOL
a2enconf security-headers

echo "[*] Blocking known bad bots..."
cat <<EOL >> /etc/apache2/apache2.conf
SetEnvIfNoCase User-Agent "BadBot" bad_bot
<Directory />
    Order Allow,Deny
    Allow from all
    Deny from env=bad_bot
</Directory>
EOL

echo "[*] Blocking public access to .git folder..."
cat <<EOL >> /etc/apache2/conf-available/block-git.conf
<DirectoryMatch "^/.*/\.git/">
    Require all denied
</DirectoryMatch>
EOL
a2enconf block-git

echo "[*] Enabling custom 404 handler..."
echo "ErrorDocument 404 /404.html" >> /etc/apache2/apache2.conf

echo "[*] Enabling mod_rewrite for URL sanitization and CSRF tokens (future use)..."
a2enmod rewrite

echo "[*] Installing and enabling mod_security for WAF..."
apt update && apt install -y libapache2-mod-security2
a2enmod security2
cp /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf
sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf

echo "[*] Restarting Apache to apply changes..."
apachectl configtest && systemctl restart apache2 && echo "✅ Apache hardened successfully with mod_security and mod_rewrite!"
