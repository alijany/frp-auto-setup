#!/bin/bash

#################################################
# FRP Auto Setup Script
# Supports both Server (frps) and Client (frpc)
# Configurable and reusable for any deployment
#################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default Configuration (can be overridden via environment variables or arguments)
FRP_VERSION="${FRP_VERSION:-0.51.3}"
FRP_ARCH="${FRP_ARCH:-linux_amd64}"
FRP_INSTALL_DIR="${FRP_INSTALL_DIR:-/opt/frp}"
DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_${FRP_ARCH}.tar.gz"

# Functions
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_header() {
    echo -e "${BLUE}===================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}===================================${NC}"
}

detect_architecture() {
    local arch=$(uname -m)
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    case "$arch" in
        x86_64|amd64)
            arch="amd64"
            ;;
        aarch64|arm64)
            arch="arm64"
            ;;
        armv7l)
            arch="arm"
            ;;
        *)
            print_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
    
    echo "${os}_${arch}"
}

show_usage() {
    cat << EOF
${BLUE}FRP Auto Setup Script${NC}
Setup FRP Server or Client with ease

${YELLOW}USAGE:${NC}
  $0 [server|client] [OPTIONS]

${YELLOW}COMMANDS:${NC}
  server    Setup FRP server (frps)
  client    Setup FRP client (frpc)

${YELLOW}SERVER OPTIONS:${NC}
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
  # Setup server with custom password
  $0 server -w mySecurePassword123

  # Setup server with all custom ports
  $0 server -p 7000 -h 8080 -s 8443 -d 7500 -u admin -w strongpass

  # Setup client
  $0 client -a SERVER_IP -p 7000 -m yourdomain.com

  # Setup client with custom local ports
  $0 client -a SERVER_IP -m yourdomain.com -l 8080 -L 8443

  # Use specific FRP version
  FRP_VERSION=0.52.0 $0 server -w mypass

  # Install to custom directory
  FRP_INSTALL_DIR=/usr/local/frp $0 server -w mypass

EOF
    exit 1
}

install_frp() {
    print_header "Installing FRP ${FRP_VERSION}"
    
    # Auto-detect architecture if not explicitly set
    if [ "$FRP_ARCH" = "linux_amd64" ] && [ -z "${FRP_ARCH_SET}" ]; then
        local detected_arch=$(detect_architecture)
        print_info "Auto-detected architecture: ${detected_arch}"
        FRP_ARCH="$detected_arch"
        DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_${FRP_ARCH}.tar.gz"
    fi
    
    # Create installation directory
    mkdir -p "$FRP_INSTALL_DIR"
    cd "$(dirname "$FRP_INSTALL_DIR")"
    
    local extract_dir="frp_${FRP_VERSION}_${FRP_ARCH}"
    
    if [ -d "$extract_dir" ]; then
        print_info "FRP already downloaded, skipping download..."
    else
        print_info "Downloading FRP from GitHub..."
        if ! wget -q --show-progress "$DOWNLOAD_URL" -O "frp_${FRP_VERSION}_${FRP_ARCH}.tar.gz"; then
            print_error "Failed to download FRP. Please check version and architecture."
            print_info "URL: $DOWNLOAD_URL"
            exit 1
        fi
        tar -xzf "frp_${FRP_VERSION}_${FRP_ARCH}.tar.gz"
        rm "frp_${FRP_VERSION}_${FRP_ARCH}.tar.gz"
    fi
    
    # Link or copy to installation directory
    if [ "$FRP_INSTALL_DIR" != "/opt/frp" ] || [ ! -L "$FRP_INSTALL_DIR" ]; then
        rm -rf "$FRP_INSTALL_DIR"
        ln -sf "$(pwd)/$extract_dir" "$FRP_INSTALL_DIR"
    fi
    
    print_success "FRP installed to $FRP_INSTALL_DIR"
}

