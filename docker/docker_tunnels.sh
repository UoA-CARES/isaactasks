#!/bin/bash

# Bidirectional sync tunnel between local folder and remote Docker container
# Architecture: Local folder <--> Remote temp folder <--> Docker container folder
#
# Usage: ./docker_tunnels.sh <local_folder> <docker_folder> <container_name> <remote_user> <remote_ip>
#
# Requirements:
#   - Local: rsync, inotify-tools (inotifywait)
#   - Remote: rsync, docker access

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
if [ "$#" -ne 5 ]; then
    log_error "Usage: $0 <local_folder> <docker_folder> <container_name> <remote_user> <remote_ip>"
    exit 1
fi

LOCAL_FOLDER="${1%/}"  # Remove trailing slash
DOCKER_FOLDER="${2%/}"
CONTAINER_NAME="$3"
REMOTE_USER="$4"
REMOTE_IP="$5"
REMOTE_HOST="${REMOTE_USER}@${REMOTE_IP}"

# Global variables
REMOTE_TEMP_FOLDER=""
LOCAL_TO_REMOTE_PID=""
REMOTE_TO_LOCAL_PID=""
REMOTE_TO_DOCKER_PID=""
DOCKER_TO_REMOTE_PID=""
CLEANUP_DONE=false

# Validate local folder exists
validate_local_folder() {
    if [ ! -d "$LOCAL_FOLDER" ]; then
        log_error "Local folder does not exist: $LOCAL_FOLDER"
        exit 1
    fi
    log_info "Local folder validated: $LOCAL_FOLDER"
}

# Check required local tools
check_local_dependencies() {
    local missing_deps=()

    if ! command -v rsync &> /dev/null; then
        missing_deps+=("rsync")
    fi

    if ! command -v inotifywait &> /dev/null; then
        missing_deps+=("inotify-tools")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_warn "Missing dependencies: ${missing_deps[*]}"
        log_info "Attempting to install missing dependencies..."

        # Try to install missing dependencies
        if command -v apt-get &> /dev/null; then
            log_info "Using apt-get to install packages..."
            if sudo apt-get update -qq && sudo apt-get install -y "${missing_deps[@]}"; then
                log_info "Successfully installed dependencies"
            else
                log_error "Failed to install dependencies automatically"
                log_error "Please run: sudo apt-get install ${missing_deps[*]}"
                exit 1
            fi
        elif command -v yum &> /dev/null; then
            log_info "Using yum to install packages..."
            if sudo yum install -y "${missing_deps[@]}"; then
                log_info "Successfully installed dependencies"
            else
                log_error "Failed to install dependencies automatically"
                log_error "Please run: sudo yum install ${missing_deps[*]}"
                exit 1
            fi
        elif command -v dnf &> /dev/null; then
            log_info "Using dnf to install packages..."
            if sudo dnf install -y "${missing_deps[@]}"; then
                log_info "Successfully installed dependencies"
            else
                log_error "Failed to install dependencies automatically"
                log_error "Please run: sudo dnf install ${missing_deps[*]}"
                exit 1
            fi
        else
            log_error "Cannot detect package manager (apt/yum/dnf)"
            log_error "Please install manually: ${missing_deps[*]}"
            exit 1
        fi

        # Verify installation succeeded
        if ! command -v inotifywait &> /dev/null; then
            log_error "inotify-tools installation failed or inotifywait not in PATH"
            exit 1
        fi

        if ! command -v rsync &> /dev/null; then
            log_error "rsync installation failed or not in PATH"
            exit 1
        fi
    fi

    log_info "Local dependencies validated"
}

# Test SSH connection
test_ssh_connection() {
    log_info "Testing SSH connection to $REMOTE_HOST..."

    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$REMOTE_HOST" "exit" 2>/dev/null; then
        log_error "Cannot connect to $REMOTE_HOST"
        log_error "Please ensure SSH key authentication is set up"
        exit 1
    fi

    log_info "SSH connection successful"
}

# Check remote dependencies
check_remote_dependencies() {
    log_info "Checking remote dependencies..."

    if ! ssh "$REMOTE_HOST" "command -v rsync" &> /dev/null; then
        log_error "rsync is not installed on remote host"
        exit 1
    fi

    if ! ssh "$REMOTE_HOST" "command -v docker" &> /dev/null; then
        log_error "docker is not installed on remote host"
        exit 1
    fi

    log_info "Remote dependencies validated"
}

# Check if Docker container is running
check_docker_container() {
    log_info "Checking if container '$CONTAINER_NAME' is running..."

    if ! ssh "$REMOTE_HOST" "docker ps --format '{{.Names}}' | grep -q '^${CONTAINER_NAME}$'" 2>/dev/null; then
        log_error "Container '$CONTAINER_NAME' is not running on remote host"
        exit 1
    fi

    log_info "Container '$CONTAINER_NAME' is running"
}

# Create temp folder on remote machine
create_remote_temp_folder() {
    log_info "Creating temporary folder on remote host..."

    REMOTE_TEMP_FOLDER=$(ssh "$REMOTE_HOST" "mktemp -d -t docker_sync_XXXXXX")

    if [ -z "$REMOTE_TEMP_FOLDER" ]; then
        log_error "Failed to create temp folder on remote host"
        exit 1
    fi

    log_info "Created temp folder: $REMOTE_TEMP_FOLDER"
}

