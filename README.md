# FRP Auto Setup

Automated installation and configuration script for [FRP (Fast Reverse Proxy)](https://github.com/fatedier/frp) with interactive menu and remote SSH management.

> **🎉 Refactored**: This project has been refactored into a modular structure! See [REFACTORING.md](REFACTORING.md) for details.
> - **New**: Use `./frp-setup-new.sh` for the modular version
> - **Legacy**: `./frp-setup.sh` is the original script (still functional)

## Features

- **Interactive Menu** - Easy-to-use interface for all operations
- **Remote SSH Setup** - Configure servers and clients via SSH
- **Network Optimization** - Built-in settings for unstable connections
- **Configuration Management** - Save/load connection settings
- **Log Viewing & Testing** - Monitor and test FRP services
- **Auto-detection** - Automatically detects system architecture
- **Modular Architecture** - Clean, maintainable code structure (new version)

## Quick Start

```bash
# Run interactive mode (new modular version)
sudo ./frp-setup-new.sh

# Or use command-line mode
sudo ./frp-setup-new.sh server -w YourPassword123
sudo ./frp-setup-new.sh client -a SERVER_IP -m yourdomain.com

# Legacy script still works
sudo ./frp-setup.sh server -w YourPassword123
```

## Interactive Menu

The script provides an interactive menu with:
1. Setup/Update Server & Client
2. Stop/Remove Services
3. View Logs & Test Connections
4. Save/Load Configuration

## Command-Line Usage

**Server:**
```bash
./frp-setup.sh server -w PASSWORD [-p 7000] [-h 80] [-s 443] [-d 7500]
```

**Client:**
```bash
./frp-setup.sh client -a SERVER_IP -m DOMAIN [-p 7000] [-l 80] [-L 443]
```

**Update:**
```bash
./frp-setup.sh update-server -w PASSWORD
./frp-setup.sh update-client -a SERVER_IP -m DOMAIN
```

**Manage:**
```bash
./frp-setup.sh stop-server|stop-client
./frp-setup.sh remove-server|remove-client
```

## Remote Setup

Configure remote servers via SSH:
```bash
# Interactive mode will prompt for SSH details
sudo ./frp-setup.sh

# Or use command-line with -i flag
./frp-setup.sh server -i REMOTE_IP -w PASSWORD
```

## Environment Variables

- `FRP_VERSION` - Version to install (default: 0.51.3)
- `FRP_INSTALL_DIR` - Installation directory (default: /opt/frp)
- `FRP_ARCH` - Architecture (auto-detected)

## Network Optimization

The script includes optimizations for unstable networks:
- TCP multiplexing and keep-alive
- Connection pooling
- Compression enabled
- Auto-reconnection settings

## WSL Support

For Windows users with WSL2:
```bash
# Copy SSH keys from Windows to WSL
cp /mnt/c/Users/YOUR_USER/.ssh/id_rsa ~/.ssh/
chmod 600 ~/.ssh/id_rsa
```

## License

MIT License
