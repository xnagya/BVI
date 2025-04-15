#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <apache-server-ip>"
    exit 1
fi

TARGET=$1
PORT=8080
OUTPUT_DIR="apache_scan_results"
mkdir -p $OUTPUT_DIR
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

echo "Starting Apache Security Scan on: $TARGET:$PORT"
echo "Results will be saved in $OUTPUT_DIR/$TARGET-$TIMESTAMP.txt"

# Port Check
echo "[+] Checking if Apache is running on $TARGET:$PORT..."
nmap -p $PORT --open -oN "$OUTPUT_DIR/$TARGET-port-$TIMESTAMP.txt" $TARGET

# Apache Version and Server Header
echo "[+] Checking for outdated Apache versions..."
nmap -p $PORT -sV --script=http-server-header -oN "$OUTPUT_DIR/$TARGET-apache-version-$TIMESTAMP.txt" $TARGET

# Security Misconfigurations (Headers, SSL)
echo "[+] Checking for security misconfigurations..."
nmap -p $PORT --script http-security-headers,http-headers -oN "$OUTPUT_DIR/$TARGET-misconfig-$TIMESTAMP.txt" $TARGET

# Access Control Vulnerabilities
echo "[+] Checking for access control vulnerabilities..."
nmap -p $PORT --script http-auth-finder,http-methods -oN "$OUTPUT_DIR/$TARGET-access-control-$TIMESTAMP.txt" $TARGET

# Web Application Vulnerabilities (XSS, SQLi)
echo "[+] Scanning for web application vulnerabilities..."
nmap -p $PORT --script http-sql-injection,http-xssed,http-phpself-xss,http-enum -oN "$OUTPUT_DIR/$TARGET-app-issues-$TIMESTAMP.txt" $TARGET

# Sensitive Files (Backups, robots.txt)
echo "[+] Scanning for sensitive files..."
nmap -p $PORT --script http-config-backup,http-robots.txt,http-enum -oN "$OUTPUT_DIR/$TARGET-sensitive-files-$TIMESTAMP.txt" $TARGET

# Slowloris DoS Check
echo "[+] Checking for Slowloris (DoS) vulnerability..."
nmap -p $PORT --script http-slowloris-check -oN "$OUTPUT_DIR/$TARGET-slowloris-$TIMESTAMP.txt" $TARGET

# CSRF Forms Check
echo "[+] Checking for CSRF vulnerabilities..."
nmap -p $PORT --script http-csrf -oN "$OUTPUT_DIR/$TARGET-csrf-$TIMESTAMP.txt" $TARGET

# Open Proxy Detection
echo "[+] Checking for open proxy configuration..."
nmap -p $PORT --script http-open-proxy -oN "$OUTPUT_DIR/$TARGET-proxy-$TIMESTAMP.txt" $TARGET

# Malware Hosting Indicator
echo "[+] Checking for malware hosting indicators..."
nmap -p $PORT --script http-malware-host -oN "$OUTPUT_DIR/$TARGET-malware-$TIMESTAMP.txt" $TARGET

# File Upload Exploits
echo "[+] Checking for file upload vulnerabilities..."
nmap -p $PORT --script http-fileupload-exploiter -oN "$OUTPUT_DIR/$TARGET-upload-$TIMESTAMP.txt" $TARGET

# Cross-Domain Scripts (CORS, Referer leaks)
echo "[+] Checking for cross-domain script issues..."
nmap -p $PORT --script http-referer-checker,http-cross-domain-policy -oN "$OUTPUT_DIR/$TARGET-crossdomain-$TIMESTAMP.txt" $TARGET

echo "Apache Security Scan completed. Results saved in $OUTPUT_DIR/"
