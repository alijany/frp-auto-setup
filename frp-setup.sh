#!/bin/bash

#################################################
# FRP Auto Setup Script
# Supports both Server (frps) and Client (frpc)
# Configurable and reusable for any deployment
#################################################

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source required libraries
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/ui/interactive_mode.sh"
source "${SCRIPT_DIR}/lib/cli/cli_handler.sh"

# Main script entry point
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

# Handle CLI mode
handle_cli "$@"
