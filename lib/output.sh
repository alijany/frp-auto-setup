#!/bin/bash

# Source colors
source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# Output functions
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
