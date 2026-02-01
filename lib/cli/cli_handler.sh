#!/bin/bash

# Source required libraries
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="$(dirname "${_SCRIPT_DIR}")"
source "${_LIB_DIR}/output.sh"
source "${_LIB_DIR}/config.sh"
source "${_LIB_DIR}/utils.sh"
source "${_LIB_DIR}/setup/server.sh"
source "${_LIB_DIR}/setup/client.sh"
source "${_LIB_DIR}/operations/service.sh"
source "${_LIB_DIR}/operations/diagnostics.sh"
source "${_LIB_DIR}/operations/auto_setup.sh"
source "${_LIB_DIR}/cli/usage.sh"

handle_cli() {
    local MODE="$1"
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
                setup_update_server_remote "$REMOTE_IP" "$BIND_PORT" "$HTTP_PORT" "$HTTPS_PORT" "$DASHBOARD_PORT" "$DASHBOARD_USER" "$DASHBOARD_PWD" "$AUTH_TOKEN"
            else
                setup_update_server_local "$BIND_PORT" "$HTTP_PORT" "$HTTPS_PORT" "$DASHBOARD_PORT" "$DASHBOARD_USER" "$DASHBOARD_PWD" "$AUTH_TOKEN"
            fi
            ;;
            
        update-client)
            # Check if client is installed
            if [ ! -f "${FRP_INSTALL_DIR}/frpc.ini" ]; then
                print_error "FRP Client configuration not found!"
                print_info "Please run 'client' setup first"
                exit 1
            fi
            
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
            
            setup_update_client_local "$SERVER_ADDR" "$SERVER_PORT" "$DOMAIN" "$LOCAL_HTTP" "$LOCAL_HTTPS" "$AUTH_TOKEN"
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
            SERVICE_TYPE="${1:-server}"
            
            if [ "$SERVICE_TYPE" != "server" ] && [ "$SERVICE_TYPE" != "client" ]; then
                print_error "Invalid service type: $SERVICE_TYPE"
                print_info "Usage: frp-setup show-config [server|client]"
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
                        print_info "Usage: frp-setup auto-setup [-m DOMAIN] [-i SERVER_IP] [-c CLIENT_IP]"
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
}
