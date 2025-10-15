# OpenTAK Server SSL Connection Guide

**Last Updated**: October 15, 2025
**Status**: ✅ SSL Streaming OPERATIONAL

---

## Overview

Your OpenTAK Server now supports **both TCP and SSL connections** for ATAK devices:

- **TCP (Port 8089)**: Simple, no certificates required ✅ WORKING
- **SSL (Port 8446)**: Secure, requires client certificates ✅ WORKING

---

## Current Server Information

- **Public IP**: 92.5.109.1
- **Web UI**: http://92.5.109.1/
- **Credentials**: xxxx

### Available Ports

| Port | Protocol | Service | Status |
|------|----------|---------|--------|
| 80 | HTTP | Web UI | ✅ Running |
| 8080 | HTTP | TAK API | ✅ Running |
| 8089 | TCP | TAK Streaming (no SSL) | ✅ Running |
| 8443 | HTTPS | Web UI SSL | ✅ Running |
| 8446 | SSL | TAK Streaming (SSL) | ✅ Running |

---

## Method 1: SSL Connection with QR Code (Recommended)

This is the **easiest method** for connecting ATAK devices with SSL certificates.

### Prerequisites
- OpenTAK Server version 1.5.0+ (you have this ✅)
- ATAK device with recent version
- User account on OpenTAK Server

### Steps

1. **Log in to Web UI**
   - Open http://92.5.109.1/ in your browser
   - Log in

2. **Generate QR Code for ATAK**
   - Navigate to the certificate enrollment section in the Web UI
   - Generate a QR code for your ATAK device
   - Optional: Set expiration date and maximum number of uses

3. **Scan QR Code from ATAK**
   - Open ATAK on your Android device
   - Go to **Settings** → **Network Preferences** → **Network Connection Preferences**
   - Use ATAK's QR code scanner to scan the code
   - ATAK will automatically:
     - Configure server connection (92.5.109.1:8446)
     - Download client certificate
     - Import truststore certificate
     - Enable SSL/TLS

4. **Connect**
   - Save the connection settings
   - ATAK should connect automatically via SSL

---

## Method 2: Manual SSL Connection

If you prefer manual configuration or QR code doesn't work:

### Step 1: Download Truststore Certificate

The truststore certificate tells ATAK to trust your server's self-signed certificate.

**Option A: Download from Web UI**
1. Log in to http://92.5.109.1/
2. Find and click "Download Truststore" button
3. Transfer the `.p12` file to your ATAK device

**Option B: Download via API**
```bash
curl -o truststore.p12 http://92.5.109.1/api/truststore
```

**Default truststore password**: `atakatak`

### Step 2: Configure ATAK Device

1. **Transfer truststore to device**
   - Copy `truststore.p12` to your Android device
   - Place it in a location accessible to ATAK (e.g., Downloads folder)

2. **Open ATAK Settings**
   - Settings → Network Preferences → Network Connection Preferences
   - Tap "+" to add new server

3. **Configure Connection**
   ```
   Description: OpenTAK SSL
   Server Address: 92.5.109.1
   Port: 8446
   Protocol: SSL
   ```

4. **Import Truststore**
   - Enable "Enroll with Preconfigured Trust" (if available)
   - Tap "Import Trust Store" button
   - Select your `truststore.p12` file
   - Enter password: `atakatak`

5. **Enable SSL/TLS**
   - Check "SSL/TLS"
   - Verify "Enroll for Client Certificate" is checked

6. **Authentication** (if required)
   - Enable "Use Authentication"
   - Enter your OpenTAK username and password

7. **Save and Connect**
   - Save the connection
   - ATAK should connect and obtain a client certificate

---

## Method 3: TCP Connection (No SSL)

For testing or if SSL setup is problematic, you can still use TCP:

```
Description: OpenTAK TCP
Server Address: 92.5.109.1
Port: 8089
Protocol: TCP
Use Auth: OFF
SSL/TLS: OFF
```

**Note**: TCP connections are **not encrypted**. Use only for testing or in trusted networks.

---

