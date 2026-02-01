#!/bin/bash

# Source required libraries
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="$(dirname "${_SCRIPT_DIR}")"
source "${_LIB_DIR}/output.sh"
source "${_LIB_DIR}/config.sh"
source "${_LIB_DIR}/utils.sh"
source "${_LIB_DIR}/ui/menu.sh"
source "${_LIB_DIR}/ui/interactive_setup.sh"
source "${_LIB_DIR}/operations/service.sh"
source "${_LIB_DIR}/operations/diagnostics.sh"
source "${_LIB_DIR}/operations/auto_setup.sh"

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