setup_server() {
    local bind_port="${1:-7000}"
    local http_port="${2:-80}"
    local https_port="${3:-443}"
    local dashboard_port="${4:-7500}"
    local dashboard_user="${5:-admin}"
    local dashboard_pwd="$6"
    local auth_token="$7"
    
    # Validate required parameters
    if [ -z "$dashboard_pwd" ]; then
        print_error "Dashboard password is required for security!"
        print_info "Use -w or --password to set a password"
        exit 1
    fi
    
    print_header "Setting up FRP Server"
    
    install_frp
    
    # Create frps.ini
    cat > "${FRP_INSTALL_DIR}/frps.ini" << EOF
[common]
bind_port = ${bind_port}
# Allow a wide range of ports for various services
allow_ports = 80,443,2000-3000,3001,3003,4000-50000

# Dashboard settings
dashboard_port = ${dashboard_port}
dashboard_user = ${dashboard_user}
dashboard_pwd = ${dashboard_pwd}

# Virtual host settings
vhost_http_port = ${http_port}
vhost_https_port = ${https_port}

# Logging
log_file = ${FRP_INSTALL_DIR}/frps.log
log_level = info
log_max_days = 3
EOF

    # Add authentication token if provided
    if [ -n "$auth_token" ]; then
        echo "authentication_method = token" >> "${FRP_INSTALL_DIR}/frps.ini"
        echo "token = ${auth_token}" >> "${FRP_INSTALL_DIR}/frps.ini"
    fi
    
    print_success "Configuration file created: ${FRP_INSTALL_DIR}/frps.ini"
    
    # Create systemd service
    cat > /etc/systemd/system/frps.service << EOF
[Unit]
Description=FRP Server Service
After=network.target syslog.target
Wants=network.target

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
ExecStart=${FRP_INSTALL_DIR}/frps -c ${FRP_INSTALL_DIR}/frps.ini
ExecReload=/bin/kill -HUP \$MAINPID
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable frps
    systemctl restart frps
    
    sleep 2
    
    if systemctl is-active --quiet frps; then
        print_success "FRP Server is running!"
        echo ""
        print_header "Server Information"
        print_info "Server Port: ${bind_port}"
        print_info "HTTP Port: ${http_port}"
        print_info "HTTPS Port: ${https_port}"
        print_info "Dashboard: http://YOUR_SERVER_IP:${dashboard_port}"
        print_info "Dashboard User: ${dashboard_user}"
        print_info "Dashboard Password: ${dashboard_pwd}"
        [ -n "$auth_token" ] && print_info "Auth Token: ${auth_token}"
        print_info "Log File: ${FRP_INSTALL_DIR}/frps.log"
        echo ""
        print_info "Check status: systemctl status frps"
        print_info "View logs: journalctl -u frps -f"
    else
        print_error "FRP Server failed to start!"
        print_info "Check logs with: journalctl -u frps -n 50"
        exit 1
    fi
}

setup_client() {
    local server_addr="$1"
    local server_port="${2:-7000}"
    local domain="$3"
    local local_http="${4:-80}"
    local local_https="${5:-443}"
    local auth_token="$6"
    
    # Validate required parameters
    if [ -z "$server_addr" ]; then
        print_error "Server address is required for client setup"
        print_info "Use -a or --server-addr to specify the FRP server address"
        exit 1
    fi
    
    if [ -z "$domain" ]; then
        print_error "Domain is required for client setup"
        print_info "Use -m or --domain to specify your custom domain"
        exit 1
    fi
    
    print_header "Setting up FRP Client"
    
    install_frp
    
    # Create frpc.ini
    cat > "${FRP_INSTALL_DIR}/frpc.ini" << EOF
[common]
server_addr = ${server_addr}
server_port = ${server_port}
EOF

    # Add authentication token if provided
    if [ -n "$auth_token" ]; then
        echo "authentication_method = token" >> "${FRP_INSTALL_DIR}/frpc.ini"
        echo "token = ${auth_token}" >> "${FRP_INSTALL_DIR}/frpc.ini"
    fi

    cat >> "${FRP_INSTALL_DIR}/frpc.ini" << EOF

# Logging
log_file = ${FRP_INSTALL_DIR}/frpc.log
log_level = info
log_max_days = 3

# HTTP proxy
[web_http]
type = http
local_ip = 127.0.0.1
local_port = ${local_http}
custom_domains = ${domain}

# HTTPS proxy
[web_https]
type = https
local_ip = 127.0.0.1
local_port = ${local_https}
custom_domains = ${domain}
EOF
    
    print_success "Configuration file created: ${FRP_INSTALL_DIR}/frpc.ini"
    
    # Create systemd service
    cat > /etc/systemd/system/frpc.service << EOF
[Unit]
Description=FRP Client Service
After=network.target syslog.target
Wants=network.target

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
ExecStart=${FRP_INSTALL_DIR}/frpc -c ${FRP_INSTALL_DIR}/frpc.ini
ExecReload=/bin/kill -HUP \$MAINPID
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable frpc
    systemctl restart frpc
    
    sleep 2
    
    if systemctl is-active --quiet frpc; then
        print_success "FRP Client is running!"
        echo ""
        print_header "Client Information"
        print_info "Server: ${server_addr}:${server_port}"
        print_info "Domain: ${domain}"
        print_info "Local HTTP: ${local_http}"
        print_info "Local HTTPS: ${local_https}"
        [ -n "$auth_token" ] && print_info "Auth Token: Configured"
        print_info "Log File: ${FRP_INSTALL_DIR}/frpc.log"
        echo ""
        print_info "Check status: systemctl status frpc"
        print_info "View logs: journalctl -u frpc -f"
    else
        print_error "FRP Client failed to start!"
        print_info "Check logs with: journalctl -u frpc -n 50"
        exit 1
    fi
}

