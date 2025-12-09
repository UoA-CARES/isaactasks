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

# Remove the temporary Isaac workspace folder
echo "Removing temporary workspace folder: ${TMP_REMOTE_ROOT}..."
ssh ${REMOTE_TARGET} "if [ -d \"${TMP_REMOTE_ROOT}\" ]; then rm -rf \"${TMP_REMOTE_ROOT}\" && echo 'Folder removed successfully'; else echo 'Folder does not exist, nothing to remove'; fi"

echo ""
echo "Cleanup complete!"
