#!/bin/bash

# Source required libraries
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="$(dirname "${_SCRIPT_DIR}")"
source "${_LIB_DIR}/output.sh"
source "${_LIB_DIR}/config.sh"
source "${_LIB_DIR}/utils.sh"
source "${_LIB_DIR}/setup/server.sh"
source "${_LIB_DIR}/setup/client.sh"

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
