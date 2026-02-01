#!/bin/bash

# Source required libraries
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="$(dirname "${_SCRIPT_DIR}")"
source "${_LIB_DIR}/output.sh"
source "${_LIB_DIR}/config.sh"
source "${_LIB_DIR}/install.sh"

setup_server() {
    local bind_port="${1:-7000}"
    local http_port="${2:-80}"
    local https_port="${3:-443}"
    local dashboard_port="${4:-7500}"
    local dashboard_user="${5:-admin}"
    local dashboard_pwd="$6"
    local auth_token="$7"
    local remote_ip="$8"
    
    # Validate required parameters
    if [ -z "$dashboard_pwd" ]; then
        print_error "Dashboard password is required for security!"
        print_info "Use -w or --password to set a password"
        exit 1
    fi
    
    # If remote IP is provided, use SSH to setup
    if [ -n "$remote_ip" ]; then
        local remote_user="${9:-root}"
        print_header "Setting up FRP Server on Remote Host: ${remote_user}@${remote_ip}"
        print_info "This will execute the setup script on the remote server via SSH"
        
        # Get the script's root directory
        local script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
        
        # Copy entire script directory to remote server
        ssh "${remote_user}@${remote_ip}" "mkdir -p /tmp/frp-setup"
        scp -r "${script_root}/lib" "${remote_user}@${remote_ip}:/tmp/frp-setup/"
        scp "${script_root}/frp-setup.sh" "${remote_user}@${remote_ip}:/tmp/frp-setup/"
        
        # Build remote command with sudo and properly quoted arguments
        local remote_cmd="cd /tmp/frp-setup && sudo bash frp-setup.sh server -p '${bind_port}' -h '${http_port}' -s '${https_port}' -d '${dashboard_port}' -u '${dashboard_user}' -w '${dashboard_pwd}'"
        if [ -n "$auth_token" ]; then
            remote_cmd="${remote_cmd} -t '${auth_token}'"
        fi
        
        # Execute on remote server
        ssh "${remote_user}@${remote_ip}" "$remote_cmd"
        
        # Cleanup
        ssh "${remote_user}@${remote_ip}" "rm -rf /tmp/frp-setup"
        
        print_success "Remote server setup complete!"
        print_info "Server dashboard: http://${remote_ip}:${dashboard_port}"
        return 0
    fi
    
    print_header "Setting up FRP Server"
    
    install_frp
    
    # Strip any trailing newlines from password
    dashboard_pwd=$(echo -n "$dashboard_pwd" | tr -d '\n\r')
    
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

# Network optimization for unstable connections and high latency
# tcp_mux = true
# tcp_mux_keepalive_interval = 60
# heartbeat_interval = 10
# heartbeat_timeout = 90

# Connection pooling for better performance
# max_pool_count = 10

# Logging
log_file = ${FRP_INSTALL_DIR}/frps.log
log_level = error
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

# Logging - output to both journal and log file
StandardOutput=journal
StandardError=journal

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
        echo ""
        print_header "Network Settings"
        print_info "TCP Mux Keepalive: 60s (optimized for high latency)"
        print_info "Heartbeat Interval: 10s"
        print_info "Heartbeat Timeout: 90s (optimized for high latency)"
        echo ""
        print_info "Log File: ${FRP_INSTALL_DIR}/frps.log"
        print_info "Check status: systemctl status frps"
        print_info "View logs: journalctl -u frps -f"
    else
        print_error "FRP Server failed to start!"
        print_info "Check logs with: journalctl -u frps -n 50"
        exit 1
    fi
}

setup_update_server_local() {
    local bind_port="$1"
    local http_port="$2"
    local https_port="$3"
    local dashboard_port="$4"
    local dashboard_user="$5"
    local dashboard_pwd="$6"
    local auth_token="$7"
    
    if [ ! -f "${FRP_INSTALL_DIR}/frps.ini" ]; then
        print_error "FRP Server configuration not found!"
        print_info "Please run 'Setup FRP Server' first"
        return 1
    fi
    
    print_header "Updating FRP Server Configuration"
    print_info "Current config: ${FRP_INSTALL_DIR}/frps.ini"
    
    # Backup existing config
    cp "${FRP_INSTALL_DIR}/frps.ini" "${FRP_INSTALL_DIR}/frps.ini.backup.$(date +%s)"
    print_info "Backed up existing configuration"
    
    # Recreate configuration
    setup_server "$bind_port" "$http_port" "$https_port" "$dashboard_port" "$dashboard_user" "$dashboard_pwd" "$auth_token" ""
}

setup_update_server_remote() {
    local remote_ip="$1"
    local bind_port="$2"
    local http_port="$3"
    local https_port="$4"
    local dashboard_port="$5"
    local dashboard_user="$6"
    local dashboard_pwd="$7"
    local auth_token="$8"
    local remote_user="${9:-root}"
    
    print_header "Updating FRP Server on Remote Host: ${remote_user}@${remote_ip}"
    
    # Get the script's root directory
    local script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    # Copy entire script directory to remote server
    ssh "${remote_user}@${remote_ip}" "mkdir -p /tmp/frp-setup"
    scp -r "${script_root}/lib" "${remote_user}@${remote_ip}:/tmp/frp-setup/"
    scp "${script_root}/frp-setup.sh" "${remote_user}@${remote_ip}:/tmp/frp-setup/"
    
    # Build remote command with sudo and properly quoted arguments
    local remote_cmd="cd /tmp/frp-setup && sudo bash frp-setup.sh update-server -p '${bind_port}' -h '${http_port}' -s '${https_port}' -d '${dashboard_port}' -u '${dashboard_user}' -w '${dashboard_pwd}'"
    if [ -n "$auth_token" ]; then
        remote_cmd="${remote_cmd} -t '${auth_token}'"
    fi
    
    # Execute on remote server
    ssh "${remote_user}@${remote_ip}" "$remote_cmd"
    
    # Cleanup
    ssh "${remote_user}@${remote_ip}" "rm -rf /tmp/frp-setup"
    
    print_success "Remote server update complete!"
}
