#!/bin/bash

# Source required libraries
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="$(dirname "${_SCRIPT_DIR}")"
source "${_LIB_DIR}/output.sh"
source "${_LIB_DIR}/config.sh"

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
