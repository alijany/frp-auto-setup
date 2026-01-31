# FRP Auto Setup Script

A simple, reusable bash script to automate the installation and configuration of [FRP (Fast Reverse Proxy)](https://github.com/fatedier/frp) on Linux systems.

## Features

✅ **Easy Installation** - One command to set up FRP server or client  
✅ **Configurable** - All parameters can be customized via command-line or environment variables  
✅ **Auto-detection** - Automatically detects system architecture  
✅ **Systemd Integration** - Automatic service creation and management  
✅ **Secure by Default** - Requires password for dashboard, supports authentication tokens  
✅ **Multiple Versions** - Install any FRP version via environment variable  

## Requirements

- Linux-based system (tested on Ubuntu, Debian, CentOS)
- Root access (sudo)
- `wget` and `tar` installed
- Systemd (for service management)

## Quick Start

### Server Setup

```bash
# Download the script
wget https://raw.githubusercontent.com/YOUR_USERNAME/frp-auto-setup/main/frp-setup.sh
chmod +x frp-setup.sh

# Setup FRP server with a secure password
sudo ./frp-setup.sh server -w YourSecurePassword123

# Or with custom configuration
sudo ./frp-setup.sh server \
  -p 7000 \
  -h 80 \
  -s 443 \
  -d 7500 \
  -u admin \
  -w YourSecurePassword123
```

### Client Setup

```bash
# Setup FRP client
sudo ./frp-setup.sh client \
  -a YOUR_SERVER_IP \
  -p 7000 \
  -m yourdomain.com

# With custom local ports
sudo ./frp-setup.sh client \
  -a YOUR_SERVER_IP \
  -m yourdomain.com \
  -l 8080 \
  -L 8443
```

## Usage

### Server Options

```bash
./frp-setup.sh server [OPTIONS]

Options:
  -p, --port PORT           Server bind port (default: 7000)
  -h, --http-port PORT      HTTP vhost port (default: 80)
  -s, --https-port PORT     HTTPS vhost port (default: 443)
  -d, --dashboard PORT      Dashboard port (default: 7500)
  -u, --user USERNAME       Dashboard username (default: admin)
  -w, --password PASSWORD   Dashboard password (REQUIRED)
  -t, --token TOKEN         Authentication token (optional)
```

### Client Options

```bash
./frp-setup.sh client [OPTIONS]

Options:
  -a, --server-addr IP      FRP server address (REQUIRED)
  -p, --port PORT           FRP server port (default: 7000)
  -m, --domain DOMAIN       Custom domain (REQUIRED)
  -l, --local-http PORT     Local HTTP port (default: 80)
  -L, --local-https PORT    Local HTTPS port (default: 443)
  -t, --token TOKEN         Authentication token (optional)
```

## Environment Variables

Customize installation via environment variables:

```bash
# Install specific FRP version
FRP_VERSION=0.52.0 ./frp-setup.sh server -w mypass

# Custom installation directory
FRP_INSTALL_DIR=/usr/local/frp ./frp-setup.sh server -w mypass

# Specify architecture (auto-detected by default)
FRP_ARCH=linux_arm64 ./frp-setup.sh server -w mypass
```

Available environment variables:
- `FRP_VERSION` - FRP version to install (default: 0.51.3)
- `FRP_ARCH` - Architecture (default: auto-detected)
- `FRP_INSTALL_DIR` - Installation directory (default: /opt/frp)

## Architecture Support

The script automatically detects your system architecture. Supported architectures:
- `linux_amd64` (x86_64)
- `linux_arm64` (aarch64)
- `linux_arm` (armv7l)

## Managing Services

```bash
# Check service status
systemctl status frps  # for server
systemctl status frpc  # for client

# View logs
journalctl -u frps -f  # for server
journalctl -u frpc -f  # for client

# Restart service
systemctl restart frps  # for server
systemctl restart frpc  # for client

# Stop service
systemctl stop frps    # for server
systemctl stop frpc    # for client
```

## Configuration Files

After installation, configuration files are located at:
- Server: `/opt/frp/frps.ini`
- Client: `/opt/frp/frpc.ini`

You can manually edit these files and restart the service:
```bash
systemctl restart frps  # or frpc
```

## Examples

### Basic Server Setup
```bash
sudo ./frp-setup.sh server -w MyStrongPassword123
```

### Server with Custom Ports
```bash
sudo ./frp-setup.sh server \
  -p 7000 \
  -h 8080 \
  -s 8443 \
  -d 7500 \
  -w MyStrongPassword123
```

### Server with Authentication Token
```bash
sudo ./frp-setup.sh server \
  -w MyStrongPassword123 \
  -t MySecretToken456
```

### Basic Client Setup
```bash
sudo ./frp-setup.sh client \
  -a 123.45.67.89 \
  -m mywebsite.com
```

### Client with Token Authentication
```bash
sudo ./frp-setup.sh client \
  -a 123.45.67.89 \
  -m mywebsite.com \
  -t MySecretToken456
```

### Install Specific Version
```bash
FRP_VERSION=0.52.1 sudo ./frp-setup.sh server -w mypass
```

## Security Considerations

1. **Always use strong passwords** for the dashboard
2. **Use authentication tokens** for production deployments
3. **Configure firewall** to restrict access to FRP ports
4. **Use HTTPS** for sensitive data
5. **Regularly update** FRP to the latest version
6. **Monitor logs** for suspicious activity

### Recommended Firewall Rules

```bash
# Allow FRP server port
ufw allow 7000/tcp

# Allow HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Allow dashboard (restrict to specific IPs in production)
ufw allow from YOUR_IP to any port 7500
```

## Troubleshooting

### Service fails to start

Check logs:
```bash
journalctl -u frps -n 50  # or frpc
```

### Connection refused

1. Check if service is running: `systemctl status frps`
2. Verify firewall rules: `ufw status`
3. Check server logs: `cat /opt/frp/frps.log`

### Architecture detection issues

Manually specify architecture:
```bash
FRP_ARCH=linux_amd64 ./frp-setup.sh server -w mypass
```

## Uninstallation

```bash
# Stop and disable service
sudo systemctl stop frps frpc
sudo systemctl disable frps frpc

# Remove service files
sudo rm /etc/systemd/system/frps.service
sudo rm /etc/systemd/system/frpc.service

# Remove installation
sudo rm -rf /opt/frp

# Reload systemd
sudo systemctl daemon-reload
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details

## Credits

This script automates the installation of [FRP](https://github.com/fatedier/frp) by fatedier.

## Support

For issues related to:
- **This script**: Open an issue in this repository
- **FRP itself**: Visit the [official FRP repository](https://github.com/fatedier/frp)
