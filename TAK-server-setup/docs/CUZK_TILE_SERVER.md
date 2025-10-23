# CUZK Tile Server for ATAK - Complete Guide

This guide explains how to deploy and use the CUZK (Czech mapping authority) tile server integration for ATAK.

## 📋 Table of Contents

1. [What This Does](#what-this-does)
2. [Architecture Overview](#architecture-overview)
3. [Deployment Instructions](#deployment-instructions)
4. [ATAK Configuration](#atak-configuration)
5. [Usage Guide](#usage-guide)
6. [Troubleshooting](#troubleshooting)
7. [Advanced Configuration](#advanced-configuration)

---

## What This Does

This integration allows you to access official Czech Republic maps directly in ATAK without pre-downloading them. Instead of downloading gigabytes of map tiles beforehand, ATAK will download only the map tiles you need, when you need them, using your mobile data connection.

### Benefits

- **On-demand downloading**: Download only what you see, saving storage space
- **Always up-to-date**: Get the latest maps from CUZK every time
- **Multiple map types**: Choose between topographic, aerial, contours, and base maps
- **Automatic caching**: Previously viewed areas are cached on the server for faster access
- **Data efficient**: Only downloads tiles at the zoom level you're viewing

### Available Map Sources

1. **Czech Topographic** (`/topo`) - Detailed topographic maps with roads, buildings, terrain features
2. **Czech Contours** (`/contours`) - Elevation contour lines (use as overlay)
3. **Czech Ortophoto** (`/ortophoto`) - High-resolution aerial imagery
4. **Czech Base Map** (`/zmvm`) - Simplified base map for general navigation

---

## Architecture Overview

```
┌─────────────┐         ┌──────────────────┐         ┌─────────────────┐
│             │  HTTP   │                  │  HTTPS  │                 │
│    ATAK     │ ───────>│  Tile Server     │ ───────>│  CUZK ArcGIS    │
│  (Mobile)   │         │  (Your Server)   │         │  REST Service   │
│             │ <───────│  Port 8088       │ <───────│                 │
└─────────────┘         └──────────────────┘         └─────────────────┘
                               │
                               │ Stores tiles
                               ▼
                        ┌──────────────┐
                        │ Tile Cache   │
                        │ (30 day TTL) │
                        └──────────────┘
```

**How it works:**

1. **ATAK** requests a tile: `http://your-server:8088/topo/12/2234/1456.png`
2. **Tile Server** checks if tile is cached
   - If cached (and < 30 days old): Returns immediately
   - If not cached: Proceeds to step 3
3. **Tile Server** converts tile coordinates to geographic bounds
4. **Tile Server** requests map from CUZK ArcGIS service
5. **CUZK** generates and returns the map image
6. **Tile Server** caches the tile and returns it to ATAK

---

## Deployment Instructions

### Option 1: Automatic Deployment (Recommended)

If you're deploying a new server with Terraform, the tile server will be automatically installed and configured.

**Steps:**
1. The `user_data.sh` script will automatically:
   - Install required Python dependencies (Flask, mercantile, requests)
   - Copy the tile server to `/home/opentakserver/cuzk_tile_server.py`
   - Install and start the systemd service
   - Configure firewall rules

2. Verify installation after deployment:
   ```bash
   # Check service status
   systemctl status cuzk_tile_server

   # View logs
   journalctl -u cuzk_tile_server -f

   # Test the server
   curl http://localhost:8088/health
   ```

### Option 2: Manual Deployment (Existing Server)

If you already have a running OpenTAK server, follow these steps:

#### Step 1: Install Dependencies

```bash
# Activate the OpenTAK virtual environment
cd /home/opentakserver/OpenTAKServer
source opentakserver_venv/bin/activate

# Install required packages
pip install flask mercantile requests pillow
```

#### Step 2: Deploy the Tile Server

```bash
# Copy the tile server script
sudo cp TAK-support-scripts/cuzk_tile_server.py /home/opentakserver/cuzk_tile_server.py
sudo chown opentakserver:opentakserver /home/opentakserver/cuzk_tile_server.py
sudo chmod +x /home/opentakserver/cuzk_tile_server.py

# Create cache directory
sudo mkdir -p /home/opentakserver/ots/tile_cache
sudo chown -R opentakserver:opentakserver /home/opentakserver/ots/tile_cache
```

#### Step 3: Install systemd Service

```bash
# Copy systemd service file
sudo cp TAK-server-setup/systemd/cuzk_tile_server.service /etc/systemd/system/

# Reload systemd and start service
sudo systemctl daemon-reload
sudo systemctl enable cuzk_tile_server
sudo systemctl start cuzk_tile_server

# Check status
sudo systemctl status cuzk_tile_server
```

#### Step 4: Configure Firewall

```bash
# Allow port 8088 for tile server
sudo ufw allow 8088/tcp
```

#### Step 5: Verify Installation

```bash
# Check if server is responding
curl http://localhost:8088/health

# You should see: {"service":"CUZK Tile Server","status":"ok"}

# Check available services
curl http://localhost:8088/services
```

---

## ATAK Configuration

Now that the server is running, you need to configure ATAK to use it.

### Step 1: Prepare XML Configuration Files

1. **Find your server's IP address:**
   ```bash
   curl http://169.254.169.254/opc/v1/instance/metadata/public-ip
   ```

2. **Edit the XML files** in `TAK-server-setup/atak-config/`:
   - Open each XML file
   - Replace `YOUR_SERVER_IP` with your actual server IP address
   - Example: Change `http://YOUR_SERVER_IP:8088/topo/{z}/{x}/{y}.png`
             to `http://123.45.67.89:8088/topo/{z}/{x}/{y}.png`

### Step 2: Transfer XML Files to Your Android Device

**Option A: USB Transfer**
1. Connect your Android device to your computer
2. Copy the XML files to your device's Download folder

**Option B: Email/Cloud**
1. Email the XML files to yourself
2. Download them on your Android device

**Option C: Direct Download**
1. You can also host these files on your server and download via browser

### Step 3: Import Map Sources in ATAK

1. Open ATAK on your Android device
2. Tap the **hamburger menu** (☰) in the top-left
3. Go to **Settings** → **Map Sources**
4. Tap the **"+"** button or **Import**
5. Select **Import Map Source**
6. Navigate to and select one of the XML files (e.g., `czech_topo.xml`)
7. The map source will be added to your available layers
8. Repeat for all map types you want to use

### Step 4: Enable Map Layers

1. In ATAK, tap the **layers icon** (looks like stacked papers)
2. You should see your new map sources:
   - Czech Topographic
   - Czech Contours
   - Czech Ortophoto
   - Czech Base Map
3. Tap on a map source to select it as your base layer
4. For overlays (like contours), long-press to enable as an overlay

---

## Usage Guide

### Selecting Map Layers

**For Base Maps:**
- Tap the layers icon
- Select "Czech Topographic", "Czech Ortophoto", or "Czech Base Map"
- The map will reload with your selected layer

**For Overlays:**
- Tap the layers icon
- Long-press "Czech Contours"
- Select "Enable as Overlay"
- Adjust opacity if needed

### Data Usage Tips

**To minimize data usage:**

1. **Pre-cache areas before deployment:**
   - While on WiFi, zoom to areas you'll need
   - Pan around to download tiles
   - ATAK will cache these for offline use

2. **Use lower zoom levels:**
   - Zoom levels 6-12 use much less data than 16-18
   - Only zoom in when you need detail

3. **Use the simple base map for navigation:**
   - The `zmvm` base map uses less data than detailed topo
   - Switch to topo or ortophoto only when needed

4. **Enable offline mode when not needed:**
   - ATAK Settings → Map Sources → Enable offline mode
   - This prevents automatic tile downloads

### Recommended Combinations

**General Navigation:**
- Base: Czech Base Map (zmvm)
- Overlay: None
- Data usage: Low

**Tactical Planning:**
- Base: Czech Topographic
- Overlay: Czech Contours
- Data usage: Medium

**Detailed Reconnaissance:**
- Base: Czech Ortophoto
- Overlay: Czech Contours
- Data usage: High (but worth it!)

---

## Troubleshooting

### Server Issues

#### Tile server not responding

```bash
# Check if service is running
systemctl status cuzk_tile_server

# If not running, start it
sudo systemctl start cuzk_tile_server

# Check logs for errors
journalctl -u cuzk_tile_server -n 50
```

#### Tiles not loading / Blank tiles

```bash
# Check if server can reach CUZK
curl -I https://ags.cuzk.gov.cz/arcgis/rest/services

# Test tile download directly
curl -o test.png "http://localhost:8088/topo/10/557/354.png"

# Check the downloaded image
file test.png  # Should say "PNG image data"
```

#### Cache issues

```bash
# Check cache directory size
du -sh /home/opentakserver/ots/tile_cache

# Clear cache if needed
sudo rm -rf /home/opentakserver/ots/tile_cache/*
sudo systemctl restart cuzk_tile_server
```

### ATAK Issues

#### Maps not appearing in ATAK

1. Verify the XML files have the correct server IP
2. Check that port 8088 is accessible from your device:
   ```bash
   # On your Android device, use a browser to visit:
   http://YOUR_SERVER_IP:8088/health
   ```
3. Ensure you're connected to the internet (not just WiFi without data)

#### Tiles loading slowly

1. Check your internet connection speed
2. Verify server has good bandwidth to CUZK
3. Lower the max workers if server is overwhelmed:
   - Edit `/home/opentakserver/cuzk_tile_server.py`
   - Change `max_workers=8` to `max_workers=4`
   - Restart: `sudo systemctl restart cuzk_tile_server`

#### Wrong map area showing

1. Verify you're within Czech Republic bounds (12.09°-18.86°E, 48.55°-51.06°N)
2. These maps only cover Czech Republic
3. Outside this area, tiles will be blank

---

## Advanced Configuration

### Adjusting Cache Duration

Edit `/home/opentakserver/cuzk_tile_server.py`:

```python
# Find this line (around line 67):
if age_days < 30:

# Change 30 to your preferred number of days:
if age_days < 90:  # Cache for 90 days
```

Then restart: `sudo systemctl restart cuzk_tile_server`

### Disabling Cache

Edit `/home/opentakserver/cuzk_tile_server.py`:

```python
# Find this line (around line 13):
CACHE_ENABLED = True

# Change to:
CACHE_ENABLED = False
```

Then restart: `sudo systemctl restart cuzk_tile_server`

### Changing Port

If port 8088 conflicts with another service:

1. Edit `/home/opentakserver/cuzk_tile_server.py`:
   ```python
   # Find the last line:
   app.run(host='0.0.0.0', port=8088, debug=False)

   # Change to:
   app.run(host='0.0.0.0', port=9088, debug=False)
   ```

2. Update firewall:
   ```bash
   sudo ufw allow 9088/tcp
   ```

3. Update all XML files with the new port

4. Restart service:
   ```bash
   sudo systemctl restart cuzk_tile_server
   ```

### Adding Authentication

To require authentication for tile access:

1. Edit `/home/opentakserver/cuzk_tile_server.py`
2. Add Flask-HTTPAuth:
   ```bash
   pip install flask-httpauth
   ```
3. Add authentication decorator to tile endpoint (see Flask-HTTPAuth docs)

### Performance Tuning

For high-traffic servers:

1. **Use a production WSGI server** (Gunicorn):
   ```bash
   pip install gunicorn
   ```

2. Edit `/etc/systemd/system/cuzk_tile_server.service`:
   ```ini
   ExecStart=/home/opentakserver/OpenTAKServer/opentakserver_venv/bin/gunicorn \
       --bind 0.0.0.0:8088 \
       --workers 4 \
       --timeout 120 \
       cuzk_tile_server:app
   ```

3. Restart: `sudo systemctl restart cuzk_tile_server`

---

## Monitoring

### View Live Logs

```bash
# Follow tile server logs
journalctl -u cuzk_tile_server -f

# Show only errors
journalctl -u cuzk_tile_server -p err -f
```

### Check Service Status

```bash
# Quick status
systemctl status cuzk_tile_server

# Detailed status with recent logs
systemctl status cuzk_tile_server -l -n 50
```

### Monitor Cache Size

```bash
# Check cache size
du -sh /home/opentakserver/ots/tile_cache

# Count cached tiles
find /home/opentakserver/ots/tile_cache -name "*.png" | wc -l
```

---

## Support

For issues or questions:
- Check the logs: `journalctl -u cuzk_tile_server -f`
- Test server health: `curl http://YOUR_SERVER_IP:8088/health`
- Verify CUZK availability: `curl -I https://ags.cuzk.gov.cz/arcgis/rest/services`

---

## Credits

- **CUZK (ČÚZK)**: Czech Office for Surveying, Mapping and Cadastre - Official map data provider
- **Map data**: © ČÚZK - https://geoportal.cuzk.cz/
- **OpenTAK Server**: https://github.com/brian7704/OpenTAKServer