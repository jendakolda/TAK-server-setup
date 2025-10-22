# WARP.md

This file provides guidance to WARP (warp.dev) and AI assistants when working with code in this repository.

## Project Overview

This repository contains TAK (Team Awareness Kit) infrastructure and tooling for Czech Republic operations. The project has three main components:

1. **TAK-server-setup**: Complete Terraform deployment for OpenTAK Server on Oracle Cloud Infrastructure with integrated CUZK tile server
2. **TAK-support-scripts**: Python scripts for downloading Czech maps and elevation data for ATAK clients
3. **czech_maps**: Storage for generated MBTiles map files

## Documentation Structure

- **README.md** - Main documentation, deployment overview, features
- **QUICK_START.md** - Fast 5-step deployment guide
- **docs/CUZK_TILE_SERVER.md** - Czech map integration guide (on-demand tile server)
- **docs/SSL_CONNECTION.md** - SSL/TLS configuration for ATAK clients
- **docs/PLUGIN_UPDATE.md** - ATAK plugin server configuration
- **atak-config/README.md** - ATAK map source XML configuration
- **terraform/README.md** - Terraform-specific documentation

## Key Commands

### Server Deployment
```bash
# Deploy OpenTAK Server infrastructure
cd TAK-server-setup/terraform
terraform init
terraform plan
terraform apply

# Get server IP after deployment  
terraform output instance_public_ip

# Destroy infrastructure
terraform destroy
```

### Map Data Generation
```bash
# Quick Prague test (recommended first)
cd TAK-support-scripts
python3 quick_test_prague.py

# Download full Czech Republic maps
python3 czech_map_downloader.py

# Generate elevation/hillshade data
python3 czech_elevation_downloader.py

# Install dependencies
pip install -r requirements.txt
# OR using uv (faster)
uv sync
```

### Server Management
```bash
# SSH to deployed server
ssh -i ~/.ssh/your-key.pem ubuntu@<server-ip>

# Check service status
sudo systemctl status opentakserver nginx

# View logs
sudo journalctl -u opentakserver -f
sudo tail -f /var/log/user-data.log

# Restart services
sudo systemctl restart opentakserver
sudo systemctl reload nginx
```

## Architecture

### Infrastructure (TAK-server-setup)
- **Terraform Configuration**: Complete IaC for Oracle Cloud Free Tier deployment
- **Components**: VM instance, VCN, security lists, internet gateway
- **Automated Installation**: `user_data.sh` script handles complete OpenTAK Server setup
- **Web UI**: React frontend with Vite build system
- **Backend**: Python Flask application with Socket.IO for real-time communication
- **Reverse Proxy**: Nginx configuration with specific Socket.IO handling
- **Critical Fix**: Separate proxy rules for `/api` (no upgrade header) vs `/socket.io` (with upgrade header)

### Map Generation (TAK-support-scripts)
- **Data Sources**: Czech CUZK ArcGIS REST services
- **Output Format**: MBTiles (SQLite-based tile format for mobile mapping)
- **Parallel Downloads**: ThreadPoolExecutor for concurrent tile fetching
- **Resume Support**: Can continue interrupted downloads
- **Services Used**:
  - `ZABAGED_POLOHOPIS`: Base topographic maps
  - `ZABAGED_VRSTEVNICE`: Contour lines
  - `3D/dmr5g`: Digital elevation model for hillshade generation

### Data Flow
```
Czech CUZK Services → Python Scripts → MBTiles → ATAK Mobile Client
                                    ↓
                          TAK Server (Oracle Cloud) ← Terraform
```

## Project Structure Insights

### Terraform Modules
- `main.tf`: Provider configuration and basic setup  
- `compute.tf`: VM instance definition with cloud-init
- `network.tf`: VCN, subnet, internet gateway, routing
- `security.tf`: Security lists and firewall rules
- `variables.tf`: Input parameters and their types
- `outputs.tf`: Export values like public IP
- `user_data.sh`: Complete installation automation script

### Critical Configuration Details
- **Memory Management**: 2GB swap file created for building Web UI on 1GB RAM free tier
- **Nginx Proxy**: Different headers for API calls vs WebSocket connections to prevent Socket.IO hanging
- **CUZK Tile Server**: Proxied through Nginx at `/tiles/` (localhost:8088) for on-demand Czech maps
- **Service Management**: Systemd services with auto-restart for reliability (opentakserver, cuzk_tile_server, etc.)
- **Port Configuration**: Full TAK port range (8089 TCP, 8443 SSL, 8080 API, etc.)

### Map Processing Pipeline
- **Tile Coordinate System**: Handles conversion between TMS and XYZ tile schemes
- **Error Handling**: Robust retry logic and data validation for remote services
- **Elevation Processing**: Numpy-based hillshade calculation with proper error handling
- **Geographic Bounds**: Czech Republic bbox (12.0-19.0°E, 48.5-51.1°N)

## Development Workflow

### Testing Strategy
1. Start with `quick_test_prague.py` for rapid validation
2. Small area download (~25km x 15km around Prague)
3. Test MBTiles in ATAK before full country download
4. Full Czech Republic download only after validation

### Deployment Process
1. Configure `terraform.tfvars` with Oracle Cloud credentials
2. Deploy infrastructure (15-20 minutes)
3. Server automatically installs and configures all components
4. Access via web browser at `http://<public-ip>/`
5. Default login: admin/admin123

### Troubleshooting Approach
- Installation logs: `/var/log/user-data.log`
- Service logs: `sudo journalctl -u opentakserver`
- CUZK Tile Server logs: `sudo journalctl -u cuzk_tile_server`
- Nginx logs: `/var/log/nginx/error.log`
- Common issues documented in `docs/` guides

## Dependencies & Requirements

### Server Deployment
- Oracle Cloud account (Free Tier sufficient)
- Terraform 1.0+
- SSH key pair for server access
- OCI CLI configured (optional)

### Map Scripts
- Python 3.12+ with libraries: requests, mercantile, numpy, Pillow
- Internet connection for Czech CUZK services
- Sufficient disk space for MBTiles output

## Cost Considerations

- **Oracle Cloud**: $0/month (Free Tier: VM.Standard.E2.1.Micro, 100GB storage)
- **Bandwidth**: 10TB/month outbound included
- **Resource Usage**: ~600MB RAM, minimal CPU usage

## Integration Points

### ATAK Client Configuration
- **Server Address**: `<public-ip>`
- **TCP Port**: 8089 (unencrypted)
- **SSL Port**: 8443 (encrypted)
- **Web Interface**: Port 80 (HTTP)
- **Tile Server**: `http://<public-ip>/tiles/` (on-demand maps)

### Map Integration

**Option 1: On-Demand Tiles (Recommended)**
1. Copy XML files from `atak-config/` to Android device
2. ATAK Settings → Import → Import Map Source
3. Select XML file (czech_topo.xml, czech_contours.xml, etc.)
4. Tiles download automatically as you navigate
5. Uses mobile data, cached on server for 30 days

**Option 2: Offline MBTiles**
1. Generate `.mbtiles` files using TAK-support-scripts
2. Copy to Android device
3. ATAK Settings → Layers → Import
4. Maps work completely offline
5. Larger file size, requires pre-download