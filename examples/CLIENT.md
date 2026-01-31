# Client Configuration Examples

This directory contains example configurations for various FRP client setups.

## Basic Client

Simple client setup connecting to FRP server:
```bash
sudo ./frp-setup.sh client \
  -a YOUR_SERVER_IP \
  -m yourdomain.com
```

## Client with Authentication Token

When your server requires token authentication:
```bash
sudo ./frp-setup.sh client \
  -a YOUR_SERVER_IP \
  -p 7000 \
  -m yourdomain.com \
  -t YourServerToken
```

## Custom Local Ports

When your local web server runs on non-standard ports:
```bash
sudo ./frp-setup.sh client \
  -a YOUR_SERVER_IP \
  -m yourdomain.com \
  -l 8080 \
  -L 8443
```

## Multiple Domains

For setting up multiple domains (requires manual configuration):

First, run the basic setup:
```bash
sudo ./frp-setup.sh client \
  -a YOUR_SERVER_IP \
  -m primarydomain.com
```

Then edit `/opt/frp/frpc.ini` and add more services:
```ini
[web_secondary]
type = http
local_ip = 127.0.0.1
local_port = 8080
custom_domains = secondary.com

[api_service]
type = http
local_ip = 127.0.0.1
local_port = 3000
custom_domains = api.primarydomain.com
```

Restart the client:
```bash
sudo systemctl restart frpc
```

## Docker Containers

Proxying to Docker containers:
```bash
# If your Docker container exposes port 80
sudo ./frp-setup.sh client \
  -a YOUR_SERVER_IP \
  -m yourdomain.com \
  -l 80

# If your Docker container uses a custom port
sudo ./frp-setup.sh client \
  -a YOUR_SERVER_IP \
  -m yourdomain.com \
  -l 3000
```

## SSH Tunneling

To tunnel SSH (requires manual configuration):

Run basic setup first:
```bash
sudo ./frp-setup.sh client \
  -a YOUR_SERVER_IP \
  -m yourdomain.com
```

Edit `/opt/frp/frpc.ini` and add:
```ini
[ssh]
type = tcp
local_ip = 127.0.0.1
local_port = 22
remote_port = 6000
```

Restart and connect:
```bash
sudo systemctl restart frpc
ssh -p 6000 user@YOUR_SERVER_IP
```

## Database Tunneling

To tunnel MySQL/PostgreSQL (requires manual configuration):

Edit `/opt/frp/frpc.ini` and add:
```ini
[mysql]
type = tcp
local_ip = 127.0.0.1
local_port = 3306
remote_port = 3306
use_encryption = true
use_compression = true
```

## Development Environment

For local development with hot reload:
```bash
# Example: Next.js running on port 3000
sudo ./frp-setup.sh client \
  -a YOUR_SERVER_IP \
  -m dev.yourdomain.com \
  -l 3000
```

## Custom Installation Directory

Install to a custom location:
```bash
FRP_INSTALL_DIR=/usr/local/frp sudo ./frp-setup.sh client \
  -a YOUR_SERVER_IP \
  -m yourdomain.com
```

## Advanced Configuration

After installation, you can manually edit `/opt/frp/frpc.ini` for advanced features:

### Enable Encryption
```ini
[common]
server_addr = YOUR_SERVER_IP
server_port = 7000
use_encryption = true
use_compression = true
```

### Health Check
```ini
[web_http]
type = http
local_ip = 127.0.0.1
local_port = 80
custom_domains = yourdomain.com
health_check_type = http
health_check_url = /health
health_check_interval_s = 10
```

### Load Balancer
```ini
[web_http_1]
type = http
local_ip = 127.0.0.1
local_port = 8080
custom_domains = yourdomain.com
group = web
group_key = your_group_key

[web_http_2]
type = http
local_ip = 127.0.0.1
local_port = 8081
custom_domains = yourdomain.com
group = web
group_key = your_group_key
```

## Post-Installation Steps

1. **Test Connection**
```bash
# Check if service is running
sudo systemctl status frpc

# View logs
sudo journalctl -u frpc -f
```

2. **Test Your Website**
```bash
# Using curl
curl -H "Host: yourdomain.com" http://YOUR_SERVER_IP

# Or visit in browser
http://yourdomain.com
```

3. **Monitor Service**
```bash
# Check status
sudo systemctl status frpc

# View live logs
sudo journalctl -u frpc -f

# View log file
sudo tail -f /opt/frp/frpc.log
```

4. **Troubleshooting**
```bash
# Restart service
sudo systemctl restart frpc

# Check configuration
cat /opt/frp/frpc.ini

# Test local service
curl http://localhost:80  # or your local port
```

## Common Use Cases

### Home Server with Dynamic IP
```bash
# Perfect for home servers with changing IPs
sudo ./frp-setup.sh client \
  -a YOUR_VPS_IP \
  -m homeserver.yourdomain.com \
  -l 80
```

### Raspberry Pi Web Server
```bash
sudo ./frp-setup.sh client \
  -a YOUR_SERVER_IP \
  -m raspberrypi.yourdomain.com \
  -l 80
```

### Preview Environments
```bash
# For showing work to clients
sudo ./frp-setup.sh client \
  -a YOUR_SERVER_IP \
  -m preview.yourdomain.com \
  -l 3000
```
