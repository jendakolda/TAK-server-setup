# OpenTAK Server on Oracle Cloud Infrastructure (OCI)

This Terraform configuration deploys an OpenTAK server on Oracle Cloud Infrastructure using a VM.Standard.E2.1.Micro instance in the Frankfurt region.

## Prerequisites

1. **Oracle Cloud Infrastructure Account** with appropriate permissions
2. **OCI CLI configured** or API key setup
3. **Terraform installed** (version >= 1.0)

## Required OCI Information

You'll need the following OCI details:

- `tenancy_ocid` - Your OCI tenancy OCID
- `user_ocid` - Your OCI user OCID
- `fingerprint` - Your API key fingerprint
- `private_key_path` - Path to your OCI API private key file
- `compartment_ocid` - Target compartment OCID

## Quick Start

### 1. Clone and Navigate
```bash
cd terraform
```

### 2. Create terraform.tfvars
Create a `terraform.tfvars` file with your OCI credentials:

```hcl
tenancy_ocid     = "ocid1.tenancy.oc1..your_tenancy_ocid"
user_ocid        = "ocid1.user.oc1..your_user_ocid"
fingerprint      = "your_api_key_fingerprint"
private_key_path = "/path/to/your/oci_api_key.pem"
compartment_ocid = "ocid1.compartment.oc1..your_compartment_ocid"
```

### 3. Initialize and Deploy
```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

### 4. Access Your OpenTAK Server

After deployment, Terraform will output important information:

- **Web Interface**: `http://YOUR_PUBLIC_IP` or `https://YOUR_PUBLIC_IP`
- **SSH Access**: `ssh ubuntu@YOUR_PUBLIC_IP`
- **TAK Streaming**: `YOUR_PUBLIC_IP:8089` (TCP) or `YOUR_PUBLIC_IP:8443` (SSL)

## Connecting ATAK Client

1. **Get the server IP** from Terraform outputs
2. **Open ATAK app** on your Android device
3. **Go to Settings** → **Network Preferences** → **Manage Server Connections**
4. **Add new server**:
   - **Description**: Your server name
   - **Protocol**: TCP or SSL
   - **Address**: Your server's public IP
   - **Port**: 8089 (TCP) or 8443 (SSL)
5. **Connect** to your server

## Monitoring Installation

Check installation progress:
```bash
# Check if installation completed
ssh ubuntu@YOUR_PUBLIC_IP 'cat /home/opentakserver/installation_status.txt'

# Monitor installation logs
ssh ubuntu@YOUR_PUBLIC_IP 'tail -f /home/opentakserver/ots_ubuntu_installer.log'

# Check OpenTAK service status
ssh ubuntu@YOUR_PUBLIC_IP 'sudo systemctl status opentakserver'
```

## Port Configuration

The following ports are configured in the security list:

| Port | Protocol | Purpose |
|------|----------|---------|
| 22   | TCP      | SSH access |
| 80   | TCP      | HTTP web interface |
| 443  | TCP      | HTTPS web interface |
| 8080 | TCP      | Marti API |
| 8089 | TCP      | TAK streaming (TCP) |
| 8443 | TCP      | TAK streaming (SSL) |
| 8446 | TCP      | Certificate enrollment |
| 8554 | TCP      | MediaMTX RTSP |
| 8000-8010 | UDP | MediaMTX WebRTC |

## Security Features

- Non-root user (`opentakserver`) for running services
- UFW firewall configured with required ports only
- Reserved public IP for consistent access
- SSL/TLS certificate support (auto-generated)

## Troubleshooting

### Installation Issues
```bash
# Check user-data execution logs
ssh ubuntu@YOUR_PUBLIC_IP 'sudo tail -f /var/log/user-data.log'

# Restart OpenTAK service if needed
ssh ubuntu@YOUR_PUBLIC_IP 'sudo systemctl restart opentakserver'
```

### Connection Issues
1. Verify security group rules allow the required ports
2. Check if OpenTAK service is running
3. Ensure your client device can reach the server IP
4. Try both TCP (8089) and SSL (8443) ports

### Certificate Issues
- OpenTAK installer generates self-signed certificates automatically
- For production use, consider setting up proper SSL certificates

## Cleanup

To destroy the infrastructure:
```bash
terraform destroy
```

## Customization

### Change Instance Shape
Modify `instance_shape` in `variables.tf` or override in `terraform.tfvars`:
```hcl
instance_shape = "VM.Standard.E2.2.Micro"
```

### Modify Network Settings
Edit `variables.tf` to change VCN or subnet CIDR blocks.

### Additional Ports
Add new ingress rules in `security.tf` if you need additional ports.

## Support

- **OpenTAK Documentation**: https://docs.opentakserver.io
- **OpenTAK GitHub**: https://github.com/brian7704/OpenTAKServer
- **TAK Community**: https://civtak.org

## Cost Considerations

- VM.Standard.E2.1.Micro instances are part of Oracle's Always Free tier
- Reserved public IP may incur small charges
- Monitor your OCI billing dashboard for actual costs