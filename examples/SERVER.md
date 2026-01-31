# Server Configuration Examples

This directory contains example configurations for various FRP server setups.

## Basic Server

Minimal setup with default ports:
```bash
sudo ./frp-setup.sh server -w MySecurePassword123
```

## Production Server

Recommended production setup with custom ports and authentication:
```bash
sudo ./frp-setup.sh server \
  -p 7000 \
  -h 80 \
  -s 443 \
  -d 7500 \
  -u admin \
  -w "$(openssl rand -base64 32)" \
  -t "$(openssl rand -base64 32)"
```

## Multiple HTTP Ports

If you need to run web services on non-standard ports:
```bash
sudo ./frp-setup.sh server \
  -p 7000 \
  -h 8080 \
  -s 8443 \
  -d 7500 \
  -w MySecurePassword123
```

## Behind NAT/Firewall

When your server is behind NAT or firewall:
```bash
# Make sure these ports are forwarded:
# - 7000 (FRP control)
# - 80 (HTTP)
# - 443 (HTTPS)
# - 7500 (Dashboard - optional, restrict access)

sudo ./frp-setup.sh server \
  -p 7000 \
  -h 80 \
  -s 443 \
  -d 7500 \
  -w MySecurePassword123
```

## Custom Installation Directory

Install to a custom location:
```bash
FRP_INSTALL_DIR=/usr/local/frp sudo ./frp-setup.sh server \
  -w MySecurePassword123
```

## Specific FRP Version

Install a specific version of FRP:
```bash
FRP_VERSION=0.52.1 sudo ./frp-setup.sh server \
  -w MySecurePassword123
```

## Advanced Configuration

After installation, you can manually edit `/opt/frp/frps.ini` for advanced features:

### Enable Subdomain Support
```ini
subdomain_host = yourdomain.com
```

### Custom Max Pool Count
```ini
max_pool_count = 50
```

### Enable TLS
```ini
tls_enable = true
```

### Port Range
```ini
allow_ports = 1000-65535
```

Then restart the service:
```bash
sudo systemctl restart frps
```

## Post-Installation Steps

1. **Configure Firewall**
```bash
sudo ufw allow 7000/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
# Only allow dashboard from specific IP
sudo ufw allow from YOUR_IP to any port 7500
```

2. **Access Dashboard**
- URL: `http://YOUR_SERVER_IP:7500`
- Username: `admin` (or your custom username)
- Password: (the one you set)

3. **Monitor Service**
```bash
# Check status
sudo systemctl status frps

# View live logs
sudo journalctl -u frps -f

# View log file
sudo tail -f /opt/frp/frps.log
```

4. **Set Up DNS** (if using custom domains)
- Create A record pointing to your server IP
- If using subdomains, create wildcard A record: `*.yourdomain.com`
