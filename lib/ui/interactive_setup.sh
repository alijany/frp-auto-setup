#!/bin/bash

# Source required libraries
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="$(dirname "${_SCRIPT_DIR}")"
source "${_LIB_DIR}/output.sh"
source "${_LIB_DIR}/config.sh"
source "${_LIB_DIR}/utils.sh"
source "${_LIB_DIR}/setup/server.sh"
source "${_LIB_DIR}/setup/client.sh"

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
