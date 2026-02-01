#!/bin/bash

# Source required libraries
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="$(dirname "${_SCRIPT_DIR}")"
source "${_LIB_DIR}/output.sh"
source "${_LIB_DIR}/config.sh"
source "${_LIB_DIR}/install.sh"

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

# Connection pooling
pool_count = 10

# Protocol optimization
protocol = tcp
tls_enable = true

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
# Enable compression for better bandwidth usage
use_compression = true

# HTTPS proxy
[web_https]
type = https
local_ip = 127.0.0.1
local_port = ${local_https}
custom_domains = ${domain}
# Enable compression
use_compression = true
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

# Logging - output to both journal and log file
StandardOutput=journal
StandardError=journal

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
        echo ""
        print_header "Network Settings"
        print_info "TCP Mux Keepalive: 60s (optimized for high latency)"
        print_info "Heartbeat Interval: 10s"
        print_info "Heartbeat Timeout: 90s (optimized for high latency)"
        print_info "Dial Server Timeout: 30s"
        print_info "Connection Pool: 5"
        echo ""
        print_info "Log File: ${FRP_INSTALL_DIR}/frpc.log"
        print_info "Check status: systemctl status frpc"
        print_info "View logs: journalctl -u frpc -f"
    else
        print_error "FRP Client failed to start!"
        print_info "Check logs with: journalctl -u frpc -n 50"
        exit 1
    fi
}

setup_client_remote() {
    local remote_ip="$1"
    local server_addr="$2"
    local server_port="$3"
    local domain="$4"
    local local_http="$5"
    local local_https="$6"
    local auth_token="$7"
    local remote_user="${8:-root}"
    
    print_header "Setting up FRP Client on Remote Host: ${remote_user}@${remote_ip}"
    
    # Get the script's root directory
    local script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    # Copy entire script directory to remote server
    ssh "${remote_user}@${remote_ip}" "mkdir -p /tmp/frp-setup"
    scp -r "${script_root}/lib" "${remote_user}@${remote_ip}:/tmp/frp-setup/"
    scp "${script_root}/frp-setup.sh" "${remote_user}@${remote_ip}:/tmp/frp-setup/"
    
    # Build remote command with sudo and properly quoted arguments
    local remote_cmd="cd /tmp/frp-setup && sudo bash frp-setup.sh client -a '${server_addr}' -p '${server_port}' -m '${domain}' -l '${local_http}' -L '${local_https}'"
    if [ -n "$auth_token" ]; then
        remote_cmd="${remote_cmd} -t '${auth_token}'"
    fi
    
    # Execute on remote server
    ssh "${remote_user}@${remote_ip}" "$remote_cmd"
    
    # Cleanup
    ssh "${remote_user}@${remote_ip}" "rm -rf /tmp/frp-setup"
    
    print_success "Remote client setup complete!"
}

setup_update_client_local() {
    local server_addr="$1"
    local server_port="$2"
    local domain="$3"
    local local_http="$4"
    local local_https="$5"
    local auth_token="$6"
    
    if [ ! -f "${FRP_INSTALL_DIR}/frpc.ini" ]; then
        print_error "FRP Client configuration not found!"
        print_info "Please run 'Setup FRP Client' first"
        return 1
    fi
    
    print_header "Updating FRP Client Configuration"
    print_info "Current config: ${FRP_INSTALL_DIR}/frpc.ini"
    
    # Backup existing config
    cp "${FRP_INSTALL_DIR}/frpc.ini" "${FRP_INSTALL_DIR}/frpc.ini.backup.$(date +%s)"
    print_info "Backed up existing configuration"
    
    # Recreate configuration
    setup_client "$server_addr" "$server_port" "$domain" "$local_http" "$local_https" "$auth_token"
}

setup_update_client_remote() {
    local remote_ip="$1"
    local server_addr="$2"
    local server_port="$3"
    local domain="$4"
    local local_http="$5"
    local local_https="$6"
    local auth_token="$7"
    local remote_user="${8:-root}"
    
    print_header "Updating FRP Client on Remote Host: ${remote_user}@${remote_ip}"
    
    # Get the script's root directory
    local script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    # Copy entire script directory to remote server
    ssh "${remote_user}@${remote_ip}" "mkdir -p /tmp/frp-setup"
    scp -r "${script_root}/lib" "${remote_user}@${remote_ip}:/tmp/frp-setup/"
    scp "${script_root}/frp-setup.sh" "${remote_user}@${remote_ip}:/tmp/frp-setup/"
    
    # Build remote command with sudo and properly quoted arguments
    local remote_cmd="cd /tmp/frp-setup && sudo bash frp-setup.sh update-client -a '${server_addr}' -p '${server_port}' -m '${domain}' -l '${local_http}' -L '${local_https}'"
    if [ -n "$auth_token" ]; then
        remote_cmd="${remote_cmd} -t '${auth_token}'"
    fi
    
    # Execute on remote server
    ssh "${remote_user}@${remote_ip}" "$remote_cmd"
    
    # Cleanup
    ssh "${remote_user}@${remote_ip}" "rm -rf /tmp/frp-setup"
    
    print_success "Remote client update complete!"
}