# Main script
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root"
    print_info "Use: sudo $0 ..."
    exit 1
fi

MODE="$1"
shift || show_usage

case "$MODE" in
    server)
        # Default values
        BIND_PORT=7000
        HTTP_PORT=80
        HTTPS_PORT=443
        DASHBOARD_PORT=7500
        DASHBOARD_USER="admin"
        DASHBOARD_PWD=""
        AUTH_TOKEN=""
        
        # Parse arguments
        while [[ $# -gt 0 ]]; do
            case $1 in
                -p|--port)
                    BIND_PORT="$2"
                    shift 2
                    ;;
                -h|--http-port)
                    HTTP_PORT="$2"
                    shift 2
                    ;;
                -s|--https-port)
                    HTTPS_PORT="$2"
                    shift 2
                    ;;
                -d|--dashboard)
                    DASHBOARD_PORT="$2"
                    shift 2
                    ;;
                -u|--user)
                    DASHBOARD_USER="$2"
                    shift 2
                    ;;
                -w|--password)
                    DASHBOARD_PWD="$2"
                    shift 2
                    ;;
                -t|--token)
                    AUTH_TOKEN="$2"
                    shift 2
                    ;;
                *)
                    print_error "Unknown option: $1"
                    show_usage
                    ;;
            esac
        done
        
        setup_server "$BIND_PORT" "$HTTP_PORT" "$HTTPS_PORT" "$DASHBOARD_PORT" "$DASHBOARD_USER" "$DASHBOARD_PWD" "$AUTH_TOKEN"
        ;;
        
    client)
        # Default values
        SERVER_ADDR=""
        SERVER_PORT=7000
        DOMAIN=""
        LOCAL_HTTP=80
        LOCAL_HTTPS=443
        AUTH_TOKEN=""
        
        # Parse arguments
        while [[ $# -gt 0 ]]; do
            case $1 in
                -a|--server-addr)
                    SERVER_ADDR="$2"
                    shift 2
                    ;;
                -p|--port)
                    SERVER_PORT="$2"
                    shift 2
                    ;;
                -m|--domain)
                    DOMAIN="$2"
                    shift 2
                    ;;
                -l|--local-http)
                    LOCAL_HTTP="$2"
                    shift 2
                    ;;
                -L|--local-https)
                    LOCAL_HTTPS="$2"
                    shift 2
                    ;;
                -t|--token)
                    AUTH_TOKEN="$2"
                    shift 2
                    ;;
                *)
                    print_error "Unknown option: $1"
                    show_usage
                    ;;
            esac
        done
        
        setup_client "$SERVER_ADDR" "$SERVER_PORT" "$DOMAIN" "$LOCAL_HTTP" "$LOCAL_HTTPS" "$AUTH_TOKEN"
        ;;
        
    *)
        print_error "Invalid mode: $MODE"
        show_usage
        ;;
esac

print_success "Setup complete!"
