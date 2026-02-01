#!/bin/bash

# Source required libraries
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${LIB_DIR}/output.sh"
source "${LIB_DIR}/config.sh"
source "${LIB_DIR}/utils.sh"

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
