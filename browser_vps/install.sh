#!/usr/bin/env bash

set -e

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

KASM_VERSION="1.7.0"
KASM_INSTALL_BASE="/opt/kasm/${KASM_VERSION}"
DEFAULT_PROXY_LISTENING_PORT=443
DEFAULT_ADMIN_PASSWORD="$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13)"
DEFAULT_USER_PASSWORD="$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13)"
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd -P)"
KASM_RELEASE="$(cd "$SCRIPT_PATH" && pwd -P)"
EULA_PATH="${KASM_RELEASE}/licenses/LICENSE.txt"

# Check if port is available
function check_port() {
    echo "Checking if port ${DEFAULT_PROXY_LISTENING_PORT} is available..."
    if lsof -Pi :${DEFAULT_PROXY_LISTENING_PORT} -sTCP:LISTEN >/dev/null 2>&1; then
        echo "Error: Port ${DEFAULT_PROXY_LISTENING_PORT} is in use."
        exit 1
    else
        echo "Port ${DEFAULT_PROXY_LISTENING_PORT} is available."
    fi
}

# Update configurations for custom port
function set_listening_port() {
    echo "Configuring to use port ${DEFAULT_PROXY_LISTENING_PORT}..."
    local config_file=${KASM_INSTALL_BASE}/conf/nginx/orchestrator.conf
    if [[ -f "$config_file" ]]; then
        sed -i "s/listen 443 ssl;/listen ${DEFAULT_PROXY_LISTENING_PORT} ssl;/g" "$config_file"
    fi
}

# Generate random passwords
function generate_passwords() {
    echo "Admin Password: ${DEFAULT_ADMIN_PASSWORD}"
    echo "User Password: ${DEFAULT_USER_PASSWORD}"
}

# Install dependencies
function install_dependencies() {
    echo "Installing dependencies..."
    apt-get update && apt-get install -y docker.io openssl
}

# Create directories and setup environment
function setup_directories() {
    echo "Setting up directories..."
    mkdir -p ${KASM_INSTALL_BASE}/{bin,certs,www,conf/nginx/services.d,conf/nginx/containers.d,conf/database/seed_data}
    mkdir -p ${KASM_INSTALL_BASE}/log
    chmod 777 ${KASM_INSTALL_BASE}/log
}

# Generate self-signed SSL certificates
function generate_ssl() {
    echo "Generating self-signed SSL certificates..."
    openssl req -x509 -nodes -days 1825 -newkey rsa:2048 \
        -keyout ${KASM_INSTALL_BASE}/certs/kasm_nginx.key \
        -out ${KASM_INSTALL_BASE}/certs/kasm_nginx.crt \
        -subj "/C=US/ST=None/L=None/O=None/OU=None/CN=$(hostname)/emailAddress=none@none.none"
}

# Start services
function start_services() {
    echo "Starting Kasm services..."
    docker-compose -f ${KASM_INSTALL_BASE}/docker/docker-compose.yaml up -d
}

# Main installation process
function main() {
    check_port
    install_dependencies
    setup_directories
    generate_ssl
    set_listening_port
    generate_passwords
    start_services

    echo "Installation complete."
    echo "Admin credentials: admin@kasm.local / ${DEFAULT_ADMIN_PASSWORD}"
    echo "User credentials: user@kasm.local / ${DEFAULT_USER_PASSWORD}"
}

main
