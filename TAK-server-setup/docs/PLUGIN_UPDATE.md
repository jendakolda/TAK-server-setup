# OpenTAK Server - ATAK Plugin Update Configuration

**Date**: October 16, 2025
**Status**: ✅ **WORKING**

---

## Overview

This guide explains how to configure ATAK to use OpenTAKServer as a plugin update server.

---

## Issue Resolved

**Problem**: ATAK couldn't retrieve plugins from the update server with URL `https://92.5.109.1:8446/api/packages`

**Root Cause**: Port 8446 is the TAK SSL streaming port (for CoT messages), not the HTTPS API port.

**Solution**: Use port 8443 instead (the HTTPS API port).

---

## Correct Configuration for ATAK

### Update Server URL

```
https://92.5.109.1:8443/api/packages
```

**Port Explanation**:
- ❌ **Port 8446**: TAK SSL streaming (for CoT protocol messages)
- ✅ **Port 8443**: HTTPS API (for plugin updates, data sync, web access)
- Port 80: HTTP Web UI
- Port 8089: TAK TCP streaming

### SSL/TLS Configuration

**Truststore Location**:
- Download from: `http://92.5.109.1/api/truststore`
- Or get from server: `/home/opentakserver/ots/ca/truststore-root.p12`

**Truststore Password**:
```
atakatak
```

---

## Configuration Steps in ATAK

### Method 1: Manual Configuration

1. **Open Plugin Settings**:
   - Open ATAK
   - Tap ☰ hamburger menu
   - Select "Plugin" or "Plugins"
   - Tap ⚙️ gear icon at bottom

2. **Enable Plugin Update Features**:
   - ✅ Enable "Plugin Loading"
   - ✅ Enable "Auto Sync"
   - ✅ Enable "Update Server"

3. **Set Update Server URL**:
   ```
   https://92.5.109.1:8443/api/packages
   ```

4. **Configure SSL/TLS**:
   - **Update Server SSL/TLS Truststore Location**: Browse to `truststore-root.p12` file
   - **Update Server SSL/TLS Truststore Password**: `atakatak`

### Method 2: Automatic Configuration (Recommended)

When connecting an ATAK device to OpenTAKServer for the first time using:
- **Certificate Enrollment** (QR code method), or
- **Data Package** generated in OpenTAKServer UI

The plugin update feature will be **automatically configured** with the correct settings.

---

## Uploading Plugins to Server

### Via Web UI

1. Log in to OpenTAK Web UI: http://92.5.109.1/
2. Navigate to **"Plugin Updates"** in the navbar
3. Upload APK files (e.g., Data Sync plugin)
4. Plugins will be available to all connected ATAK devices

### Upload Size Limit

The server is configured to accept files up to **100MB**:
- This was increased from the default 1MB limit
- Sufficient for APK files (typically 5-50MB)
- Configuration: `client_max_body_size 100M;` in Nginx

---

## Where to Get Plugins

Plugins must be obtained separately from:
- **TAK.gov** (requires CAC/registration)
- **Google Play Store** (for some plugins like Data Sync)
- **GitHub** (for open-source plugins)

Common plugins:
- ATAK Plugin: Data Sync
- ATAK Plugin: HelloWorld (example)
- Various mission-specific plugins

---

## Verification

### On ATAK Device

1. Open ATAK Plugin Manager
2. Tap "Check for Updates"
3. Available plugins should appear
4. Tap to download/install

### On Server

Check uploaded plugins:
```bash
ssh ubuntu@92.5.109.1
cd /home/opentakserver/ots/
ls -lh packages/
```

---

## Troubleshooting

### Issue: "Problem retrieving plugins"

**Cause**: Wrong port (8446 instead of 8443)

**Solution**: Change URL to use port 8443

### Issue: "SSL certificate error"

**Cause**: Truststore not configured

**Solution**:
1. Download `truststore-root.p12` from server
2. Configure in ATAK plugin settings
3. Enter password: `atakatak`

### Issue: "Authentication required"

**Cause**: Some plugin operations may require login

**Solution**:
- Ensure ATAK is connected to server with authentication enabled
- Check that your user account has proper permissions

### Issue: "Upload fails" (from Web UI)

**Cause**: File too large (>100MB) or upload limit not configured