# Cleanup function
cleanup() {
    if [ "$CLEANUP_DONE" = true ]; then
        return
    fi
    CLEANUP_DONE=true

    log_info "Cleaning up..."

    # Kill background sync processes
    if [ -n "$LOCAL_TO_REMOTE_PID" ]; then
        kill "$LOCAL_TO_REMOTE_PID" 2>/dev/null || true
    fi
    if [ -n "$REMOTE_TO_LOCAL_PID" ]; then
        kill "$REMOTE_TO_LOCAL_PID" 2>/dev/null || true
    fi
    if [ -n "$REMOTE_TO_DOCKER_PID" ]; then
        kill "$REMOTE_TO_DOCKER_PID" 2>/dev/null || true
    fi
    if [ -n "$DOCKER_TO_REMOTE_PID" ]; then
        kill "$DOCKER_TO_REMOTE_PID" 2>/dev/null || true
    fi

    # Remove temp folder on remote
    if [ -n "$REMOTE_TEMP_FOLDER" ]; then
        log_info "Removing temp folder: $REMOTE_TEMP_FOLDER"
        ssh "$REMOTE_HOST" "rm -rf '$REMOTE_TEMP_FOLDER'" 2>/dev/null || true
    fi

    log_info "Cleanup complete"
}

# Set up trap for cleanup
trap cleanup EXIT INT TERM

# Initial sync: Local -> Remote temp -> Docker
initial_sync_to_docker() {
    log_info "Performing initial sync: Local -> Remote -> Docker..."

    # Sync local to remote temp
    rsync -az --delete \
        -e "ssh" \
        "$LOCAL_FOLDER/" \
        "$REMOTE_HOST:$REMOTE_TEMP_FOLDER/" || {
        log_error "Failed to sync local to remote"
        exit 1
    }

    # Sync remote temp to docker
    ssh "$REMOTE_HOST" "docker cp '$REMOTE_TEMP_FOLDER/.' '$CONTAINER_NAME:$DOCKER_FOLDER/'" || {
        log_error "Failed to sync remote to docker"
        exit 1
    }

    log_info "Initial sync complete"
}

# Initial sync: Docker -> Remote temp -> Local
initial_sync_from_docker() {
    log_info "Performing initial sync: Docker -> Remote -> Local..."

    # Sync docker to remote temp (create a separate folder to avoid conflicts)
    ssh "$REMOTE_HOST" "docker cp '$CONTAINER_NAME:$DOCKER_FOLDER/.' '$REMOTE_TEMP_FOLDER/'" || {
        log_warn "Failed to sync docker to remote (folder might be empty)"
    }

    # Sync remote temp to local
    rsync -az \
        -e "ssh" \
        "$REMOTE_HOST:$REMOTE_TEMP_FOLDER/" \
        "$LOCAL_FOLDER/" || {
        log_warn "Failed to sync remote to local"
    }

    log_info "Initial sync from docker complete"
}

# Watch local folder and sync to remote/docker
watch_local_to_remote() {
    log_info "Starting local -> remote -> docker sync watcher..."

    while true; do
        inotifywait -r -e modify,create,delete,move \
            --exclude '\.git|\.swp|~$' \
            "$LOCAL_FOLDER" 2>/dev/null || {
            sleep 1
            continue
        }

        # Sync local to remote
        rsync -az --delete \
            -e "ssh" \
            "$LOCAL_FOLDER/" \
            "$REMOTE_HOST:$REMOTE_TEMP_FOLDER/" 2>/dev/null || {
            log_warn "Rsync failed during local->remote sync"
            continue
        }

        # Sync remote to docker
        ssh "$REMOTE_HOST" "docker cp '$REMOTE_TEMP_FOLDER/.' '$CONTAINER_NAME:$DOCKER_FOLDER/'" 2>/dev/null || {
            log_warn "Docker cp failed during remote->docker sync"
        }

        log_info "Synced local changes to docker"
    done
}

# Watch docker folder and sync to remote/local
watch_docker_to_local() {
    log_info "Starting docker -> remote -> local sync watcher..."

    while true; do
        sleep 2  # Poll every 2 seconds (docker doesn't support inotify easily)

        # Sync docker to remote temp
        ssh "$REMOTE_HOST" "docker cp '$CONTAINER_NAME:$DOCKER_FOLDER/.' '$REMOTE_TEMP_FOLDER/'" 2>/dev/null || {
            log_warn "Docker cp failed during docker->remote sync"
            sleep 5
            continue
        }

        # Sync remote to local
        rsync -az \
            -e "ssh" \
            "$REMOTE_HOST:$REMOTE_TEMP_FOLDER/" \
            "$LOCAL_FOLDER/" 2>/dev/null || {
            log_warn "Rsync failed during remote->local sync"
            sleep 5
            continue
        }
    done
}

# Main function
main() {
    log_info "Starting Docker sync tunnel..."
    log_info "Local: $LOCAL_FOLDER"
    log_info "Remote: $REMOTE_HOST"
    log_info "Container: $CONTAINER_NAME:$DOCKER_FOLDER"

    # Validation steps
    validate_local_folder
    check_local_dependencies
    test_ssh_connection
    check_remote_dependencies
    check_docker_container
    create_remote_temp_folder

    # Initial bidirectional sync
    initial_sync_to_docker
    initial_sync_from_docker

    # Start background watchers
    watch_local_to_remote &
    LOCAL_TO_REMOTE_PID=$!

    watch_docker_to_local &
    REMOTE_TO_LOCAL_PID=$!

    log_info "Sync tunnel active. Press Ctrl+C to stop."
    log_info "Watching for changes..."

    # Wait for background processes
    wait
}

# Run main function
main