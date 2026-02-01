#!/bin/bash

# Source output functions
source "$(dirname "${BASH_SOURCE[0]}")/output.sh"

# Default Configuration (can be overridden via environment variables or arguments)
FRP_VERSION="${FRP_VERSION:-0.51.3}"
FRP_ARCH="${FRP_ARCH:-linux_amd64}"
FRP_INSTALL_DIR="${FRP_INSTALL_DIR:-/opt/frp}"
DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_${FRP_ARCH}.tar.gz"
CONFIG_FILE="${HOME}/.frp-setup.conf"

# Export configuration variables
export FRP_VERSION FRP_ARCH FRP_INSTALL_DIR DOWNLOAD_URL CONFIG_FILE

save_config() {
    local server_location="$1"
    local client_location="$2"
    local server_ip="$3"
    local server_user="$4"
    local client_ip="$5"
    local client_user="$6"
    
    print_header "Saving Configuration"
    
    cat > "$CONFIG_FILE" << EOF
# FRP Auto Setup Configuration
# Generated on $(date)

# Server Configuration
SERVER_LOCATION="${server_location}"
SERVER_IP="${server_ip}"
SERVER_USER="${server_user}"

# Client Configuration
CLIENT_LOCATION="${client_location}"
CLIENT_IP="${client_ip}"
CLIENT_USER="${client_user}"
EOF
    
    chmod 600 "$CONFIG_FILE"
    print_success "Configuration saved to ${CONFIG_FILE}"
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        print_info "Loading configuration from ${CONFIG_FILE}"
        source "$CONFIG_FILE"
        return 0
    else
        return 1
    fi
}

show_saved_config() {
    if [ -f "$CONFIG_FILE" ]; then
        print_header "Saved Configuration"
        echo
        source "$CONFIG_FILE"
        
        echo -e "${YELLOW}Server Configuration:${NC}"
        if [ "$SERVER_LOCATION" = "1" ]; then
            echo "  Location: Local machine"
        elif [ "$SERVER_LOCATION" = "2" ]; then
            echo "  Location: Remote (SSH)"
            echo "  IP: ${SERVER_IP}"
            echo "  User: ${SERVER_USER}"
        else
            echo "  Location: Disabled"
        fi
        
        echo
        echo -e "${YELLOW}Client Configuration:${NC}"
        if [ "$CLIENT_LOCATION" = "1" ]; then
            echo "  Location: Local machine"
        elif [ "$CLIENT_LOCATION" = "2" ]; then
            echo "  Location: Remote (SSH)"
            echo "  IP: ${CLIENT_IP}"
            echo "  User: ${CLIENT_USER}"
        else
            echo "  Location: Disabled"
        fi
        echo
    else
        print_error "No saved configuration found"
        print_info "Config file: ${CONFIG_FILE}"
    fi
}
