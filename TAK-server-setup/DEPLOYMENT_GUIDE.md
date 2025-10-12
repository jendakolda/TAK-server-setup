# OpenTAK Server - Complete Deployment Guide

## Quick Start

This guide will help you deploy a fully functional OpenTAK Server on Oracle Cloud Infrastructure using Terraform.

## Prerequisites

Before you begin, ensure you have:

1. **Oracle Cloud Account** (Free Tier is sufficient)
2. **Terraform** installed (v1.0 or later)
   ```bash
   terraform --version
   ```
3. **OCI CLI** configured (optional, but helpful)
4. **SSH key pair** for server access

## Step-by-Step Deployment

### Step 1: Prepare OCI Credentials

1. Log into Oracle Cloud Console
2. Navigate to **Identity** → **Users** → Your User → **API Keys**
3. Click **Add API Key** and download:
   - Private key file (e.g., `oci_api_key.pem`)
   - Configuration file preview (contains your credentials)

4. Note down these values:
   - Tenancy OCID
   - User OCID
   - Fingerprint
   - Region

### Step 2: Create terraform.tfvars

Navigate to the terraform directory:
```bash
cd /home/koljan3/TAK/TAK-server-setup/terraform
```

Create `terraform.tfvars` with your credentials:

```hcl
# OCI Authentication
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaa..."
user_ocid        = "ocid1.user.oc1..aaaaaaaa..."
fingerprint      = "aa:bb:cc:dd:ee:ff:..."
private_key_path = "/home/koljan3/.oci/oci_api_key.pem"
region           = "eu-frankfurt-1"

# Compartment (use root compartment OCID or create a new one)
compartment_ocid = "ocid1.compartment.oc1..aaaaaaaa..."

# SSH Access (paste your public key)
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC..."

# Instance Configuration
instance_name  = "opentakserver"
instance_shape = "VM.Standard.E2.1.Micro"  # Free tier
```

**Important**: Never commit `terraform.tfvars` to version control!

### Step 3: Initialize Terraform

```bash
terraform init
```

This downloads the necessary provider plugins.

### Step 4: Review the Deployment Plan

```bash
terraform plan
```

Review the resources that will be created:
- 1 VCN (Virtual Cloud Network)
- 1 Subnet
- 1 Internet Gateway
- 1 Route Table
- 2 Security Lists
- 1 Compute Instance

### Step 5: Deploy the Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to confirm.

**Deployment Time**: Approximately 15-20 minutes
- Infrastructure creation: 2-3 minutes
- Software installation: 12-17 minutes

### Step 6: Monitor the Installation

Get the public IP address:
```bash
terraform output instance_public_ip
```

SSH to the server to watch installation progress:
```bash
ssh -i ~/.ssh/your-private-key.pem ubuntu@<public-ip>
sudo tail -f /var/log/user-data.log
```

Installation is complete when you see:
```
OpenTAK Server installation completed!
Web Interface: http://<public-ip>/
```

### Step 7: Access the Web Interface

Open your browser and navigate to:
```
http://<public-ip>/
```

Login with the default credentials:
- **Username**: `admin`
- **Password**: `admin123`

**Important**: Change the admin password after first login!

## What Gets Installed

The Terraform deployment automatically installs and configures:

### System Components
- ✅ Ubuntu 24.04 LTS
- ✅ Python 3.12 with virtual environment
- ✅ Node.js 20.x
- ✅ Nginx web server
- ✅ RabbitMQ message broker
- ✅ 2GB swap space (for building on free tier)

### OpenTAK Server
- ✅ Backend server (Python/Flask with Socket.IO)
- ✅ Web UI (React/Vite)
- ✅ SQLite database
- ✅ Admin user created automatically
- ✅ Systemd service for automatic startup

### Network Configuration
- ✅ VCN with public subnet
- ✅ Internet gateway
- ✅ Security groups with all necessary ports
- ✅ UFW firewall configured
- ✅ Nginx reverse proxy with correct Socket.IO handling

### Configured Ports
| Port | Protocol | Purpose |
|------|----------|---------|
| 22 | TCP | SSH access |
| 80 | TCP | HTTP (Web UI) |
| 8080 | TCP | TAK API (direct backend) |
| 8089 | TCP | TAK TCP streaming |
| 8443 | TCP/SSL | TAK SSL streaming |
| 8446 | TCP/SSL | TAK SSL API |
| 8554 | TCP | Video streaming (RTSP) |
| 8000-8010 | UDP | Video streaming |

