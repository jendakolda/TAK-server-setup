# OpenTAK Server - Quick Start Guide

## Deploy in 5 Steps

### 1. Create terraform.tfvars

```bash
cd /home/koljan3/TAK/TAK-server-setup/terraform

cat > terraform.tfvars << 'EOF'
tenancy_ocid     = "YOUR_TENANCY_OCID"
user_ocid        = "YOUR_USER_OCID"
fingerprint      = "YOUR_FINGERPRINT"
private_key_path = "~/.oci/oci_api_key.pem"
region           = "eu-frankfurt-1"
compartment_ocid = "YOUR_COMPARTMENT_OCID"
ssh_public_key   = "YOUR_SSH_PUBLIC_KEY"
instance_name    = "opentakserver"
instance_shape   = "VM.Standard.E2.1.Micro"
EOF
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Deploy

```bash
terraform apply
```

Type `yes` when prompted. Wait 15-20 minutes.

### 4. Get Your Server IP

```bash
terraform output instance_public_ip
```

### 5. Access Web UI

Open browser: `http://<your-ip>/`

Login:
- Username: `admin`
- Password: `admin123`

## That's It! 🎉

Your OpenTAK Server is ready!

## Connect ATAK Client

In ATAK app:
- Settings → Network → Add Server
- Address: `<your-ip>`
- Port: `8089` (TCP) or `8443` (SSL)

## Useful Commands

```bash
# SSH to server
ssh -i ~/.ssh/your-key.pem ubuntu@<your-ip>

# Check status
sudo systemctl status opentakserver nginx

# View logs
sudo journalctl -u opentakserver -f

# Restart services
sudo systemctl restart opentakserver
sudo systemctl reload nginx
```

## Files

- **Full Guide**: See `docs/` folder for detailed guides
- **Success Report**: `FINAL_SUCCESS.md`
- **Terraform Config**: `terraform/`

## Cost

**$0/month** (Oracle Cloud Free Tier)

---

**Need Help?** See troubleshooting sections in `docs/SSL_CONNECTION.md` or `docs/CUZK_TILE_SERVER.md`.
