# config
$nmapPath = "C:\Program Files (x86)\Nmap\nmap.exe"
$outputFile = "nmap_output.txt"
$apacheConf = "C:\Apache24\conf\httpd.conf"
$apacheDefaults = "C:\Apache24\conf\extra\httpd-default.conf"
$apacheBin = "C:\Apache24\bin\httpd.exe"

write-host "[*] running nmap scan on localhost:8080..."
& "$nmapPath" -p 8080 --script http-* -T4 -A -v 127.0.0.1 -oN $outputFile

write-host "[*] parsing nmap output..."
$nmapOutput = Get-Content $outputFile -Raw

# trace
if ($nmapOutput -match "TRACE is enabled") {
    write-host "[!] trace method detected"
    if (Test-Path $apacheDefaults) {
        if (-not (Select-String -Path $apacheDefaults -Pattern "TraceEnable off" -Quiet)) {
            Add-Content -Path $apacheDefaults -Value "`nTraceEnable off"
            write-host "[+] trace disabled in httpd-default.conf"
        }
    } else {
        if (-not (Select-String -Path $apacheConf -Pattern "TraceEnable off" -Quiet)) {
            Add-Content -Path $apacheConf -Value "`nTraceEnable off"
            write-host "[+] trace disabled in httpd.conf"
        }
    }
}

# git
if ($nmapOutput -match "Exposed .git directory") {
    write-host "[!] .git directory exposed"
    $gitBlockRule = @"
<DirectoryMatch "^${SRVROOT}/htdocs/\.git">
    Require all denied
</DirectoryMatch>
"@
    if (-not (Select-String -Path $apacheConf -Pattern 'htdocs/.git' -Quiet)) {
        Add-Content -Path $apacheConf -Value "`n$gitBlockRule"
        write-host "[+] .git access blocked"
    } else {
        write-host "[=] .git rule already exists"
    }
}

# headers
if ($nmapOutput -match "http-security-headers" -or $nmapOutput -match "Bug in http-security-headers") {
    write-host "[!] security headers missing"
    if (-not (Select-String -Path $apacheConf -Pattern "Header always set X-Frame-Options" -Quiet)) {
        $headersBlock = @"
<IfModule headers_module>
    Header always set X-Frame-Options "DENY"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "no-referrer"
</IfModule>
"@
        Add-Content -Path $apacheConf -Value "`n$headersBlock"
        write-host "[+] security headers added"
    } else {
        write-host "[=] headers already exist"
    }
}

# server banner
if ($nmapOutput -match "Server: Apache") {
    write-host "[!] server version exposed"
    if (-not (Select-String -Path $apacheConf -Pattern "ServerTokens Prod" -Quiet)) {
        Add-Content -Path $apacheConf -Value "`nServerTokens Prod"
        write-host "[+] set ServerTokens Prod"
    }
    if (-not (Select-String -Path $apacheConf -Pattern "ServerSignature Off" -Quiet)) {
        Add-Content -Path $apacheConf -Value "`nServerSignature Off"
        write-host "[+] set ServerSignature Off"
    }
}

# bad bots
# if ($nmapOutput -match "Allowed User Agents") {
#     write-host "[!] bad user-agents allowed"
#     if (-not (Select-String -Path $apacheConf -Pattern "BadBot" -Quiet)) {
#         $botBlock = @"
# SetEnvIfNoCase User-Agent "BadBot" bad_bot
# <Directory />
#     Order Allow,Deny
#     Allow from all
#     Deny from env=bad_bot
# </Directory>
# "@
#         Add-Content -Path $apacheConf -Value "`n$botBlock"
#         write-host "[+] bad bot rule added"
#     } else {
#         write-host "[=] bad bot rule already exists"
#     }
# }

# slowloris
if ($nmapOutput -match "Slowloris DOS attack") {
    write-host "[!] slowloris vulnerability detected"
    if (-not (Select-String -Path $apacheConf -Pattern "RequestReadTimeout" -Quiet)) {
        $slowlorisFix = @"
<IfModule reqtimeout_module>
    RequestReadTimeout header=20-40,MinRate=500 body=20,MinRate=500
</IfModule>
"@
        Add-Content -Path $apacheConf -Value "`n$slowlorisFix"
        write-host "[+] request timeout settings added"
    } else {
        write-host "[=] slowloris fix already present"
    }
}

# mod_security
$modSecModule = "C:\Apache24\modules\mod_security2.so"
$modSecConf = "C:\Apache24\conf\extra\modsecurity.conf"

if (Test-Path $modSecModule) {
    write-host "[*] mod_security module found"

    # ensure mod_security module is loaded
    if (-not (Select-String -Path $apacheConf -Pattern "mod_security2.so" -Quiet)) {
        Add-Content -Path $apacheConf -Value "`nLoadModule security2_module modules/mod_security2.so"
        write-host "[+] mod_security module enabled"
    } else {
        write-host "[=] mod_security module already enabled"
    }

    # include modsecurity.conf
    if ((Test-Path $modSecConf) -and (-not (Select-String -Path $apacheConf -Pattern "modsecurity.conf" -Quiet))) {
        Add-Content -Path $apacheConf -Value "`nInclude conf/extra/modsecurity.conf"
        write-host "[+] included modsecurity.conf"
    } else {
        write-host "[=] modsecurity config already included or missing"
    }

} else {
    write-host "[!] mod_security module not found, please install manually"
}

# proxy
# if ($nmapOutput -match "http-open-proxy") {
#     write-host "[!] open proxy detected"
#     if (-not (Select-String -Path $apacheConf -Pattern "<Proxy \*>" -Quiet)) {
#         $proxyBlock = @"
# <Proxy *>
#     Order deny,allow
#     Deny from all
# </Proxy>
# "@
#         Add-Content -Path $apacheConf -Value "`n$proxyBlock"
#         write-host "[+] proxy access blocked"
#     } else {
#         write-host "[=] proxy rule already exists"
#     }
# }

# restart apache
if (Test-Path $apacheBin) {
    write-host "[*] restarting apache"
    Stop-Process -Name "httpd" -Force -ErrorAction SilentlyContinue
    Start-Process -FilePath $apacheBin
    write-host "apache restarted"
} else {
    write-host "[!] apache binary not found, restart manually"
}

# summary
write-host "`n[*] summary of fixes:"
$nmapOutput | Select-String -Pattern "TRACE|.git|security-headers|Server: Apache|Slowloris|open-proxy|User Agents" | ForEach-Object {
    write-host "[+] $($_.Line)"
}

write-host "`n[*] scan-and-fix routine complete. re-run the nmap scan to verify."
