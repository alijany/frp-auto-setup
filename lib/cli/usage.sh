#!/bin/bash

# Source required libraries
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="$(dirname "${_SCRIPT_DIR}")"
source "${_LIB_DIR}/output.sh"

show_usage() {
    cat << EOF
${BLUE}FRP Auto Setup Script${NC}
Setup FRP Server or Client with ease

${YELLOW}USAGE:${NC}
  $0 [server|client] [OPTIONS]

${YELLOW}COMMANDS:${NC}
  server           Setup FRP server (frps)
  client           Setup FRP client (frpc)
  update-server    Update existing FRP server configuration
  update-client    Update existing FRP client configuration
  stop-server      Stop FRP server service
  stop-client      Stop FRP client service
  restart-server   Restart FRP server service
  restart-client   Restart FRP client service
  show-config      Show FRP configuration (server or client)
  auto-setup       Automatically setup both server and client with random secure values
  remove-server    Remove FRP server completely
  remove-client    Remove FRP client completely

${YELLOW}SERVER OPTIONS:${NC}
  -i, --server-ip IP        Remote server IP (for SSH setup, optional)
  -p, --port PORT           Server bind port (default: 7000)
  -h, --http-port PORT      HTTP vhost port (default: 80)
  -s, --https-port PORT     HTTPS vhost port (default: 443)
  -d, --dashboard PORT      Dashboard port (default: 7500)
  -u, --user USERNAME       Dashboard username (default: admin)
  -w, --password PASSWORD   Dashboard password (required, no default)
  -t, --token TOKEN         Authentication token (optional)

${YELLOW}CLIENT OPTIONS:${NC}
  -a, --server-addr IP      FRP server address (required)
  -p, --port PORT           FRP server port (default: 7000)
  -m, --domain DOMAIN       Custom domain (required)
  -l, --local-http PORT     Local HTTP port (default: 80)
  -L, --local-https PORT    Local HTTPS port (default: 443)
  -t, --token TOKEN         Authentication token (optional, must match server)

${YELLOW}ENVIRONMENT VARIABLES:${NC}
  FRP_VERSION               FRP version to install (default: 0.51.3)
  FRP_ARCH                  Architecture (default: auto-detect or linux_amd64)
  FRP_INSTALL_DIR           Installation directory (default: /opt/frp)

${YELLOW}EXAMPLES:${NC}
  # Setup server locally with custom password
  $0 server -w mySecurePassword123

  # Setup remote server via SSH
  $0 server -i 192.168.1.100 -w mySecurePassword123

  # Setup server with all custom ports
  $0 server -p 7000 -h 8080 -s 8443 -d 7500 -u admin -w strongpass

  # Setup client
  $0 client -a SERVER_IP -p 7000 -m yourdomain.com

  # Setup client with custom local ports
  $0 client -a SERVER_IP -m yourdomain.com -l 8080 -L 8443

  # Stop/Remove services
  $0 stop-server
  $0 remove-client

  # Use specific FRP version
  FRP_VERSION=0.52.0 $0 server -w mypass

  # Install to custom directory
  FRP_INSTALL_DIR=/usr/local/frp $0 server -w mypass

EOF
    exit 1
}