## Verification Checklist

After deployment, verify everything works:

- [ ] Web UI loads at `http://<public-ip>/`
- [ ] Login page displays correctly
- [ ] Can log in with admin/admin123
- [ ] Dashboard loads after login
- [ ] Backend service is running: `sudo systemctl status opentakserver`
- [ ] Nginx is running: `sudo systemctl status nginx`
- [ ] No errors in logs: `sudo journalctl -u opentakserver -n 50`

## Connecting ATAK Clients

To connect your ATAK Android devices:

1. Open ATAK app
2. Navigate to **Settings** → **Network Preferences** → **Network Connection Preferences**
3. Add new server connection:
   - **Address**: `<your-public-ip>`
   - **Port**: `8089` (TCP) or `8443` (SSL)
   - **Protocol**: TCP or SSL
4. Save and connect

## Troubleshooting

### Installation Fails

Check the installation log:
```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<public-ip>
sudo tail -100 /var/log/user-data.log
```

Common issues:
- **Out of memory during npm build**: The swap space should handle this, but check with `free -h`
- **Service won't start**: Check logs with `sudo journalctl -u opentakserver -n 100`
- **Port conflicts**: Verify no other services are using ports 8081, 8089, etc.

### Can't Access Web UI

1. **Check if server is accessible**:
   ```bash
   ping <public-ip>
   ```

2. **Verify Nginx is running**:
   ```bash
   ssh ubuntu@<public-ip> 'sudo systemctl status nginx'
   ```

3. **Check firewall rules**:
   ```bash
   ssh ubuntu@<public-ip> 'sudo ufw status'
   ```

4. **Test from server itself**:
   ```bash
   ssh ubuntu@<public-ip> 'curl -s http://localhost/ | head -20'
   ```

### Login Doesn't Work

1. **Verify admin user was created**:
   ```bash
   ssh ubuntu@<public-ip> 'cat /home/opentakserver/installation_status.txt'
   ```

2. **Check backend logs**:
   ```bash
   ssh ubuntu@<public-ip> 'sudo journalctl -u opentakserver -n 50'
   ```

3. **Test API directly**:
   ```bash
   curl -X POST http://<public-ip>/api/login \
     -H "Content-Type: application/json" \
     -d '{"username":"admin","password":"admin123"}'
   ```
   Should return JSON with code 200.

### Backend Service Won't Start

1. **Check service status**:
   ```bash
   sudo systemctl status opentakserver
   ```

2. **View detailed logs**:
   ```bash
   sudo journalctl -u opentakserver -xe
   ```

3. **Verify Python virtual environment**:
   ```bash
   sudo -u opentakserver bash -c "cd /home/opentakserver/OpenTAKServer && source opentakserver_venv/bin/activate && python --version"
   ```

4. **Restart service**:
   ```bash
   sudo systemctl restart opentakserver
   ```

## Redeployment

To completely redeploy the infrastructure:

```bash
cd /home/koljan3/TAK/TAK-server-setup/terraform

# Destroy everything
terraform destroy

# Deploy fresh
terraform apply
```

**Warning**: This will delete all data including users, configurations, and database!

## Updating the Server

To update the OpenTAK Server software without redeploying infrastructure:

```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<public-ip>

# Update backend
cd /home/opentakserver/OpenTAKServer
sudo systemctl stop opentakserver
sudo -u opentakserver git pull
sudo -u opentakserver bash -c "source opentakserver_venv/bin/activate && pip install -e ."
sudo systemctl start opentakserver

# Update Web UI
cd /home/opentakserver/OpenTAKServer-UI
sudo -u opentakserver git pull
sudo -u opentakserver bash -c "npm install --legacy-peer-deps && NODE_OPTIONS='--max-old-space-size=1536' npm run build"
sudo systemctl reload nginx
```

## Security Recommendations

### Immediate Actions
1. **Change default password**: Log into Web UI and change admin password
2. **Configure SSL**: Set up proper SSL certificates for production
3. **Restrict SSH**: Configure SSH to only accept key-based authentication
4. **Enable automatic updates**: Configure unattended-upgrades

