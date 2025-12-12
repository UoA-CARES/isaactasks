#!/bin/bash
# Usage: ./clear_remote.sh <REMOTE_TARGET>
#
# Parameters:
#   REMOTE_TARGET - SSH target (user@host, e.g., myuser1@130.216.239.143)
#
# This script will:
#   1. Stop all Docker containers on the remote machine
#   2. Remove the temporary Isaac workspace folder at ${REMOTE_HOME}/.temp_isaac
#
# Examples:
#   ./clear_remote.sh myuser1@130.216.239.143
#   ./clear_remote.sh lee@127.0.0.1

# Parse command-line arguments
if [ "$#" -ne 1 ]; then
    echo "Error: Expected 1 argument, got $#"
    echo "Usage: $0 <REMOTE_TARGET>"
    echo "Example: $0 myuser1@130.216.239.143"
    exit 1
fi

REMOTE_TARGET="$1"

set -e # Exit immediately if any command fails

echo "Connecting to ${REMOTE_TARGET}..."

# Get the actual remote home directory
REMOTE_HOME=$(ssh ${REMOTE_TARGET} 'echo $HOME')
TMP_REMOTE_ROOT="${REMOTE_HOME}/.temp_isaac"

echo "Remote home directory: ${REMOTE_HOME}"
echo "Temporary workspace: ${TMP_REMOTE_ROOT}"
echo ""

# Stop all Docker containers on the remote machine
echo "Stopping all Docker containers on remote machine..."
ssh ${REMOTE_TARGET} 'docker stop $(docker ps -aq) 2>/dev/null || echo "No running containers to stop"'

echo "Docker containers stopped."
echo ""

# Remove task-specific containers and folders
echo "Removing task-specific containers and folders..."
ssh ${REMOTE_TARGET} "bash -s" << 'ENDSSH'
TMP_REMOTE_ROOT="${HOME}/.temp_isaac"

if [ -d "${TMP_REMOTE_ROOT}" ]; then
    # Iterate through each subfolder in TMP_REMOTE_ROOT
    for task_folder in "${TMP_REMOTE_ROOT}"/*; do
        if [ -d "${task_folder}" ]; then
            task_id=$(basename "${task_folder}")
            echo "Processing task: ${task_id}"

            # Stop and remove the Docker container with the same name
            if docker ps -a --format '{{.Names}}' | grep -q "^${task_id}$"; then
                echo "  - Stopping and removing container: ${task_id}"
                docker stop "${task_id}" 2>/dev/null || true
                docker rm "${task_id}" 2>/dev/null || true
            else
                echo "  - No container found with name: ${task_id}"
            fi

            # Remove the task folder using Docker (to handle root-owned files)
            echo "  - Removing folder: ${task_folder}"
            docker run --rm -v "${TMP_REMOTE_ROOT}:/tmp/cleanup" alpine rm -rf "/tmp/cleanup/${task_id}"
        fi
    done
    echo "All task containers and folders removed."
else
    echo "Temporary workspace folder does not exist: ${TMP_REMOTE_ROOT}"
fi
ENDSSH

echo ""
echo "Cleanup complete!"
