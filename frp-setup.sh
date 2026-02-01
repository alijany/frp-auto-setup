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
CONFIG_FILE="${HOME}/.frp-setup.conf"

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

prompt_input() {
    local prompt="$1"
    local default="$2"
    local value
    
    if [ -n "$default" ]; then
        read -p "${prompt} [${default}]: " value
        echo "${value:-$default}"
    else
        read -p "${prompt}: " value
        echo "$value"
    fi
}

prompt_password() {
    local prompt="$1"
    local password
    
    read -sp "${prompt}: " password
    echo >&2
    echo -n "$password"
}

prompt_confirm() {
    local prompt="$1"
    local response
    
    read -p "${prompt} (yes/no): " response
    [[ "$response" == "yes" ]] && return 0 || return 1
}

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

generate_random_string() {
    local length="${1:-16}"
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
}

generate_random_port() {
    local min="${1:-7000}"
    local max="${2:-8000}"
    echo $((min + RANDOM % (max - min)))
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

show_main_menu() {
    local server_location="$1"
    local client_location="$2"
    
    clear
    print_header "FRP Auto Setup - Main Menu"
    echo
    
    # Show current configuration
    if [ "$server_location" = "1" ]; then
        print_info "Server: Local machine"
    elif [ "$server_location" = "2" ]; then
        print_info "Server: Remote (SSH)"
    else
        print_info "Server: Disabled"
    fi
    
    if [ "$client_location" = "1" ]; then
        print_info "Client: Local machine"
    elif [ "$client_location" = "2" ]; then
        print_info "Client: Remote (SSH)"
    else
        print_info "Client: Disabled"
    fi
    
    echo
    echo -e "${BLUE}1)${NC} Setup FRP Server"
    echo -e "${BLUE}2)${NC} Setup FRP Client"
    echo -e "${BLUE}3)${NC} Update FRP Server Configuration"
    echo -e "${BLUE}4)${NC} Update FRP Client Configuration"
    echo -e "${BLUE}5)${NC} Stop FRP Server"
    echo -e "${BLUE}6)${NC} Stop FRP Client"
    echo -e "${BLUE}7)${NC} Restart FRP Server"
    echo -e "${BLUE}8)${NC} Restart FRP Client"
    echo -e "${BLUE}9)${NC} Remove FRP Server"
    echo -e "${BLUE}10)${NC} Remove FRP Client"
    echo -e "${BLUE}11)${NC} View FRP Logs"
    echo -e "${BLUE}12)${NC} Test FRP Connection"
    echo -e "${BLUE}13)${NC} Show FRP Config"
    echo -e "${BLUE}14)${NC} Auto Setup (Server + Client)"
    echo -e "${BLUE}15)${NC} Save Configuration"
    echo -e "${BLUE}16)${NC} View Saved Configuration"
    echo -e "${BLUE}17)${NC} Exit"
    echo
}

interactive_server_setup() {
    local is_update="$1"
    local remote_ip="$2"
    local remote_user="${3:-root}"
    
    print_header "FRP Server Configuration"
    echo
    
    if [ -n "$remote_ip" ]; then
        print_info "Configuring remote server: ${remote_user}@${remote_ip}"
    else
        print_info "Configuring local server"
    fi
    echo
    
    # Get configuration
    local bind_port=$(prompt_input "Server bind port" "7000")
    local http_port=$(prompt_input "HTTP vhost port" "80")
    local https_port=$(prompt_input "HTTPS vhost port" "443")
    local dashboard_port=$(prompt_input "Dashboard port" "7500")
    local dashboard_user=$(prompt_input "Dashboard username" "admin")
    local dashboard_pwd=$(prompt_password "Dashboard password")
    
    if [ -z "$dashboard_pwd" ]; then
        print_error "Dashboard password is required"
        return 1
    fi
    
    echo
    local use_token=$(prompt_input "Use authentication token? (yes/no)" "no")
    local auth_token=""
    if [ "$use_token" = "yes" ]; then
        auth_token=$(prompt_input "Authentication token")
    fi
    
    # Execute setup
    if [ "$is_update" = "true" ]; then
        if [ -n "$remote_ip" ]; then
            setup_update_server_remote "$remote_ip" "$bind_port" "$http_port" "$https_port" "$dashboard_port" "$dashboard_user" "$dashboard_pwd" "$auth_token" "$remote_user"
        else
            setup_update_server_local "$bind_port" "$http_port" "$https_port" "$dashboard_port" "$dashboard_user" "$dashboard_pwd" "$auth_token"
        fi
    else
        setup_server "$bind_port" "$http_port" "$https_port" "$dashboard_port" "$dashboard_user" "$dashboard_pwd" "$auth_token" "$remote_ip" "$remote_user"
    fi
}

interactive_client_setup() {
    local is_update="$1"
    local remote_ip="$2"
    local remote_user="${3:-root}"
    
    print_header "FRP Client Configuration"
    echo
    
    if [ -n "$remote_ip" ]; then
        print_info "Configuring remote client: ${remote_user}@${remote_ip}"
    else
        print_info "Configuring local client"
    fi
    echo
    
    # Get configuration
    local server_addr=$(prompt_input "FRP Server address (IP or domain)")
    if [ -z "$server_addr" ]; then
        print_error "Server address is required"
        return 1
    fi
    
    local server_port=$(prompt_input "FRP Server port" "7000")
    local domain=$(prompt_input "Your custom domain (e.g., example.com)")
    
    if [ -z "$domain" ]; then
        print_error "Domain is required"
        return 1
    fi
    
    local local_http=$(prompt_input "Local HTTP port" "80")
    local local_https=$(prompt_input "Local HTTPS port" "443")
    
    echo
    local use_token=$(prompt_input "Use authentication token? (yes/no)" "no")
    local auth_token=""
    if [ "$use_token" = "yes" ]; then
        auth_token=$(prompt_input "Authentication token")
    fi
    
    # Execute setup
    if [ "$is_update" = "true" ]; then
        if [ -n "$remote_ip" ]; then
            setup_update_client_remote "$remote_ip" "$server_addr" "$server_port" "$domain" "$local_http" "$local_https" "$auth_token" "$remote_user"
        else
            setup_update_client_local "$server_addr" "$server_port" "$domain" "$local_http" "$local_https" "$auth_token"
        fi
    else
        if [ -n "$remote_ip" ]; then
            setup_client_remote "$remote_ip" "$server_addr" "$server_port" "$domain" "$local_http" "$local_https" "$auth_token" "$remote_user"
        else
            setup_client "$server_addr" "$server_port" "$domain" "$local_http" "$local_https" "$auth_token"
        fi
    fi
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
    
    # Copy script to remote server
    scp "$0" "${remote_user}@${remote_ip}:/tmp/frp-setup.sh"
    
    # Build remote command with sudo and properly quoted arguments
    local remote_cmd="sudo bash /tmp/frp-setup.sh update-server -p '${bind_port}' -h '${http_port}' -s '${https_port}' -d '${dashboard_port}' -u '${dashboard_user}' -w '${dashboard_pwd}'"
    if [ -n "$auth_token" ]; then
        remote_cmd="${remote_cmd} -t '${auth_token}'"
    fi
    
    # Execute on remote server
    ssh "${remote_user}@${remote_ip}" "$remote_cmd"
    
    # Cleanup
    ssh "${remote_user}@${remote_ip}" "rm /tmp/frp-setup.sh"
    
    print_success "Remote server update complete!"
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
    
    # Copy script to remote server
    scp "$0" "${remote_user}@${remote_ip}:/tmp/frp-setup.sh"
    
    # Build remote command with sudo and properly quoted arguments
    local remote_cmd="sudo bash /tmp/frp-setup.sh client -a '${server_addr}' -p '${server_port}' -m '${domain}' -l '${local_http}' -L '${local_https}'"
    if [ -n "$auth_token" ]; then
        remote_cmd="${remote_cmd} -t '${auth_token}'"
    fi
    
    # Execute on remote server
    ssh "${remote_user}@${remote_ip}" "$remote_cmd"
    
    # Cleanup
    ssh "${remote_user}@${remote_ip}" "rm /tmp/frp-setup.sh"
    
    print_success "Remote client setup complete!"
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
    
    # Copy script to remote server
    scp "$0" "${remote_user}@${remote_ip}:/tmp/frp-setup.sh"
    
    # Build remote command with sudo and properly quoted arguments
    local remote_cmd="sudo bash /tmp/frp-setup.sh update-client -a '${server_addr}' -p '${server_port}' -m '${domain}' -l '${local_http}' -L '${local_https}'"
    if [ -n "$auth_token" ]; then
        remote_cmd="${remote_cmd} -t '${auth_token}'"
    fi
    
    # Execute on remote server
    ssh "${remote_user}@${remote_ip}" "$remote_cmd"
    
    # Cleanup
    ssh "${remote_user}@${remote_ip}" "rm /tmp/frp-setup.sh"
    
    print_success "Remote client update complete!"
}

interactive_mode() {
    # Try to load saved configuration
    local SERVER_IP=""
    local SERVER_USER="root"
    local CLIENT_IP=""
    local CLIENT_USER="root"
    local server_location=""
    local client_location=""
    local use_saved_config="no"
    
    if [ -f "$CONFIG_FILE" ]; then
        clear
        print_header "FRP Auto Setup"
        echo
        print_success "Found saved configuration: ${CONFIG_FILE}"
        echo
        
        # Show saved config preview
        source "$CONFIG_FILE"
        echo -e "${YELLOW}Saved settings:${NC}"
        if [ "$SERVER_LOCATION" = "2" ]; then
            echo "  Server: ${SERVER_USER}@${SERVER_IP}"
        elif [ "$SERVER_LOCATION" = "1" ]; then
            echo "  Server: Local"
        fi
        if [ "$CLIENT_LOCATION" = "2" ]; then
            echo "  Client: ${CLIENT_USER}@${CLIENT_IP}"
        elif [ "$CLIENT_LOCATION" = "1" ]; then
            echo "  Client: Local"
        fi
        echo
        
        use_saved_config=$(prompt_input "Use saved configuration? (yes/no)" "yes")
        
        if [ "$use_saved_config" = "yes" ]; then
            server_location="$SERVER_LOCATION"
            client_location="$CLIENT_LOCATION"
            print_success "Loaded saved configuration"
            sleep 1
        fi
    fi
    
    # If not using saved config, ask for new configuration
    if [ "$use_saved_config" != "yes" ]; then
        # Collect server configuration at startup
        clear
        print_header "FRP Auto Setup - Initial Configuration"
        echo
        print_info "First, let's configure which servers you want to manage."
        echo
        
        # Server configuration
        echo -e "${YELLOW}FRP Server location:${NC}"
        echo "1) Local machine (this computer)"
        echo "2) Remote server (via SSH)"
        echo "3) Skip server management"
        server_location=$(prompt_input "Choose server location" "1")
        
        SERVER_IP=""
        SERVER_USER="root"
        if [ "$server_location" = "2" ]; then
            SERVER_IP=$(prompt_input "Enter FRP Server IP")
            if [ -n "$SERVER_IP" ]; then
                SERVER_USER=$(prompt_input "SSH username" "root")
                print_info "Testing SSH connection to ${SERVER_USER}@${SERVER_IP}..."
            
            # Try SSH connection with detailed error
            if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${SERVER_USER}@${SERVER_IP}" "exit" 2>/dev/null; then
                print_success "SSH key authentication successful"
            else
                print_error "SSH key authentication failed"
                echo
                print_info "Trying to diagnose the issue..."
                
                # Test connection and show error
                ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${SERVER_USER}@${SERVER_IP}" "exit" 2>&1 | head -5
                
                echo
                print_info "Common issues:"
                print_info "1. SSH keys not set up - Run: ssh-copy-id ${SERVER_USER}@${SERVER_IP}"
                print_info "2. Wrong username - Current: ${SERVER_USER}"
                print_info "3. Firewall blocking port 22"
                print_info "4. SSH keys not in WSL - See setup-wsl-ssh.sh"
                echo
                
                if prompt_confirm "Continue anyway? (You'll be prompted for password)"; then
                    print_info "Will use password authentication"
                else
                    print_info "Server management will be disabled"
                    SERVER_IP=""
                    SERVER_USER="root"
                    server_location="3"
                fi
            fi
        fi
        fi
        
        echo
        
        # Client configuration
        echo -e "${YELLOW}FRP Client location:${NC}"
        echo "1) Local machine (this computer)"
        echo "2) Remote server (via SSH)"
        echo "3) Skip client management"
        client_location=$(prompt_input "Choose client location" "1")
        
        CLIENT_IP=""
        CLIENT_USER="root"
        if [ "$client_location" = "2" ]; then
            CLIENT_IP=$(prompt_input "Enter FRP Client machine IP")
            if [ -n "$CLIENT_IP" ]; then
                CLIENT_USER=$(prompt_input "SSH username" "root")
                print_info "Testing SSH connection to ${CLIENT_USER}@${CLIENT_IP}..."
            
            # Try SSH connection with detailed error
            if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${CLIENT_USER}@${CLIENT_IP}" "exit" 2>/dev/null; then
                print_success "SSH key authentication successful"
            else
                print_error "SSH key authentication failed"
                echo
                print_info "Trying to diagnose the issue..."
                
                # Test connection and show error
                ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${CLIENT_USER}@${CLIENT_IP}" "exit" 2>&1 | head -5
                
                echo
                print_info "Common issues:"
                print_info "1. SSH keys not set up - Run: ssh-copy-id ${CLIENT_USER}@${CLIENT_IP}"
                print_info "2. Wrong username - Current: ${CLIENT_USER}"
                print_info "3. Firewall blocking port 22"
                print_info "4. SSH keys not in WSL - See setup-wsl-ssh.sh"
                echo
                
                if prompt_confirm "Continue anyway? (You'll be prompted for password)"; then
                    print_info "Will use password authentication"
                else
                    print_info "Client management will be disabled"
                    CLIENT_IP=""
                    CLIENT_USER="root"
                    client_location="3"
                fi
            fi
        fi
        fi
        
        echo
        print_success "Configuration complete!"
        read -p "Press Enter to continue..."
    fi
    
    while true; do
        show_main_menu "$server_location" "$client_location"
        local choice=$(prompt_input "Select an option" "17")
        echo
        
        case "$choice" in
            1)
                if [ "$server_location" = "3" ]; then
                    print_error "Server management is disabled"
                else
                    interactive_server_setup "false" "$SERVER_IP" "$SERVER_USER"
                fi
                ;;
            2)
                if [ "$client_location" = "3" ]; then
                    print_error "Client management is disabled"
                else
                    interactive_client_setup "false" "$CLIENT_IP" "$CLIENT_USER"
                fi
                ;;
            3)
                if [ "$server_location" = "3" ]; then
                    print_error "Server management is disabled"
                else
                    interactive_server_setup "true" "$SERVER_IP" "$SERVER_USER"
                fi
                ;;
            4)
                if [ "$client_location" = "3" ]; then
                    print_error "Client management is disabled"
                else
                    interactive_client_setup "true" "$CLIENT_IP" "$CLIENT_USER"
                fi
                ;;
            5)
                if [ "$server_location" = "3" ]; then
                    print_error "Server management is disabled"
                else
                    stop_server "$SERVER_IP" "$SERVER_USER"
                fi
                ;;
            6)
                if [ "$client_location" = "3" ]; then
                    print_error "Client management is disabled"
                else
                    stop_client "$CLIENT_IP" "$CLIENT_USER"
                fi
                ;;
            7)
                if [ "$server_location" = "3" ]; then
                    print_error "Server management is disabled"
                else
                    restart_server "$SERVER_IP" "$SERVER_USER"
                fi
                ;;
            8)
                if [ "$client_location" = "3" ]; then
                    print_error "Client management is disabled"
                else
                    restart_client "$CLIENT_IP" "$CLIENT_USER"
                fi
                ;;
            9)
                if [ "$server_location" = "3" ]; then
                    print_error "Server management is disabled"
                else
                    if prompt_confirm "Are you sure you want to remove FRP Server?"; then
                        remove_server "$SERVER_IP" "$SERVER_USER"
                    fi
                fi
                ;;
            10)
                if [ "$client_location" = "3" ]; then
                    print_error "Client management is disabled"
                else
                    if prompt_confirm "Are you sure you want to remove FRP Client?"; then
                        remove_client "$CLIENT_IP" "$CLIENT_USER"
                    fi
                fi
                ;;
            11)
                echo -e "${YELLOW}View logs for:${NC}"
                echo "1) FRP Server"
                echo "2) FRP Client"
                local log_choice=$(prompt_input "Select service" "1")
                echo
                
                if [ "$log_choice" = "1" ]; then
                    if [ "$server_location" = "3" ]; then
                        print_error "Server management is disabled"
                    else
                        local log_lines=$(prompt_input "Number of lines to show" "50")
                        view_logs "server" "$SERVER_IP" "$SERVER_USER" "$log_lines"
                    fi
                elif [ "$log_choice" = "2" ]; then
                    if [ "$client_location" = "3" ]; then
                        print_error "Client management is disabled"
                    else
                        local log_lines=$(prompt_input "Number of lines to show" "50")
                        view_logs "client" "$CLIENT_IP" "$CLIENT_USER" "$log_lines"
                    fi
                else
                    print_error "Invalid choice"
                fi
                ;;
            12)
                echo -e "${YELLOW}Test connection for:${NC}"
                echo "1) FRP Server"
                echo "2) FRP Client"
                local test_choice=$(prompt_input "Select service" "1")
                echo
                
                if [ "$test_choice" = "1" ]; then
                    if [ "$server_location" = "3" ]; then
                        print_error "Server management is disabled"
                    else
                        test_connection "server" "$SERVER_IP" "$SERVER_USER"
                    fi
                elif [ "$test_choice" = "2" ]; then
                    if [ "$client_location" = "3" ]; then
                        print_error "Client management is disabled"
                    else
                        test_connection "client" "$CLIENT_IP" "$CLIENT_USER"
                    fi
                else
                    print_error "Invalid choice"
                fi
                ;;
            13)
                echo -e "${YELLOW}Show config for:${NC}"
                echo "1) FRP Server"
                echo "2) FRP Client"
                local config_choice=$(prompt_input "Select service" "1")
                echo
                
                if [ "$config_choice" = "1" ]; then
                    if [ "$server_location" = "3" ]; then
                        print_error "Server management is disabled"
                    else
                        show_frp_config "server" "$SERVER_IP" "$SERVER_USER"
                    fi
                elif [ "$config_choice" = "2" ]; then
                    if [ "$client_location" = "3" ]; then
                        print_error "Client management is disabled"
                    else
                        show_frp_config "client" "$CLIENT_IP" "$CLIENT_USER"
                    fi
                else
                    print_error "Invalid choice"
                fi
                ;;
            14)
                auto_setup "$SERVER_IP" "$SERVER_USER" "$CLIENT_IP" "$CLIENT_USER"
                ;;
            15)
                save_config "$server_location" "$client_location" "$SERVER_IP" "$SERVER_USER" "$CLIENT_IP" "$CLIENT_USER"
                ;;
            16)
                show_saved_config
                ;;
            17)
                print_success "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please try again."
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

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