### SSH Hardening
```bash
# Disable password authentication
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### Firewall Configuration
The UFW firewall is already configured, but you can restrict SSH access:
```bash
# Allow SSH only from your IP
sudo ufw delete allow ssh
sudo ufw allow from <your-ip> to any port 22
```

## Maintenance

### Regular Tasks

**Weekly**:
- Check logs for errors: `sudo journalctl -u opentakserver -n 100`
- Monitor disk space: `df -h`
- Review system logs: `sudo tail -100 /var/log/syslog`

**Monthly**:
- Update system packages: `sudo apt update && sudo apt upgrade`
- Backup database: `sudo cp /home/opentakserver/ots/data/*.db /backup/`
- Review user accounts

### Backup

Important files to backup:
```bash
# Database
/home/opentakserver/ots/data/

# Certificates
/home/opentakserver/ots/certs/

# Configuration (if customized)
/home/opentakserver/OpenTAKServer/config.py
```

Create a backup script:
```bash
#!/bin/bash
BACKUP_DIR="/backup/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"
sudo cp -r /home/opentakserver/ots/data "$BACKUP_DIR/"
sudo cp -r /home/opentakserver/ots/certs "$BACKUP_DIR/"
tar -czf "$BACKUP_DIR.tar.gz" "$BACKUP_DIR"
```

## Cost Optimization

### Free Tier Resources (Always Free)
- ✅ VM.Standard.E2.1.Micro (1 OCPU, 1GB RAM)
- ✅ 2 VMs (total) in always-free tier
- ✅ 100GB total storage
- ✅ 10TB outbound data transfer per month

### Staying Within Free Tier
Your deployment uses:
- 1 VM instance (free)
- 1 VCN (free, up to 2)
- ~50GB storage (free, under 100GB limit)

To avoid charges:
- Don't upgrade instance shape
- Don't create additional resources
- Don't exceed 10TB monthly bandwidth

## Advanced Configuration

### Custom Domain

To use your own domain:

1. Point your domain's A record to the server's public IP
2. Update Nginx configuration:
   ```bash
   sudo nano /etc/nginx/sites-available/opentakserver
   # Change: server_name _;
   # To: server_name yourdomain.com;
   ```
3. Install Let's Encrypt SSL:
   ```bash
   sudo apt install certbot python3-certbot-nginx
   sudo certbot --nginx -d yourdomain.com
   ```

### Environment Variables

To customize OpenTAK Server, edit `/home/opentakserver/OpenTAKServer/config.py`:
```python
# Example customizations
OTS_LISTENER_ADDRESS = "127.0.0.1"
OTS_LISTENER_PORT = 8081
DEBUG = False
SECRET_KEY = "your-custom-secret-key"
```

Then restart the service:
```bash
sudo systemctl restart opentakserver
```

## Getting Help

### Documentation
- **OpenTAK Server**: https://github.com/brian7704/OpenTAKServer
- **ATAK**: https://www.civtak.org/
- **Terraform OCI Provider**: https://registry.terraform.io/providers/oracle/oci/latest/docs

### Community Support
- **OpenTAK Issues**: https://github.com/brian7704/OpenTAKServer/issues
- **TAK Community**: https://tak.gov/

### Log Files
When asking for help, provide:
- Installation log: `/var/log/user-data.log`
- Backend logs: `sudo journalctl -u opentakserver -n 200`
- Nginx logs: `/var/log/nginx/error.log`
- System info: `uname -a`, `free -h`, `df -h`

## Summary

This deployment provides a complete, production-ready OpenTAK Server with:
- ✅ Fully automated installation
- ✅ Working Web UI with login
- ✅ Ready for ATAK client connections
- ✅ Running on free tier (no cost)
- ✅ Automatic service startup
- ✅ Proper reverse proxy configuration
- ✅ All necessary ports configured

**Total deployment time**: 15-20 minutes
**Monthly cost**: $0 (Free Tier)
**Maintenance**: Minimal

---

**Last Updated**: October 11, 2025
**Terraform Version**: 1.0+
**OCI Provider Version**: 5.0+
**OpenTAK Server**: Latest from GitHub