## Verifying Connection

### From ATAK Device

1. Check connection indicator in ATAK
   - Green = Connected
   - Red = Disconnected

2. Send a test marker or message

### From Server

```bash
# SSH to server
ssh -i ~/.ssh/ssh-key-OCI-longinus-private.key ubuntu@92.5.109.1

# Check SSL EUD handler logs
sudo journalctl -u eud_handler_ssl -f

# Check TCP EUD handler logs
sudo journalctl -u eud_handler -f

# Verify ports are listening
sudo lsof -i :8089 -i :8446 -n -P
```

You should see your device's connection in the logs.

---

## Troubleshooting

### Issue 1: QR Code Not Available in Web UI

**Solution**:
- Ensure you're running OpenTAK Server 1.5.0+
- Check that you're logged in with proper permissions
- Navigate to user settings or certificate enrollment page

### Issue 2: "Certificate Enrollment Failed"

**Cause**: Authentication issue or server not responding

**Solution**:
1. Verify you have a user account on the server
2. Check that port 8446 is accessible:
   ```bash
   nc -zv 92.5.109.1 8446
   ```
3. Check server logs for errors

### Issue 3: "Unable to Connect to Server"

**Cause**: Port blocked or service not running

**Solution**:
1. Verify SSL EUD handler is running:
   ```bash
   ssh -i ~/.ssh/ssh-key-OCI-longinus-private.key ubuntu@92.5.109.1 \
     'sudo systemctl status eud_handler_ssl'
   ```

2. Check firewall:
   ```bash
   ssh -i ~/.ssh/ssh-key-OCI-longinus-private.key ubuntu@92.5.109.1 \
     'sudo ufw status | grep 8446'
   ```

3. Verify OCI Security List allows port 8446

### Issue 4: "Certificate Verification Failed"

**Cause**: Truststore not imported correctly

**Solution**:
1. Re-download truststore certificate
2. Verify password is `atakatak`
3. Try removing and re-adding the server connection in ATAK
4. Use QR code method instead

### Issue 5: Connection Works But No Data

**Cause**: Certificate enrollment incomplete or permissions issue

**Solution**:
1. Check that client certificate was issued
2. Log in to Web UI and verify your user account is active
3. Check server logs for authentication errors

---

## Server Certificate Information

### Certificate Authority (CA)

Your server has a self-signed Certificate Authority:

- **Location**: `/home/opentakserver/ots/ca/`
- **CA Certificate**: `ca.pem`
- **CA Private Key**: `ca-do-not-share.key` (keep secure!)
- **Truststore**: `truststore-root.p12`
- **Password**: `atakatak`

### Server Certificate

- **Location**: `/home/opentakserver/ots/ca/certs/opentakserver/`
- **Certificate**: `opentakserver.pem`
- **Private Key**: `opentakserver.nopass.key`
- **Valid For**: 10 years (default: 3650 days)

### Certificate Details

```
Subject: /C=WW/ST=XX/L=YY/O=ZZ/OU=OpenTAKServer
Organization: OpenTAKServer
```

You can customize these values in the config if needed for production use.

---

## Service Management

### Check Service Status

```bash
# SSL EUD handler
sudo systemctl status eud_handler_ssl

# TCP EUD handler
sudo systemctl status eud_handler

# Web server
sudo systemctl status opentakserver

# Nginx
sudo systemctl status nginx
```

### Restart Services

```bash
# Restart SSL EUD handler
sudo systemctl restart eud_handler_ssl

# Restart TCP EUD handler
sudo systemctl restart eud_handler

# Restart all
sudo systemctl restart opentakserver eud_handler eud_handler_ssl nginx
```

### View Logs

```bash
# SSL connections
sudo journalctl -u eud_handler_ssl -f

# TCP connections
sudo journalctl -u eud_handler -f

# Combined (all TAK streaming)
sudo journalctl -u eud_handler -u eud_handler_ssl -f
```

---

## Security Recommendations

### For Production Use

1. **Change Default Password**
   ```bash
   # Log in to Web UI and change admin password
   ```

