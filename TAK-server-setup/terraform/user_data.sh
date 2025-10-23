#!/bin/bash

# OpenTAK Server Installation Script for Ubuntu 24.04
# This script installs OpenTAK Server from source with systemd
# This script runs on first boot via cloud-init

set -e

# Log all output
exec > >(tee /var/log/user-data.log) 2>&1

echo "Starting OpenTAK Server installation at $(date)"

# Update system packages
echo "Updating system packages..."
apt-get update -y
apt-get upgrade -y

# Install required dependencies
echo "Installing dependencies..."
apt-get install -y \
    git \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3-dev \
    nginx \
    ufw \
    curl \
    wget

# Install Node.js 20 (required for Web UI build)
echo "Installing Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Create swap space for Web UI build (2GB)
echo "Creating swap space..."
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile none swap sw 0 0" >> /etc/fstab

# Configure firewall
echo "Configuring firewall..."
ufw --force enable
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8080/tcp
ufw allow 8089/tcp
ufw allow 8443/tcp
ufw allow 8446/tcp
ufw allow 8554/tcp
ufw allow 8000:8010/udp
ufw allow 8088/tcp

# Create opentakserver user
echo "Creating opentakserver user..."
useradd -m -s /bin/bash opentakserver

# Create OpenTAK directories
mkdir -p /home/opentakserver/ots/{data,logs,certs}
chown -R opentakserver:opentakserver /home/opentakserver/ots

# Clone OpenTAK Server backend
echo "Cloning OpenTAK Server backend..."
sudo -u opentakserver git clone https://github.com/brian7704/OpenTAKServer.git /home/opentakserver/OpenTAKServer

# Create Python virtual environment
echo "Creating Python virtual environment..."
sudo -u opentakserver bash -c "cd /home/opentakserver/OpenTAKServer && python3 -m venv opentakserver_venv"

# Install Poetry and OpenTAK Server
echo "Installing OpenTAK Server..."
sudo -u opentakserver bash -c "cd /home/opentakserver/OpenTAKServer && source opentakserver_venv/bin/activate && pip install --upgrade pip && pip install poetry && pip install -e ."

# Initialize database
echo "Initializing database..."
sudo -u opentakserver bash -c "cd /home/opentakserver/OpenTAKServer && source opentakserver_venv/bin/activate && python -c 'from opentakserver import create_app; app = create_app(); app.app_context().push()'"

# Create systemd service for OpenTAK Server
echo "Creating systemd service..."
cat > /etc/systemd/system/opentakserver.service << 'EOF'
[Unit]
Description=OpenTAK Server
After=network.target

[Service]
Type=simple
User=opentakserver
WorkingDirectory=/home/opentakserver/OpenTAKServer
Environment="PATH=/home/opentakserver/OpenTAKServer/opentakserver_venv/bin"
ExecStart=/home/opentakserver/OpenTAKServer/opentakserver_venv/bin/python /home/opentakserver/OpenTAKServer/opentakserver/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start OpenTAK Server
systemctl daemon-reload
systemctl enable opentakserver
systemctl start opentakserver

# Wait for backend to initialize
echo "Waiting for backend to initialize..."
sleep 15

# Clone OpenTAK Web UI
echo "Cloning OpenTAK Web UI..."
sudo -u opentakserver git clone https://github.com/brian7704/OpenTAKServer-UI.git /home/opentakserver/OpenTAKServer-UI

# Build Web UI
echo "Building Web UI (this may take several minutes)..."
sudo -u opentakserver bash -c "cd /home/opentakserver/OpenTAKServer-UI && npm install --legacy-peer-deps && NODE_OPTIONS='--max-old-space-size=1536' npm run build"

# Set proper permissions for Nginx
echo "Setting permissions..."
chmod 755 /home/opentakserver
chmod 755 /home/opentakserver/OpenTAKServer-UI
chmod -R 755 /home/opentakserver/OpenTAKServer-UI/dist

