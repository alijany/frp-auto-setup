#!/bin/bash

# Source output functions
source "$(dirname "${BASH_SOURCE[0]}")/output.sh"

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

generate_random_string() {
    local length="${1:-16}"
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
}

generate_random_port() {
    local min="${1:-7000}"
    local max="${2:-8000}"
    echo $((min + RANDOM % (max - min)))
}
