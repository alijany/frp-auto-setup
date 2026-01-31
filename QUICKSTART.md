# Quick Start Guide

Get FRP up and running in 5 minutes!

## Prerequisites

- A VPS/Server with a public IP (for FRP server)
- A local machine/server you want to expose (for FRP client)
- Root access on both machines
- Domain name pointing to your VPS (optional but recommended)

## Step 1: Setup FRP Server (on your VPS)

```bash
# Download the script
wget https://raw.githubusercontent.com/YOUR_USERNAME/frp-auto-setup/main/frp-setup.sh
chmod +x frp-setup.sh

# Run the setup
sudo ./frp-setup.sh server -w YourSecurePassword123
```

**Important:** Note down the dashboard credentials shown after installation!

## Step 2: Configure DNS (Optional)

If you have a domain, create an A record:
```
Type: A
Name: @ (or subdomain)
Value: YOUR_VPS_IP
```

For wildcard subdomains:
```
Type: A
Name: *
Value: YOUR_VPS_IP
```

Wait for DNS propagation (can take a few minutes to hours).

## Step 3: Setup FRP Client (on your local machine)

```bash
# Download the script
wget https://raw.githubusercontent.com/YOUR_USERNAME/frp-auto-setup/main/frp-setup.sh
chmod +x frp-setup.sh

# Run the setup (replace with your actual values)
sudo ./frp-setup.sh client \
  -a YOUR_VPS_IP \
  -m yourdomain.com
```

## Step 4: Test Your Setup

```bash
# Check server status
ssh root@YOUR_VPS_IP
systemctl status frps

# Check client status (on local machine)
systemctl status frpc

# Visit your domain
http://yourdomain.com
```

## What Just Happened?

1. **FRP Server** is now running on your VPS, listening for connections
2. **FRP Client** connected to the server from your local machine
3. Traffic to your domain → VPS → Tunneled to your local machine → Your local web server

## Common Scenarios

### Scenario 1: Home Web Server
You have a web server at home and want it accessible via a domain:

**On VPS:**
```bash
sudo ./frp-setup.sh server -w MyPass123
```

**On Home Server:**
```bash
sudo ./frp-setup.sh client -a VPS_IP -m myhome.com
```

### Scenario 2: Development Preview
You're developing locally and want to show it to a client:

**On VPS (one-time setup):**
```bash
sudo ./frp-setup.sh server -w MyPass123
```

**On Dev Machine:**
```bash
# Your Next.js/React app runs on port 3000
sudo ./frp-setup.sh client -a VPS_IP -m preview.mysite.com -l 3000
```

### Scenario 3: Multiple Services
You have both HTTP and HTTPS services:

**On VPS:**
```bash
sudo ./frp-setup.sh server -w MyPass123 -h 80 -s 443
```

**On Local:**
```bash
sudo ./frp-setup.sh client -a VPS_IP -m myapp.com -l 8080 -L 8443
```

## Troubleshooting

### Client can't connect to server
```bash
# On server, check if service is running
systemctl status frps

# Check firewall
sudo ufw allow 7000/tcp
```

### Website not loading
```bash
# Check if local service is running
curl http://localhost:80

# Check FRP client logs
sudo journalctl -u frpc -f
```

### "Connection refused"
```bash
# Verify FRP server is accessible
telnet YOUR_VPS_IP 7000

# Check server logs
ssh root@YOUR_VPS_IP
journalctl -u frps -f
```

## Next Steps

- **Secure your setup**: Add authentication tokens
- **Monitor your services**: Check the dashboard at `http://VPS_IP:7500`
- **Add more tunnels**: Edit `/opt/frp/frpc.ini` for additional services
- **Set up HTTPS**: Use Let's Encrypt on your local machine

## Security Checklist

- [ ] Use a strong dashboard password
- [ ] Add authentication token for client-server communication
- [ ] Configure firewall to restrict dashboard access
- [ ] Use HTTPS for sensitive data
- [ ] Regularly update FRP to latest version
- [ ] Monitor logs for suspicious activity

## Quick Reference Commands

```bash
# Server Commands
systemctl status frps      # Check status
systemctl restart frps     # Restart
journalctl -u frps -f      # View logs
nano /opt/frp/frps.ini     # Edit config

# Client Commands
systemctl status frpc      # Check status
systemctl restart frpc     # Restart
journalctl -u frpc -f      # View logs
nano /opt/frp/frpc.ini     # Edit config
```

## Need Help?

- Check the [examples](examples/) directory for more configurations
- Read the full [README](README.md) for detailed documentation
- Visit [FRP's official documentation](https://github.com/fatedier/frp)