# Configure Nginx
echo "Configuring Nginx..."
cat > /etc/nginx/sites-available/opentakserver << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name _;

    # Allow larger file uploads (for APK files, data packages, etc.)
    client_max_body_size 100M;

    root /home/opentakserver/OpenTAKServer-UI/dist;
    index index.html;

    # Serve static files
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy API requests to backend (NO upgrade header - causes Socket.IO to hang)
    location /api {
        proxy_pass http://127.0.0.1:8081;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Proxy WebSocket connections (WITH upgrade header for Socket.IO)
    location /socket.io {
        proxy_pass http://127.0.0.1:8081;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }

    # CUZK Tile Server proxy (Czech maps for ATAK)
    location /tiles/ {
        proxy_pass http://127.0.0.1:8088/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}

server {
    listen 8080;
    listen [::]:8080;
    server_name _;

    # Allow larger file uploads
    client_max_body_size 100M;

    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

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
EOF

# Enable Nginx site
ln -sf /etc/nginx/sites-available/opentakserver /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and restart Nginx
nginx -t
systemctl restart nginx

# Wait for services to stabilize
sleep 5

# Configure OpenTAK for production
echo "Configuring OpenTAK Server..."
cat > /home/opentakserver/OpenTAKServer/config.py << 'EOF'
# Override default config for production
OTS_LISTENER_ADDRESS = "0.0.0.0"
OTS_LISTENER_PORT = 8081

# Fix Flask-Security for reverse proxy
WTF_CSRF_CHECK_DEFAULT = False
WTF_CSRF_ENABLED = False
SECURITY_CSRF_PROTECT_MECHANISMS = []
SECURITY_CSRF_IGNORE_UNAUTH_ENDPOINTS = True
SESSION_COOKIE_SECURE = False
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = "Lax"
PREFERRED_URL_SCHEME = "http"

# Enable TAK protocol streaming
OTS_ENABLE_TCP_STREAMING_PORT = True
OTS_TCP_STREAMING_PORT = 8089
OTS_SSL_STREAMING_PORT = 8446
EOF

chown opentakserver:opentakserver /home/opentakserver/OpenTAKServer/config.py

# Create admin user
echo "Creating admin user..."
sudo -u opentakserver bash -c "cd /home/opentakserver/OpenTAKServer && source opentakserver_venv/bin/activate && python << 'PYEOF'
import uuid
from opentakserver.app import create_app, db
from opentakserver.models.user import User
from flask_security import hash_password

app = create_app()
with app.app_context():
    # Check if admin user already exists
    admin = User.query.filter_by(username='admin').first()
    if not admin:
        user = User(
            username='admin',
            email='admin@opentakserver.local',
            password=hash_password('admin123'),
            active=True,
            fs_uniquifier=str(uuid.uuid4())
        )
        from opentakserver.models.role import Role
        admin_role = Role.query.filter_by(name='administrator').first()
        if admin_role:
            user.roles.append(admin_role)
        db.session.add(user)
        db.session.commit()
        print('Admin user created successfully')
    else:
        print('Admin user already exists')
PYEOF
"

# Wait for config.yml to be created by first run
sleep 10

# Update config.yml for TAK streaming ports
echo "Configuring TAK streaming ports..."
sudo -u opentakserver sed -i "s/OTS_TCP_STREAMING_PORT: 8088/OTS_TCP_STREAMING_PORT: 8089/" /home/opentakserver/ots/config.yml
sudo -u opentakserver sed -i "s/OTS_SSL_STREAMING_PORT: 8089/OTS_SSL_STREAMING_PORT: 8446/" /home/opentakserver/ots/config.yml

# Create EUD handler systemd service for TCP streaming
echo "Creating EUD handler service for TCP streaming..."
cat > /etc/systemd/system/eud_handler.service << 'EOF'
[Unit]
Description=OpenTAK Server EUD Handler (TCP)
After=network.target rabbitmq-server.service opentakserver.service
Requires=rabbitmq-server.service opentakserver.service

[Service]
Type=simple
User=opentakserver
Group=opentakserver
WorkingDirectory=/home/opentakserver/OpenTAKServer
Environment="PATH=/home/opentakserver/OpenTAKServer/opentakserver_venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/home/opentakserver/OpenTAKServer/opentakserver_venv/bin/python /home/opentakserver/OpenTAKServer/opentakserver/eud_handler/eud_handler.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start TCP EUD handler
systemctl daemon-reload
systemctl enable eud_handler
systemctl start eud_handler

# Wait for TCP handler to stabilize
sleep 5

# Create EUD handler systemd service for SSL streaming
echo "Creating EUD handler service for SSL streaming..."
cat > /etc/systemd/system/eud_handler_ssl.service << 'EOF'
[Unit]
Description=OpenTAK Server EUD Handler (SSL)
After=network.target rabbitmq-server.service opentakserver.service eud_handler.service
Requires=rabbitmq-server.service opentakserver.service

[Service]
Type=simple
User=opentakserver
Group=opentakserver
WorkingDirectory=/home/opentakserver/OpenTAKServer
Environment="PATH=/home/opentakserver/OpenTAKServer/opentakserver_venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/home/opentakserver/OpenTAKServer/opentakserver_venv/bin/python /home/opentakserver/OpenTAKServer/opentakserver/eud_handler/eud_handler.py --ssl
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start SSL EUD handler
systemctl daemon-reload
systemctl enable eud_handler_ssl
systemctl start eud_handler_ssl

# Wait for SSL handler to stabilize
sleep 5

# Create CoT Parser systemd service (CRITICAL - Required for markers to appear on map!)
echo "Creating CoT Parser service..."
cat > /etc/systemd/system/cot_parser.service << 'EOF'
[Unit]
Description=OpenTAK Server CoT Parser
After=network.target rabbitmq-server.service opentakserver.service
Requires=rabbitmq-server.service opentakserver.service

[Service]
Type=simple
User=opentakserver
Group=opentakserver
WorkingDirectory=/home/opentakserver/OpenTAKServer
Environment="PATH=/home/opentakserver/OpenTAKServer/opentakserver_venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/home/opentakserver/OpenTAKServer/opentakserver_venv/bin/python /home/opentakserver/OpenTAKServer/opentakserver/cot_parser/cot_parser.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start CoT Parser
systemctl daemon-reload
systemctl enable cot_parser
systemctl start cot_parser

# Wait for CoT parser to stabilize
sleep 5

# Install CUZK Tile Server for on-demand Czech map downloads
echo "Installing CUZK Tile Server..."
sudo -u opentakserver bash -c "cd /home/opentakserver/OpenTAKServer && source opentakserver_venv/bin/activate && pip install flask mercantile pillow"

# Create the tile server script
cat > /home/opentakserver/cuzk_tile_server.py << 'TILEEOF'
#!/usr/bin/env python3
"""
CUZK Tile Server Adapter for ATAK
Translates XYZ tile requests into ArcGIS REST API calls to Czech CUZK services.
"""

from flask import Flask, Response, abort
import requests
import mercantile
import hashlib
import time
from pathlib import Path
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

app = Flask(__name__)

CUZK_BASE_URL = "https://ags.cuzk.gov.cz/arcgis/rest/services"
CACHE_DIR = "/home/opentakserver/ots/tile_cache"
CACHE_ENABLED = True
TILE_SIZE = 256

AVAILABLE_SERVICES = {
    'topo': 'ZABAGED_POLOHOPIS',
    'contours': 'ZABAGED_VRSTEVNICE',
    'ortophoto': 'ortofoto/ortofoto',
    'zmvm': 'ZMVM/zmvm',
}

class TileCache:
    def __init__(self, cache_dir):
        self.cache_dir = Path(cache_dir)
        if CACHE_ENABLED:
            self.cache_dir.mkdir(parents=True, exist_ok=True)

    def get_cache_path(self, service, z, x, y):
        tile_id = f"{service}/{z}/{x}/{y}"
        hash_dir = hashlib.md5(tile_id.encode()).hexdigest()[:2]
        cache_path = self.cache_dir / service / str(z) / hash_dir
        cache_path.mkdir(parents=True, exist_ok=True)
        return cache_path / f"{x}_{y}.png"

    def get(self, service, z, x, y):
        if not CACHE_ENABLED:
            return None
        cache_file = self.get_cache_path(service, z, x, y)
        if cache_file.exists():
            age_days = (time.time() - cache_file.stat().st_mtime) / 86400
            if age_days < 30:
                return cache_file.read_bytes()
            else:
                cache_file.unlink()
        return None

    def set(self, service, z, x, y, data):
        if not CACHE_ENABLED or not data:
            return
        try:
            cache_file = self.get_cache_path(service, z, x, y)
            cache_file.write_bytes(data)
        except Exception as e:
            logger.error(f"Failed to cache tile: {e}")

tile_cache = TileCache(CACHE_DIR)

def download_arcgis_tile(service_path, x, y, z):
    bbox = mercantile.bounds(x, y, z)
    url = (f"{CUZK_BASE_URL}/{service_path}/MapServer/export?"
           f"bbox={bbox.west},{bbox.south},{bbox.east},{bbox.north}&"
           f"bboxSR=4326&imageSR=3857&size={TILE_SIZE},{TILE_SIZE}&"
           f"format=png&transparent=true&f=image")
    try:
        response = requests.get(url, timeout=30, headers={'User-Agent': 'ATAK-CUZK-Tile-Server/1.0'})
        if response.status_code == 200 and 'image' in response.headers.get('Content-Type', ''):
            return response.content
    except Exception as e:
        logger.error(f"Download failed: {e}")
    return None

@app.route('/health')
def health_check():
    return {'status': 'ok', 'service': 'CUZK Tile Server'}

@app.route('/services')
def list_services():
    return {'services': AVAILABLE_SERVICES, 'usage': '/{service}/{z}/{x}/{y}.png'}

@app.route('/<service>/<int:z>/<int:x>/<int:y>.png')
def get_tile(service, z, x, y):
    if service not in AVAILABLE_SERVICES:
        abort(404)
    if z < 0 or z > 20:
        abort(400)

    cached_tile = tile_cache.get(service, z, x, y)
    if cached_tile:
        return Response(cached_tile, mimetype='image/png')

    tile_data = download_arcgis_tile(AVAILABLE_SERVICES[service], x, y, z)
    if tile_data:
        tile_cache.set(service, z, x, y, tile_data)
        return Response(tile_data, mimetype='image/png')
    abort(404)

@app.route('/')
def index():
    return """<h1>CUZK Tile Server for ATAK</h1>
    <p>Available services: topo, contours, ortophoto, zmvm</p>
    <p>Usage: /{service}/{z}/{x}/{y}.png</p>"""

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8088, debug=False)
TILEEOF

chown opentakserver:opentakserver /home/opentakserver/cuzk_tile_server.py
chmod +x /home/opentakserver/cuzk_tile_server.py

# Create tile cache directory
mkdir -p /home/opentakserver/ots/tile_cache
chown -R opentakserver:opentakserver /home/opentakserver/ots/tile_cache

# Create CUZK Tile Server systemd service
echo "Creating CUZK Tile Server service..."
cat > /etc/systemd/system/cuzk_tile_server.service << 'EOF'
[Unit]
Description=CUZK Tile Server for ATAK
After=network.target opentakserver.service
Wants=opentakserver.service

[Service]
Type=simple
User=opentakserver
Group=opentakserver
WorkingDirectory=/home/opentakserver
Environment="PATH=/home/opentakserver/OpenTAKServer/opentakserver_venv/bin:/usr/local/bin:/usr/bin:/bin"
Environment="PYTHONUNBUFFERED=1"
ExecStart=/home/opentakserver/OpenTAKServer/opentakserver_venv/bin/python /home/opentakserver/cuzk_tile_server.py
Restart=always
RestartSec=10
NoNewPrivileges=true
PrivateTmp=true
StandardOutput=journal
StandardError=journal
SyslogIdentifier=cuzk-tile-server

[Install]
WantedBy=multi-user.target
EOF

# Enable and start CUZK Tile Server
systemctl daemon-reload
systemctl enable cuzk_tile_server
systemctl start cuzk_tile_server

# Wait for tile server to stabilize
sleep 3

# Create status file
PUBLIC_IP=$(curl -s http://169.254.169.254/opc/v1/instance/metadata/public-ip 2>/dev/null || echo 'YOUR_PUBLIC_IP')

cat > /home/opentakserver/installation_status.txt << EOF
OpenTAK Server installation completed at $(date)

Access Information:
- Web Interface: http://${PUBLIC_IP}/
- TAK API: http://${PUBLIC_IP}:8080/
- TAK TCP Streaming: ${PUBLIC_IP}:8089
- TAK SSL Streaming: ${PUBLIC_IP}:8446 (requires client certificates)

Login Credentials:
- Username: admin
- Password: admin123

ATAK Connection Settings:
For TCP (simple, no certificates):
- Server Address: ${PUBLIC_IP}
- Port: 8089
- Protocol: TCP
- Use Auth: OFF

For SSL (secure, with certificates):
- Server Address: ${PUBLIC_IP}
- Port: 8446
- Protocol: SSL
- Download Truststore: http://${PUBLIC_IP}/api/truststore
- Truststore Password: atakatak
- Or use QR Code from Web UI for automatic setup

Czech Map Integration:
- CUZK Tile Server: http://${PUBLIC_IP}:8088/
- Available maps: topo, contours, ortophoto, zmvm
- Health check: http://${PUBLIC_IP}:8088/health
- ATAK XML configs: See CUZK_TILE_SERVER_GUIDE.md

Service Status:
- Backend: systemctl status opentakserver
- TCP Streaming: systemctl status eud_handler
- SSL Streaming: systemctl status eud_handler_ssl
- CoT Parser: systemctl status cot_parser
- CUZK Tile Server: systemctl status cuzk_tile_server
- Nginx: systemctl status nginx

Logs:
- Installation: /var/log/user-data.log
- OpenTAK: journalctl -u opentakserver -f
- TCP EUD Handler: journalctl -u eud_handler -f
- SSL EUD Handler: journalctl -u eud_handler_ssl -f
- CoT Parser: journalctl -u cot_parser -f
- CUZK Tile Server: journalctl -u cuzk_tile_server -f
- Nginx: /var/log/nginx/error.log
EOF

chown opentakserver:opentakserver /home/opentakserver/installation_status.txt

echo "========================================"
echo "OpenTAK Server installation completed!"
echo "Web Interface: http://${PUBLIC_IP}/"
echo "TAK TCP Streaming: ${PUBLIC_IP}:8089"
echo "TAK SSL Streaming: ${PUBLIC_IP}:8446"
echo "========================================"
echo "ATAK Connection Options:"
echo "  - TCP: Port 8089 (no certificates)"
echo "  - SSL: Port 8446 (with certificates)"
echo "  - Use QR Code from Web UI for easy SSL setup"
echo "========================================"
echo "User data script execution completed successfully at $(date)!"
