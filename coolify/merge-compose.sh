#!/bin/bash

###############################################################################
# merge-compose.sh
#
# Description:
#   Merges multiple docker-compose YAML files into a single docker-compose.prod.yml
#   file using yq (Mike Farah v4+). Checks for required dependencies and downloads
#   yq if missing. Ensures all input compose files exist before merging.
#
# Usage:
#   ./merge-compose.sh
#
# Requirements:
#   - yq (Mike Farah v4+) and curl (auto-installs yq if missing)
#   - All listed compose files must exist in the working directory
#
# Output:
#   - docker-compose.prod.yml (merged result)
###############################################################################

COMPOSE_FILES=("docker-compose.yml" "docker-compose.s3.yml" "coolify/docker-compose.coolify.yml")
MERGED_COMPOSE="docker-compose.prod.yml"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Messaging functions
print_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
print_fail()  { echo -e "${RED}[FAIL]${NC} $1"; }
print_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_info()  { echo -e "${YELLOW}[INFO]${NC} $1"; }

# Check if a command exists
check_command() {
    command -v "$1" &> /dev/null
}

# Check all dependencies
check_dependencies() {
    local deps=("yq" "curl")
    local missing=0
    for dep in "${deps[@]}"; do
        if ! check_command "$dep"; then
            print_warn "Dependency missing: $dep"
            missing=1
        else
            print_ok "Dependency found: $dep"
        fi
    done
    if [ "$missing" -eq 1 ]; then
        print_fail "Missing dependencies. Please install them and rerun the script."
        exit 1
    fi
}

# Install yq if missing
install_yq() {
    if ! check_command yq; then
        print_info "Installing yq (Go version, Mike Farah)..."
        YQ_BIN="/usr/local/bin/yq"
        if [ ! -w "$(dirname "$YQ_BIN")" ]; then
            print_fail "No write permission to $(dirname "$YQ_BIN"). Run with sudo or install yq manually: https://github.com/mikefarah/yq"
            exit 1
        fi
        curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o "$YQ_BIN"
        chmod +x "$YQ_BIN"
        if ! check_command yq; then
            print_fail "Failed to install yq. Please install manually: https://github.com/mikefarah/yq"
            exit 1
        fi
        print_ok "yq installed successfully."
    else
        print_ok "yq already installed."
    fi
    yq --version
    if ! yq --version 2>&1 | grep -Eqi 'version v?4'; then
        print_fail "yq installed is not v4.x (Mike Farah). Remove other yq from PATH and try again."
        exit 1
    fi
}

# Check existence of compose files
check_compose_files() {
    local missing=0
    for f in "${COMPOSE_FILES[@]}"; do
        if [ ! -f "$f" ]; then
            print_fail "Compose file not found: $f"
            missing=1
        else
            print_ok "Compose file found: $f"
        fi
    done
    if [ "$missing" -eq 1 ]; then
        print_fail "One or more compose files are missing. Aborting."
        exit 1
    fi
}

# Merge compose files
merge_compose_files() {
    print_info "Merging docker-compose files..."
    if [ "${#COMPOSE_FILES[@]}" -eq 3 ]; then
        # Use multiplication operator for 3 files
        yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1) * select(fileIndex == 2)' "${COMPOSE_FILES[@]}" > "${MERGED_COMPOSE}"
    else
        # Generic fallback for N files
        yq eval-all 'reduce .[] as $item ({}; . * $item)' "${COMPOSE_FILES[@]}" > "${MERGED_COMPOSE}"
    fi
    if [ $? -eq 0 ]; then
        print_ok "Merge completed successfully! Output: ${MERGED_COMPOSE}"
    else
        print_fail "Failed to merge docker-compose files. Check if all files are valid YAML and yq version is >= v4.25."
        exit 1
    fi
}

# Early check for compose files existence
for f in "${COMPOSE_FILES[@]}"; do
    if [ ! -f "$f" ]; then
        print_fail "Compose file not found: $f"
        exit 1
    fi
done

# Main execution flow
main() {
    check_dependencies
    install_yq
    check_compose_files
    merge_compose_files
}

main