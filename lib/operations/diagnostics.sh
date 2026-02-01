#!/bin/bash

# Source required libraries
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="$(dirname "${_SCRIPT_DIR}")"
source "${_LIB_DIR}/output.sh"
source "${_LIB_DIR}/config.sh"

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