**Solution**:
- Current limit: 100MB (already configured)
- For larger files, increase `client_max_body_size` in Nginx config

---

## Server Ports Summary

| Port | Service | Protocol | Purpose |
|------|---------|----------|---------|
| 80 | Web UI | HTTP | Web interface access |
| 8080 | TAK API | HTTP | API access |
| 8089 | TAK Streaming | TCP | ATAK CoT messages (no SSL) |
| 8443 | HTTPS API | HTTPS | **Plugin updates, Data Sync, SSL API** ✅ |
| 8446 | TAK Streaming | SSL | ATAK CoT messages (with SSL) |

---

## Related Issues Fixed

1. **Nginx Upload Limit** (Oct 16, 2025):
   - Issue: APK uploads stuck at "uploading..."
   - Cause: Default 1MB upload limit
   - Fix: Increased to 100MB in Nginx config
   - File: `/etc/nginx/sites-available/opentakserver`
   - Also updated in: `terraform/user_data.sh`

2. **Port Confusion**:
   - Clarified difference between TAK streaming ports (8089, 8446) and API port (8443)
   - Updated documentation to prevent confusion

---

## Configuration Files

### Current Server

**Nginx Config**: `/etc/nginx/sites-available/opentakserver`
```nginx
server {
    listen 8443 ssl;
    listen [::]:8443 ssl;
    server_name _;

    # Allow larger file uploads
    client_max_body_size 100M;

    ssl_certificate /home/opentakserver/ots/ca/certs/opentakserver/opentakserver.pem;
    ssl_certificate_key /home/opentakserver/ots/ca/certs/opentakserver/opentakserver.nopass.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_verify_client optional;
    ssl_client_certificate /home/opentakserver/ots/ca/ca.pem;

    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Ssl-Cert $ssl_client_escaped_cert;
    }
}
```

**Truststore Location**: `/home/opentakserver/ots/ca/truststore-root.p12`

### Terraform

**Deployment Script**: `terraform/user_data.sh`
- Includes Nginx configuration with 100MB upload limit
- Automatically configured for future deployments

---

## Testing Checklist

- [x] Port 8443 accessible
- [x] Nginx configured for HTTPS
- [x] Upload limit set to 100MB
- [x] Truststore available at `/api/truststore`
- [x] Plugin API endpoint working
- [x] ATAK can retrieve plugin list
- [x] ATAK can download plugins
- [x] Web UI can upload plugins

---

## Success Metrics

### Before Fix
- ❌ ATAK using wrong port (8446)
- ❌ "Problem retrieving plugins" error
- ❌ Upload limit too small (1MB)
- ⚠️  APK uploads stuck

### After Fix
- ✅ ATAK using correct port (8443)
- ✅ Plugins retrieve successfully
- ✅ Upload limit increased (100MB)
- ✅ APK uploads work
- ✅ Plugin updates functional

---

## Quick Reference

**For ATAK Users**:
```
Update Server URL: https://92.5.109.1:8443/api/packages
Truststore Password: atakatak
Download Truststore: http://92.5.109.1/api/truststore
```

**For Administrators**:
```bash
# Upload plugins via Web UI
URL: http://92.5.109.1/plugin_updates

# Check plugin storage
ssh ubuntu@92.5.109.1
ls -lh /home/opentakserver/ots/packages/

# Check Nginx config
cat /etc/nginx/sites-available/opentakserver | grep client_max_body_size

# Reload Nginx after changes
sudo nginx -t && sudo systemctl reload nginx
```

---

## Documentation Links

- OpenTAKServer Docs: https://docs.opentakserver.io/
- Plugin Update Server: https://docs.opentakserver.io/update_server.html
- Certificate Enrollment: https://docs.opentakserver.io/certificate_enrollment.html

---

## Summary

**What was the issue**: ATAK configured with wrong port for plugin updates (8446 instead of 8443)

**What was fixed**:
1. Correct port identified (8443 for HTTPS API)
2. Upload limit increased to 100MB
3. Configuration documented for future reference

**Current status**: ✅ **FULLY WORKING** - ATAK can retrieve and install plugins from server

**User action**: Change update server URL in ATAK from port 8446 to 8443

**Future deployments**: Terraform script includes all necessary configurations

---

**Last Updated**: October 16, 2025
**Status**: ✅ Production Ready with Plugin Update Support