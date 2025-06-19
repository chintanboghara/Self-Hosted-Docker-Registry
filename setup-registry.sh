#!/usr/bin/env bash
set -euo pipefail

# Constants
ENV_FILE="./registry.env"
CERT_DIR="./certs"
AUTH_DIR="./auth"
DATA_DIR="./data"
HTPASSWD_FILE="$AUTH_DIR/htpasswd"
COMPOSE_FILE="docker-compose.yml"

function usage() {
    cat <<EOF
Usage: ./setup-registry.sh [--help]

This script sets up a secure, self-hosted Docker Registry using Docker Compose.
It creates TLS certificates, HTTP Basic Authentication, and required folder structure.

Make sure to edit registry.env before running.

Options:
  --help      Show this help message and exit

Environment variables (in registry.env):
  DOMAIN      - Your registry domain (e.g., registry.example.com)
  USERNAME    - Username for basic auth
  PASSWORD    - Password for basic auth
EOF
}

function load_env() {
    if [[ ! -f "$ENV_FILE" ]]; then
        echo "❌ $ENV_FILE not found. Please create it with DOMAIN, USERNAME, PASSWORD."
        exit 1
    fi
    # shellcheck disable=SC1091
    source "$ENV_FILE"
    if [[ -z "${DOMAIN:-}" || -z "${USERNAME:-}" || -z "${PASSWORD:-}" ]]; then
        echo "❌ DOMAIN, USERNAME, and PASSWORD must be set in $ENV_FILE."
        exit 1
    fi
}

function prepare_dirs() {
    mkdir -p "$CERT_DIR" "$AUTH_DIR" "$DATA_DIR"
}

function generate_cert() {
    if [[ ! -f "$CERT_DIR/fullchain.pem" || ! -f "$CERT_DIR/privkey.pem" ]]; then
        echo "🔐 Generating self-signed TLS cert for $DOMAIN"
        openssl req -newkey rsa:4096 -nodes -sha256 -keyout "$CERT_DIR/privkey.pem" \
            -x509 -days 365 -out "$CERT_DIR/fullchain.pem" -subj "/CN=$DOMAIN"
    else
        echo "✅ TLS certificate already exists"
    fi
}

function generate_auth() {
    if [[ ! -f "$HTPASSWD_FILE" ]]; then
        echo "🔑 Creating htpasswd for user $USERNAME"
        docker run --rm httpd:2.4 htpasswd -Bbn "$USERNAME" "$PASSWORD" > "$HTPASSWD_FILE"
    else
        echo "✅ htpasswd already exists"
    fi
}

function run_compose() {
    echo "🚀 Launching Docker Registry with Compose"
    docker compose -f "$COMPOSE_FILE" up -d
}

# MAIN
if [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

load_env
prepare_dirs
generate_cert
generate_auth
run_compose

echo "✅ Registry running at https://$DOMAIN"
