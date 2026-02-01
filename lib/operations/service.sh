#!/bin/bash

# Source required libraries
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="$(dirname "${_SCRIPT_DIR}")"
source "${_LIB_DIR}/output.sh"
source "${_LIB_DIR}/config.sh"

stop_server() {
    local remote_ip="$1"
    local remote_user="${2:-root}"
    
    if [ -n "$remote_ip" ]; then
        print_header "Stopping FRP Server on Remote Host: ${remote_user}@${remote_ip}"
        ssh "${remote_user}@${remote_ip}" "sudo systemctl stop frps"
        print_success "FRP Server stopped on ${remote_ip}"
    else
        print_header "Stopping FRP Server"
        
        if systemctl is-active --quiet frps 2>/dev/null; then
            systemctl stop frps
            print_success "FRP Server stopped"
        else
            print_info "FRP Server is not running"
        fi
    fi
}

stop_client() {
    local remote_ip="$1"
    local remote_user="${2:-root}"
    
    if [ -n "$remote_ip" ]; then
        print_header "Stopping FRP Client on Remote Host: ${remote_user}@${remote_ip}"
        ssh "${remote_user}@${remote_ip}" "sudo systemctl stop frpc"
        print_success "FRP Client stopped on ${remote_ip}"
    else
        print_header "Stopping FRP Client"
        
        if systemctl is-active --quiet frpc 2>/dev/null; then
            systemctl stop frpc
            print_success "FRP Client stopped"
        else
            print_info "FRP Client is not running"
        fi
    fi
}

restart_server() {
    local remote_ip="$1"
    local remote_user="${2:-root}"
    
    if [ -n "$remote_ip" ]; then
        print_header "Restarting FRP Server on Remote Host: ${remote_user}@${remote_ip}"
        ssh "${remote_user}@${remote_ip}" "sudo systemctl restart frps"
        print_success "FRP Server restarted on ${remote_ip}"
    else
        print_header "Restarting FRP Server"
        
        if systemctl is-active --quiet frps 2>/dev/null; then
            systemctl restart frps
            print_success "FRP Server restarted"
        elif systemctl is-enabled --quiet frps 2>/dev/null; then
            systemctl start frps
            print_success "FRP Server started"
        else
            print_error "FRP Server is not installed or enabled"
            return 1
        fi
    fi
}

restart_client() {
    local remote_ip="$1"
    local remote_user="${2:-root}"
    
    if [ -n "$remote_ip" ]; then
        print_header "Restarting FRP Client on Remote Host: ${remote_user}@${remote_ip}"
        ssh "${remote_user}@${remote_ip}" "sudo systemctl restart frpc"
        print_success "FRP Client restarted on ${remote_ip}"
    else
        print_header "Restarting FRP Client"
        
        if systemctl is-active --quiet frpc 2>/dev/null; then
            systemctl restart frpc
            print_success "FRP Client restarted"
        elif systemctl is-enabled --quiet frpc 2>/dev/null; then
            systemctl start frpc
            print_success "FRP Client started"
        else
            print_error "FRP Client is not installed or enabled"
            return 1
        fi
    fi
}

remove_server() {
    local remote_ip="$1"
    local remote_user="${2:-root}"
    
    if [ -n "$remote_ip" ]; then
        print_header "Removing FRP Server on Remote Host: ${remote_user}@${remote_ip}"
        
        ssh -o LogLevel=QUIET -T "${remote_user}@${remote_ip}" << 'ENDSSH'
set -e

# Stop and disable service
if systemctl is-active --quiet frps 2>/dev/null; then
    sudo systemctl stop frps
    echo "Stopped FRP Server service"
fi

if systemctl is-enabled --quiet frps 2>/dev/null; then
    sudo systemctl disable frps
    echo "Disabled FRP Server service"
fi

# Remove systemd service file
if [ -f /etc/systemd/system/frps.service ]; then
    sudo rm /etc/systemd/system/frps.service
    sudo systemctl daemon-reload
    echo "Removed systemd service file"
fi

# Remove installation directory
if [ -d "/opt/frp" ]; then
    sudo rm -rf /opt/frp
    echo "Removed installation directory"
fi

echo "FRP Server completely removed"
ENDSSH
        
        print_success "FRP Server removed from ${remote_ip}"
    else
        print_header "Removing FRP Server"
        
        # Stop and disable service
        if systemctl is-active --quiet frps 2>/dev/null; then
            systemctl stop frps
            print_success "Stopped FRP Server service"
        fi
        
        if systemctl is-enabled --quiet frps 2>/dev/null; then
            systemctl disable frps
            print_success "Disabled FRP Server service"
        fi
        
        # Remove systemd service file
        if [ -f /etc/systemd/system/frps.service ]; then
            rm /etc/systemd/system/frps.service
            systemctl daemon-reload
            print_success "Removed systemd service file"
        fi
        
        # Remove installation directory
        if [ -d "$FRP_INSTALL_DIR" ]; then
            rm -rf "$FRP_INSTALL_DIR"
            print_success "Removed installation directory: $FRP_INSTALL_DIR"
        fi
        
        print_success "FRP Server completely removed"
    fi
}

remove_client() {
    local remote_ip="$1"
    local remote_user="${2:-root}"
    
    if [ -n "$remote_ip" ]; then
        print_header "Removing FRP Client on Remote Host: ${remote_user}@${remote_ip}"
        
        ssh -o LogLevel=QUIET -T "${remote_user}@${remote_ip}" << 'ENDSSH'
set -e

# Stop and disable service
if systemctl is-active --quiet frpc 2>/dev/null; then
    sudo systemctl stop frpc
    echo "Stopped FRP Client service"
fi

if systemctl is-enabled --quiet frpc 2>/dev/null; then
    sudo systemctl disable frpc
    echo "Disabled FRP Client service"
fi

# Remove systemd service file
if [ -f /etc/systemd/system/frpc.service ]; then
    sudo rm /etc/systemd/system/frpc.service
    sudo systemctl daemon-reload
    echo "Removed systemd service file"
fi

# Remove installation directory
if [ -d "/opt/frp" ]; then
    sudo rm -rf /opt/frp
    echo "Removed installation directory"
fi

echo "FRP Client completely removed"
ENDSSH
        
        print_success "FRP Client removed from ${remote_ip}"
    else
        print_header "Removing FRP Client"
        
        # Stop and disable service
        if systemctl is-active --quiet frpc 2>/dev/null; then
            systemctl stop frpc
            print_success "Stopped FRP Client service"
        fi
        
        if systemctl is-enabled --quiet frpc 2>/dev/null; then
            systemctl disable frpc
            print_success "Disabled FRP Client service"
        fi
        
        # Remove systemd service file
        if [ -f /etc/systemd/system/frpc.service ]; then
            rm /etc/systemd/system/frpc.service
            systemctl daemon-reload
            print_success "Removed systemd service file"
        fi
        
        # Remove installation directory
        if [ -d "$FRP_INSTALL_DIR" ]; then
            rm -rf "$FRP_INSTALL_DIR"
            print_success "Removed installation directory: $FRP_INSTALL_DIR"
        fi
        
        print_success "FRP Client completely removed"
    fi
}