view_logs() {
    local service_type="$1"  # "server" or "client"
    local remote_ip="$2"
    local remote_user="${3:-root}"
    local lines="${4:-50}"
    
    local service_name
    if [ "$service_type" = "server" ]; then
        service_name="frps"
    else
        service_name="frpc"
    fi
    
    if [ -n "$remote_ip" ]; then
        print_header "Viewing FRP ${service_type^} Logs on Remote Host: ${remote_user}@${remote_ip}"
        echo
        print_info "Press Ctrl+C to exit"
        echo
        ssh "${remote_user}@${remote_ip}" "sudo journalctl -u ${service_name} -n ${lines} -f"
    else
        print_header "Viewing FRP ${service_type^} Logs"
        echo
        print_info "Press Ctrl+C to exit"
        echo
        
        if systemctl list-unit-files | grep -q "${service_name}.service"; then
            journalctl -u ${service_name} -n ${lines} -f
        else
            print_error "FRP ${service_type^} is not installed"
        fi
    fi
}

test_connection() {
    local service_type="$1"  # "server" or "client"
    local remote_ip="$2"
    local remote_user="${3:-root}"
    
    local service_name
    local config_file
    
    if [ "$service_type" = "server" ]; then
        service_name="frps"
        config_file="${FRP_INSTALL_DIR}/frps.ini"
    else
        service_name="frpc"
        config_file="${FRP_INSTALL_DIR}/frpc.ini"
    fi
    
    print_header "Testing FRP ${service_type^} Connection - Real Data Test"
    echo
    
    if [ -n "$remote_ip" ]; then
        print_info "Testing remote service on ${remote_user}@${remote_ip}..."
        echo
        
        # Check if service is running
        if ! ssh "${remote_user}@${remote_ip}" "sudo systemctl is-active --quiet ${service_name}"; then
            print_error "${service_name} service is not running"
            echo
            print_info "Last 20 log lines:"
            ssh "${remote_user}@${remote_ip}" "sudo journalctl -u ${service_name} -n 20 --no-pager"
            return 1
        fi
        
        print_success "✓ Service is running"
        
        if [ "$service_type" = "server" ]; then
            # Test server bind port and dashboard
            local bind_port=$(ssh "${remote_user}@${remote_ip}" "grep -E '^bind_port' ${config_file} 2>/dev/null | cut -d'=' -f2 | tr -d ' '")
            local dash_port=$(ssh "${remote_user}@${remote_ip}" "grep -E '^dashboard_port' ${config_file} 2>/dev/null | cut -d'=' -f2 | tr -d ' '")
            
            echo
            print_info "Testing bind port connectivity..."
            if ssh "${remote_user}@${remote_ip}" "timeout 3 bash -c 'echo test_data > /dev/tcp/127.0.0.1/${bind_port}' 2>/dev/null"; then
                print_success "✓ Bind port ${bind_port} is accessible"
            else
                print_error "✗ Bind port ${bind_port} test failed"
            fi
            
            if [ -n "$dash_port" ]; then
                echo
                print_info "Testing dashboard HTTP connection..."
                if ssh "${remote_user}@${remote_ip}" "curl -s -m 5 -o /dev/null -w '%{http_code}' http://127.0.0.1:${dash_port} | grep -qE '(200|401|302)'"; then
                    print_success "✓ Dashboard is responding on port ${dash_port}"
                else
                    print_error "✗ Dashboard connection test failed on port ${dash_port}"
                fi
            fi
        else
            # Test client connection to server
            local server_addr=$(ssh "${remote_user}@${remote_ip}" "grep -E '^server_addr' ${config_file} 2>/dev/null | cut -d'=' -f2 | tr -d ' '")
            local server_port=$(ssh "${remote_user}@${remote_ip}" "grep -E '^server_port' ${config_file} 2>/dev/null | cut -d'=' -f2 | tr -d ' '")
            
            echo
            print_info "Testing connection to FRP server ${server_addr}:${server_port}..."
            if ssh "${remote_user}@${remote_ip}" "timeout 5 bash -c 'echo -n \"PING\" > /dev/tcp/${server_addr}/${server_port}' 2>/dev/null"; then
                print_success "✓ Can reach FRP server ${server_addr}:${server_port}"
            else
                print_error "✗ Cannot reach FRP server ${server_addr}:${server_port}"
            fi
            
            # Check client logs for successful connection
            echo
            print_info "Checking client connection status in logs..."
            if ssh "${remote_user}@${remote_ip}" "sudo journalctl -u ${service_name} -n 50 --no-pager | grep -iE '(login to server success|start proxy success)'" | head -5; then
                print_success "✓ Client has successfully connected to server"
            else
                print_error "✗ No successful connection messages found in logs"
            fi
        fi
        
        echo
        print_info "Recent service logs:"
        ssh "${remote_user}@${remote_ip}" "sudo journalctl -u ${service_name} -n 10 --no-pager"
        
    else
        print_info "Testing local service..."
        echo
        
        # Check if service is running
        if ! systemctl is-active --quiet ${service_name} 2>/dev/null; then
            print_error "${service_name} service is not running or not installed"
            if systemctl list-unit-files | grep -q "${service_name}.service"; then
                echo
                print_info "Last 20 log lines:"
                journalctl -u ${service_name} -n 20 --no-pager
            fi
            return 1
        fi
        
        print_success "✓ Service is running"
        
        if [ "$service_type" = "server" ]; then
            # Test server bind port and dashboard
            local bind_port=$(grep -E '^bind_port' ${config_file} 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
            local dash_port=$(grep -E '^dashboard_port' ${config_file} 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
            
            echo
            print_info "Testing bind port connectivity..."
            if timeout 3 bash -c "echo test_data > /dev/tcp/127.0.0.1/${bind_port}" 2>/dev/null; then
                print_success "✓ Bind port ${bind_port} is accessible"
            else
                print_error "✗ Bind port ${bind_port} test failed"
            fi
            
            if [ -n "$dash_port" ]; then
                echo
                print_info "Testing dashboard HTTP connection..."
                local http_code=$(curl -s -m 5 -o /dev/null -w '%{http_code}' http://127.0.0.1:${dash_port} 2>/dev/null)
                if echo "$http_code" | grep -qE '(200|401|302)'; then
                    print_success "✓ Dashboard is responding on port ${dash_port} (HTTP ${http_code})"
                else
                    print_error "✗ Dashboard connection test failed on port ${dash_port}"
                fi
            fi
            
            # Check for active client connections
            echo
            print_info "Checking for connected clients..."
            local client_count=$(journalctl -u ${service_name} -n 100 --no-pager 2>/dev/null | grep -c "client login success" || echo "0")
            if [ "$client_count" -gt 0 ]; then
                print_success "✓ Detected ${client_count} client connection(s) in recent logs"
            else
                print_info "ℹ No client connections detected in recent logs"
            fi
            
        else
            # Test client connection to server
            local server_addr=$(grep -E '^server_addr' ${config_file} 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
            local server_port=$(grep -E '^server_port' ${config_file} 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
            
            echo
            print_info "Testing connection to FRP server ${server_addr}:${server_port}..."
            if timeout 5 bash -c "echo -n 'PING' > /dev/tcp/${server_addr}/${server_port}" 2>/dev/null; then
                print_success "✓ Can reach FRP server ${server_addr}:${server_port}"
            else
                print_error "✗ Cannot reach FRP server ${server_addr}:${server_port}"
            fi
            
            # Check client logs for successful connection
            echo
            print_info "Checking client connection status in logs..."
            if journalctl -u ${service_name} -n 50 --no-pager 2>/dev/null | grep -iE '(login to server success|start proxy success)' | head -5; then
                print_success "✓ Client has successfully connected to server"
            else
                print_error "✗ No successful connection messages found in logs"
            fi
            
            # Test local proxied services
            echo
            print_info "Testing local proxied services..."
            local local_http=$(grep -A 5 '\[web_http\]' ${config_file} 2>/dev/null | grep 'local_port' | cut -d'=' -f2 | tr -d ' ')
            if [ -n "$local_http" ]; then
                if timeout 3 bash -c "echo -e 'GET / HTTP/1.0\r\n\r\n' > /dev/tcp/127.0.0.1/${local_http}" 2>/dev/null; then
                    print_success "✓ Local HTTP service on port ${local_http} is accessible"
                else
                    print_info "ℹ Local HTTP service on port ${local_http} may not be running"
                fi
            fi
        fi
        
        echo
        print_info "Recent service logs:"
        journalctl -u ${service_name} -n 10 --no-pager
    fi
}

auto_setup() {
    local server_ip="$1"
    local server_user="${2:-root}"
    local client_ip="$3"
    local client_user="${4:-root}"
    
    print_header "Auto Setup - Server + Client"
    echo
    print_info "This will automatically configure both FRP server and client"
    print_info "with randomly generated secure credentials."
    echo
    
    # Get domain for client
    local domain=$(prompt_input "Enter your custom domain (e.g., example.com)")
    if [ -z "$domain" ]; then
        print_error "Domain is required"
        return 1
    fi
    
    # Determine server address
    local server_addr
    if [ -n "$server_ip" ]; then
        server_addr="$server_ip"
        print_info "Server will be set up on: ${server_user}@${server_ip}"
    else
        print_info "Server will be set up locally"
        # Get local IP or use localhost
        server_addr=$(hostname -I | awk '{print $1}' || echo "127.0.0.1")
    fi
    
    if [ -n "$client_ip" ]; then
        print_info "Client will be set up on: ${client_user}@${client_ip}"
    else
        print_info "Client will be set up locally"
    fi
    
    echo
    if ! prompt_confirm "Continue with auto setup?"; then
        print_info "Auto setup cancelled"
        return 0
    fi
    
    # Generate random values
    print_header "Generating Secure Random Values"
    local bind_port=$(generate_random_port 7000 7999)
    local dashboard_port=$(generate_random_port 7500 8499)
    local dashboard_pwd=$(generate_random_string 20)
    local auth_token=$(generate_random_string 32)
    local dashboard_user="admin"
    
    print_success "Bind Port: ${bind_port}"
    print_success "Dashboard Port: ${dashboard_port}"
    print_success "Dashboard User: ${dashboard_user}"
    print_success "Dashboard Password: ${dashboard_pwd}"
    print_success "Auth Token: ${auth_token}"
    echo
    
    # Setup server
    print_header "Step 1: Setting up FRP Server"
    if ! setup_server "$bind_port" "80" "443" "$dashboard_port" "$dashboard_user" "$dashboard_pwd" "$auth_token" "$server_ip" "$server_user"; then
        print_error "Server setup failed!"
        return 1
    fi
    
    echo
    sleep 2
    
    # Setup client
    print_header "Step 2: Setting up FRP Client"
    if [ -n "$client_ip" ]; then
        if ! setup_client_remote "$client_ip" "$server_addr" "$bind_port" "$domain" "80" "443" "$auth_token" "$client_user"; then
            print_error "Client setup failed!"
            return 1
        fi
    else
        if ! setup_client "$server_addr" "$bind_port" "$domain" "80" "443" "$auth_token"; then
            print_error "Client setup failed!"
            return 1
        fi
    fi
    
    # Display summary
    echo
    print_header "Auto Setup Complete!"
    echo
    print_success "Server Configuration:"
    echo "  Server Address: ${server_addr}"
    echo "  Bind Port: ${bind_port}"
    echo "  Dashboard: http://${server_addr}:${dashboard_port}"
    echo "  Dashboard User: ${dashboard_user}"
    echo "  Dashboard Password: ${dashboard_pwd}"
    echo
    print_success "Client Configuration:"
    echo "  Server: ${server_addr}:${bind_port}"
    echo "  Domain: ${domain}"
    echo "  Auth Token: ${auth_token}"
    echo
    print_info "IMPORTANT: Save these credentials in a secure location!"
    echo
    
    # Optionally save to file
    if prompt_confirm "Save credentials to a file?"; then
        local cred_file="${HOME}/frp-auto-setup-credentials-$(date +%Y%m%d-%H%M%S).txt"
        cat > "$cred_file" << EOF
FRP Auto Setup Credentials
Generated: $(date)

=== Server Configuration ===
Server Address: ${server_addr}
Bind Port: ${bind_port}
Dashboard URL: http://${server_addr}:${dashboard_port}
Dashboard User: ${dashboard_user}
Dashboard Password: ${dashboard_pwd}

=== Client Configuration ===
Server: ${server_addr}:${bind_port}
Domain: ${domain}
Auth Token: ${auth_token}

=== Service Commands ===
Restart Server: systemctl restart frps
Restart Client: systemctl restart frpc
View Server Logs: journalctl -u frps -f
View Client Logs: journalctl -u frpc -f
EOF
        chmod 600 "$cred_file"
        print_success "Credentials saved to: ${cred_file}"
    fi
}

show_frp_config() {
    local service_type="$1"  # "server" or "client"
    local remote_ip="$2"
    local remote_user="${3:-root}"
    
    local service_name
    local config_file
    
    if [ "$service_type" = "server" ]; then
        service_name="frps"
        config_file="${FRP_INSTALL_DIR}/frps.ini"
    else
        service_name="frpc"
        config_file="${FRP_INSTALL_DIR}/frpc.ini"
    fi
    
    print_header "FRP ${service_type^} Configuration"
    echo
    
    if [ -n "$remote_ip" ]; then
        print_info "Configuration on Remote Host: ${remote_user}@${remote_ip}"
        print_info "Config file: ${config_file}"
        echo
        
        if ssh "${remote_user}@${remote_ip}" "test -f ${config_file}"; then
            ssh "${remote_user}@${remote_ip}" "cat ${config_file}"
        else
            print_error "Configuration file not found on remote host"
            print_info "FRP ${service_type^} may not be installed"
        fi
    else
        print_info "Config file: ${config_file}"
        echo
        
        if [ -f "$config_file" ]; then
            cat "$config_file"
        else
            print_error "Configuration file not found"
            print_info "FRP ${service_type^} may not be installed"
        fi
    fi
}

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
        
        ssh "${remote_user}@${remote_ip}" << 'ENDSSH'
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
        
        ssh "${remote_user}@${remote_ip}" << 'ENDSSH'
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
        
        # Copy script to remote server
        scp "$0" "${remote_user}@${remote_ip}:/tmp/frp-setup.sh"
        
        # Build remote command with sudo and properly quoted arguments
        local remote_cmd="sudo bash /tmp/frp-setup.sh server -p '${bind_port}' -h '${http_port}' -s '${https_port}' -d '${dashboard_port}' -u '${dashboard_user}' -w '${dashboard_pwd}'"
        if [ -n "$auth_token" ]; then
            remote_cmd="${remote_cmd} -t '${auth_token}'"
        fi
        
        # Execute on remote server
        ssh "${remote_user}@${remote_ip}" "$remote_cmd"
        
        # Cleanup
        ssh "${remote_user}@${remote_ip}" "rm /tmp/frp-setup.sh"
        
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

# Network optimization for unstable connections
tcp_mux = true
tcp_mux_keepalive_interval = 30
heartbeat_interval = 10
heartbeat_timeout = 45

# Connection pooling for better performance
max_pool_count = 10

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
        print_info "TCP Mux Keepalive: 30s"
        print_info "Heartbeat Interval: 10s"
        print_info "Heartbeat Timeout: 45s"
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

# Network optimization for unstable connections
tcp_mux = true
tcp_mux_keepalive_interval = 30
heartbeat_interval = 10
heartbeat_timeout = 45

# Connection pooling
pool_count = 5

# Reconnection settings
login_fail_exit = false
dial_server_timeout = 20
dial_server_keepalive = 7200

# Protocol optimization
protocol = tcp
tls_enable = false

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
        print_info "TCP Mux Keepalive: 30s"
        print_info "Heartbeat Interval: 10s"
        print_info "Heartbeat Timeout: 45s"
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

# Main script
# if [ "$EUID" -ne 0 ]; then
#     print_error "This script must be run as root"
#     print_info "Use: sudo $0 ..."
#     exit 1
# fi
# If no arguments, run interactive mode
if [ $# -eq 0 ]; then
    interactive_mode
    exit 0
fi
MODE="$1"
shift || show_usage

case "$MODE" in
    server)
        # Default values
        REMOTE_IP=""
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
                -i|--server-ip)
                    REMOTE_IP="$2"
                    shift 2
                    ;;
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
        
        setup_server "$BIND_PORT" "$HTTP_PORT" "$HTTPS_PORT" "$DASHBOARD_PORT" "$DASHBOARD_USER" "$DASHBOARD_PWD" "$AUTH_TOKEN" "$REMOTE_IP"
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
        
    update-server)
        # Default values
        REMOTE_IP=""
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
                -i|--server-ip)
                    REMOTE_IP="$2"
                    shift 2
                    ;;
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
        
        if [ -z "$DASHBOARD_PWD" ]; then
            print_error "Dashboard password is required!"
            print_info "Use -w or --password to set a password"
            exit 1
        fi
        
        # If remote IP provided, execute on remote server
        if [ -n "$REMOTE_IP" ]; then
            print_header "Updating FRP Server on Remote Host: ${REMOTE_IP}"
            
            # Copy script to remote server
            scp "$0" "root@${REMOTE_IP}:/tmp/frp-setup.sh"
            
            # Build remote command
            local remote_cmd="bash /tmp/frp-setup.sh update-server -p ${BIND_PORT} -h ${HTTP_PORT} -s ${HTTPS_PORT} -d ${DASHBOARD_PORT} -u ${DASHBOARD_USER} -w ${DASHBOARD_PWD}"
            if [ -n "$AUTH_TOKEN" ]; then
                remote_cmd="${remote_cmd} -t ${AUTH_TOKEN}"
            fi
            
            # Execute on remote server
            ssh "root@${REMOTE_IP}" "$remote_cmd"
            
            # Cleanup
            ssh "root@${REMOTE_IP}" "rm /tmp/frp-setup.sh"
            
            print_success "Remote server update complete!"
            exit 0
        fi
        
        # Check if server is installed locally
        if [ ! -f "${FRP_INSTALL_DIR}/frps.ini" ]; then
            print_error "FRP Server configuration not found!"
            print_info "Please run 'server' setup first"
            exit 1
        fi
        
        print_header "Updating FRP Server Configuration"
        print_info "Current config: ${FRP_INSTALL_DIR}/frps.ini"
        
        # Backup existing config
        cp "${FRP_INSTALL_DIR}/frps.ini" "${FRP_INSTALL_DIR}/frps.ini.backup.$(date +%s)"
        print_info "Backed up existing configuration"
        
        # Recreate configuration
        setup_server "$BIND_PORT" "$HTTP_PORT" "$HTTPS_PORT" "$DASHBOARD_PORT" "$DASHBOARD_USER" "$DASHBOARD_PWD" "$AUTH_TOKEN" ""
        ;;
        
    update-client)
        # Check if client is installed
        if [ ! -f "${FRP_INSTALL_DIR}/frpc.ini" ]; then
            print_error "FRP Client configuration not found!"
            print_info "Please run 'client' setup first"
            exit 1
        fi
        
        print_header "Updating FRP Client Configuration"
        print_info "Current config: ${FRP_INSTALL_DIR}/frpc.ini"
        
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
        
        if [ -z "$SERVER_ADDR" ]; then
            print_error "Server address is required!"
            print_info "Use -a or --server-addr to specify the FRP server address"
            exit 1
        fi
        
        if [ -z "$DOMAIN" ]; then
            print_error "Domain is required!"
            print_info "Use -m or --domain to specify your custom domain"
            exit 1
        fi
        
        # Backup existing config
        cp "${FRP_INSTALL_DIR}/frpc.ini" "${FRP_INSTALL_DIR}/frpc.ini.backup.$(date +%s)"
        print_info "Backed up existing configuration"
        
        # Recreate configuration
        setup_client "$SERVER_ADDR" "$SERVER_PORT" "$DOMAIN" "$LOCAL_HTTP" "$LOCAL_HTTPS" "$AUTH_TOKEN"
        ;;
        
    stop-server)
        stop_server
        ;;
        
    stop-client)
        stop_client
        ;;
        
    restart-server)
        restart_server
        ;;
        
    restart-client)
        restart_client
        ;;
        
    show-config)
        # Parse optional service type argument
        SERVICE_TYPE="${2:-server}"
        
        if [ "$SERVICE_TYPE" != "server" ] && [ "$SERVICE_TYPE" != "client" ]; then
            print_error "Invalid service type: $SERVICE_TYPE"
            print_info "Usage: $0 show-config [server|client]"
            exit 1
        fi
        
        show_frp_config "$SERVICE_TYPE"
        ;;
        
    auto-setup)
        # Parse optional arguments for domain
        DOMAIN=""
        SERVER_IP=""
        CLIENT_IP=""
        
        while [[ $# -gt 0 ]]; do
            case $1 in
                -m|--domain)
                    DOMAIN="$2"
                    shift 2
                    ;;
                -i|--server-ip)
                    SERVER_IP="$2"
                    shift 2
                    ;;
                -c|--client-ip)
                    CLIENT_IP="$2"
                    shift 2
                    ;;
                *)
                    print_error "Unknown option: $1"
                    print_info "Usage: $0 auto-setup [-m DOMAIN] [-i SERVER_IP] [-c CLIENT_IP]"
                    exit 1
                    ;;
            esac
        done
        
        if [ -z "$DOMAIN" ]; then
            read -p "Enter your custom domain (e.g., example.com): " DOMAIN
            if [ -z "$DOMAIN" ]; then
                print_error "Domain is required"
                exit 1
            fi
        fi
        
        # Non-interactive version
        print_header "Auto Setup - Server + Client"
        echo
        
        # Determine server address
        REAL_SERVER_ADDR="$SERVER_IP"
        if [ -z "$REAL_SERVER_ADDR" ]; then
            REAL_SERVER_ADDR=$(hostname -I | awk '{print $1}' || echo "127.0.0.1")
        fi
        
        # Generate random values
        BIND_PORT=$(generate_random_port 7000 7999)
        DASHBOARD_PORT=$(generate_random_port 7500 8499)
        DASHBOARD_PWD=$(generate_random_string 20)
        AUTH_TOKEN=$(generate_random_string 32)
        DASHBOARD_USER="admin"
        
        print_info "Generated secure random values"
        
        # Setup server
        print_header "Setting up Server"
        setup_server "$BIND_PORT" "80" "443" "$DASHBOARD_PORT" "$DASHBOARD_USER" "$DASHBOARD_PWD" "$AUTH_TOKEN" "$SERVER_IP"
        
        sleep 2
        
        # Setup client
        print_header "Setting up Client"
        if [ -n "$CLIENT_IP" ]; then
            setup_client_remote "$CLIENT_IP" "$REAL_SERVER_ADDR" "$BIND_PORT" "$DOMAIN" "80" "443" "$AUTH_TOKEN"
        else
            setup_client "$REAL_SERVER_ADDR" "$BIND_PORT" "$DOMAIN" "80" "443" "$AUTH_TOKEN"
        fi
        
        # Save credentials
        CRED_FILE="${HOME}/frp-auto-setup-credentials-$(date +%Y%m%d-%H%M%S).txt"
        cat > "$CRED_FILE" << EOF
FRP Auto Setup Credentials
Generated: $(date)

=== Server Configuration ===
Server Address: ${REAL_SERVER_ADDR}
Bind Port: ${BIND_PORT}
Dashboard URL: http://${REAL_SERVER_ADDR}:${DASHBOARD_PORT}
Dashboard User: ${DASHBOARD_USER}
Dashboard Password: ${DASHBOARD_PWD}

=== Client Configuration ===
Server: ${REAL_SERVER_ADDR}:${BIND_PORT}
Domain: ${DOMAIN}
Auth Token: ${AUTH_TOKEN}
EOF
        chmod 600 "$CRED_FILE"
        
        echo
        print_success "Auto setup complete!"
        print_success "Credentials saved to: ${CRED_FILE}"
        ;;
        
    remove-server)
        read -p "Are you sure you want to remove FRP Server? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            remove_server
        else
            print_info "Cancelled"
        fi
        ;;
        
    remove-client)
        read -p "Are you sure you want to remove FRP Client? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            remove_client
        else
            print_info "Cancelled"
        fi
        ;;
        
    *)
        print_error "Invalid mode: $MODE"
        show_usage
        ;;
esac

print_success "Setup complete!"
