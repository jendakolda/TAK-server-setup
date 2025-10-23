# ATAK Map Source Configuration Files

These XML files configure ATAK to download Czech maps on-demand from your tile server.

## Quick Start

### 1. Update Server IP Address

**Before using these files**, you MUST replace `YOUR_SERVER_IP` with your actual server IP address in ALL XML files.

Find your server IP:
```bash
# On your server, run:
curl http://169.254.169.254/opc/v1/instance/metadata/public-ip
```

Then edit each XML file and replace:
```xml
<url>http://YOUR_SERVER_IP:8088/topo/{z}/{x}/{y}.png</url>
```

With (example):
```xml
<url>http://123.45.67.89:8088/topo/{z}/{x}/{y}.png</url>
```

### 2. Transfer Files to Android Device

Choose one method:
- **USB**: Connect device and copy to `Download` folder
- **Email**: Email files to yourself and download
- **Cloud**: Upload to Google Drive/Dropbox and download

### 3. Import into ATAK

1. Open ATAK
2. Tap ☰ menu → Settings → Map Sources
3. Tap "+" or "Import"
4. Select "Import Map Source"
5. Navigate to and select an XML file
6. Repeat for each map type you want

## Available Map Sources

### czech_topo.xml
**Czech Topographic Map** - Detailed topographic maps with roads, buildings, terrain features
- **Best for**: General navigation, tactical planning
- **Data usage**: Medium
- **Zoom levels**: 6-18

### czech_contours.xml
**Czech Contour Lines** - Elevation contour lines overlay
- **Best for**: Terrain analysis, elevation planning
- **Data usage**: Low (transparent overlay)
- **Zoom levels**: 8-16
- **Note**: Use as overlay on top of base map

### czech_ortophoto.xml
**Czech Aerial Imagery** - High-resolution satellite/aerial photography
- **Best for**: Detailed reconnaissance, current conditions
- **Data usage**: High
- **Zoom levels**: 6-20

### czech_basemap.xml
**Czech Base Map** - Simplified general-purpose map
- **Best for**: Low-data situations, overview navigation
- **Data usage**: Low
- **Zoom levels**: 6-18

## Usage in ATAK

### Selecting a Base Layer
1. Tap the layers icon (stacked papers)
2. Select your desired map source
3. Map will reload with the new layer

### Using Contours as Overlay
1. Tap the layers icon
2. **Long-press** "Czech Contours"
3. Select "Enable as Overlay"
4. Adjust opacity if needed (0.7 recommended)

## Troubleshooting

### Maps not loading?

1. **Check server IP**: Verify you replaced `YOUR_SERVER_IP` correctly
2. **Test server**: Open `http://YOUR_SERVER_IP:8088/health` in a browser
3. **Check connectivity**: Ensure you have internet access
4. **Verify firewall**: Port 8088 must be open on your server

### Blank tiles?

- These maps only cover **Czech Republic** (12.09°-18.86°E, 48.55°-51.06°N)
- Outside this area, tiles will be blank or fail to load

### Slow loading?

- First load is always slower (downloading from CUZK)
- Subsequent loads are faster (cached on server)
- Try zooming out for lower detail/faster loading

## Data Usage Estimates

Based on typical usage patterns:

| Map Type | Light Use | Moderate Use | Heavy Use |
|----------|-----------|--------------|-----------|
| Topo | 5-10 MB/hr | 20-50 MB/hr | 100+ MB/hr |
| Ortophoto | 10-20 MB/hr | 50-100 MB/hr | 200+ MB/hr |
| Contours | 2-5 MB/hr | 10-20 MB/hr | 30+ MB/hr |
| Base Map | 2-5 MB/hr | 10-20 MB/hr | 40+ MB/hr |

**Tips to reduce data usage:**
- Pre-cache areas on WiFi before deployment
- Use lower zoom levels (6-12 vs 16-18)
- Use base map instead of topo when detail isn't needed
- Enable ATAK offline mode when not actively navigating

## For More Information

See **CUZK_TILE_SERVER_GUIDE.md** for:
- Complete deployment instructions
- Server configuration options
- Performance tuning
- Advanced troubleshooting