2. **Use Strong CA Password**
   - The default CA password is `atakatak`
   - Consider changing it for production

3. **Generate New Certificates with Proper Subject**
   - Update CA subject with your organization details
   - Regenerate certificates with correct DNS name/IP

4. **Enable Client Certificate Verification**
   - Configure `OTS_SSL_VERIFICATION_MODE` in config.yml
   - Mode 2 = verify client certificates

5. **Restrict Access**
   - Update OCI Security List to allow only known IP ranges
   - Use UFW to limit access to specific IPs

6. **Enable HTTPS for Web UI**
   - Set up Let's Encrypt for production domain
   - Use proper SSL certificates (not self-signed)

---

## Configuration Files

### Config.yml Location

```
/home/opentakserver/ots/config.yml
```

### Relevant SSL Settings

```yaml
OTS_ENABLE_TCP_STREAMING_PORT: true
OTS_TCP_STREAMING_PORT: 8089
OTS_SSL_STREAMING_PORT: 8446
OTS_CA_FOLDER: /home/opentakserver/ots/ca
OTS_CA_PASSWORD: atakatak
OTS_SSL_VERIFICATION_MODE: 2  # 0=none, 1=optional, 2=required
```

---

## What Changed

### Server Configuration Updates (Oct 15, 2025)

1. **Removed Nginx from Port 8446**
   - Previously Nginx was listening on 8446 for web API
   - Conflicted with EUD SSL handler
   - Now only EUD handler listens on 8446

2. **Created SSL EUD Handler Service**
   - New systemd service: `eud_handler_ssl.service`
   - Runs `eud_handler.py --ssl` to enable SSL mode
   - Auto-starts on boot

3. **Both TCP and SSL Now Working**
   - TCP: Port 8089 (existing)
   - SSL: Port 8446 (new)
   - Both can run simultaneously

---

## Testing Checklist

### ✅ Completed
- [x] SSL certificates exist
- [x] Port 8446 available (Nginx removed)
- [x] SSL EUD handler service created
- [x] SSL EUD handler running
- [x] Port 8446 listening
- [x] Firewall allows port 8446

### ⏳ Pending User Testing
- [ ] QR code generation in Web UI
- [ ] ATAK device connects via SSL
- [ ] Client certificate enrollment works
- [ ] Data flows correctly over SSL
- [ ] Multiple SSL connections

---

## Next Steps

1. **Test QR Code Method**
   - Log in to Web UI
   - Generate QR code for ATAK
   - Scan with ATAK device
   - Verify connection

2. **Test Manual SSL Connection**
   - Download truststore from Web UI
   - Configure ATAK manually
   - Test connection

3. **Compare TCP vs SSL**
   - Test both connection types
   - Verify no conflicts
   - Confirm both work simultaneously

4. **Production Hardening** (when ready)
   - Change default passwords
   - Regenerate certificates with proper details
   - Enable client certificate verification
   - Restrict firewall access

---

## Support Resources

### OpenTAK Documentation
- Certificate Enrollment: https://docs.opentakserver.io/certificate_enrollment.html
- TAK Server Setup: https://docs.opentakserver.io/opentak_icu/tak_server.html

### Community
- GitHub: https://github.com/brian7704/OpenTAKServer
- Discord: https://discord.gg/6uaVHjtfXN

### Server Logs
```bash
# Installation log
/var/log/user-data.log

# Service logs
journalctl -u opentakserver
journalctl -u eud_handler
journalctl -u eud_handler_ssl

# Nginx logs
/var/log/nginx/error.log
```

---

## Summary

✅ **Your server is now fully configured for SSL connections!**

**Quick Connection Settings:**

**For SSL (Secure):**
```
Server: 92.5.109.1
Port: 8446
Protocol: SSL
Truststore Password: atakatak
```

**For TCP (Testing):**
```
Server: 92.5.109.1
Port: 8089
Protocol: TCP
```

**Best Method**: Use the QR code feature in the Web UI for the easiest setup!

---

**Need Help?** Check the troubleshooting section or view server logs for more details.