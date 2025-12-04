#!/bin/bash
# Usage: ./run_remote_pipeline.sh <ISAACLAB_TASK_NAME> <LOCAL_WORKSPACE> <TASK_FOLDER> <LOGS_FOLDER_NAME> <TASK_TRAINING_CONFIG> <REMOTE_TARGET>
#
# Parameters:
#   ISAACLAB_TASK_NAME   - Task identifier (e.g., Template-Ant-Direct-v0)
#   LOCAL_WORKSPACE      - Local workspace path (e.g., /home/lee/code/isaactasks)
#   TASK_FOLDER          - Folder name inside isaactasks/ (e.g., ant, allegro_hand)
#   LOGS_FOLDER_NAME     - Path to logs folder on local machine (e.g., training_logs/iter_1/run_1)
#   TASK_TRAINING_CONFIG - Training config file (use "" for default)
#   REMOTE_TARGET        - SSH target (user@host, e.g., lee@127.0.0.1)

# The following two are fixed:
#   TMP_WORKSPACE        - Temporary directory on remote machine (e.g., ${HOME}/.temp_isaac)
#   TASK_LOG_NAME        - Name for the copied log directory (e.g., eval_1, run_1)
#
# Examples:
#   ./run_remote_pipeline.sh Template-Ant-Direct-v0 /home/lee/code/isaactasks ant training_logs/test "" lee@127.0.0.1 
#
#   ./run_remote_pipeline.sh Template-Allegro-Hand-Direct-v0 /home/lee/code/isaactasks allegro_hand training_logs/test "" lee@127.0.0.1 

# Parse command-line arguments
if [ "$#" -ne 6 ]; then
    echo "Error: Expected 6 arguments, got $#"
    echo "Usage: $0 <ISAACLAB_TASK_NAME> <LOCAL_WORKSPACE> <TASK_FOLDER> <LOGS_FOLDER_NAME> <TASK_TRAINING_CONFIG> <REMOTE_TARGET>"
    exit 1
fi


ISAACLAB_TASK_NAME="$1"       # The --task argument for your script
LOCAL_WORKSPACE="$2"          # Local workspace path
TASK_FOLDER="$3"              # The folder name of your task (the folder inside isaactasks/)
LOGS_FOLDER_NAME="$4"         # Path to logs folder on local machine (e.g., training_logs/iter_1/run_1)
TASK_TRAINING_CONFIG="$5"     # Training config (can be empty string)
REMOTE_TARGET="$6"            # Remote target (user@host)

# Fixed parameters
TMP_REMOTE_ROOT="${HOME}/.temp_isaac"
TMP_TASK_ID="$(date +%Y%m%d_%H%M%S)_$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)"
DOCKER_NAME=$TMP_TASK_ID

TMP_WORKSPACE="${TMP_REMOTE_ROOT}/${TMP_TASK_ID}"
# --- DO NOT EDIT BELOW THIS LINE ---

set -e # Exit immediately if any command fails

echo "Connecting to ${REMOTE_TARGET}..."

echo "Creating remote workspace directory..."
ssh ${REMOTE_TARGET} "if [ -d \"${TMP_WORKSPACE}\" ]; then echo 'Removing existing ${TMP_WORKSPACE}...'; rm -rf \"${TMP_WORKSPACE}\"; fi"
ssh ${REMOTE_TARGET} "mkdir -p \"${TMP_WORKSPACE}\""

# First, copy the Docker scripts to the remote host
echo "Copying Docker scripts to remote host..."
scp -q "run_inside_docker.sh" ${REMOTE_TARGET}:${TMP_WORKSPACE}/run_inside_docker.sh
scp -q "run_on_remote_host.sh" ${REMOTE_TARGET}:${TMP_WORKSPACE}/run_on_remote_host.sh
# Ensure the local task folder exists, compute its basename, and copy it to the remote workspace
ABS_TASK_PATH="${LOCAL_WORKSPACE}/${TASK_FOLDER}"
if [ ! -d "$ABS_TASK_PATH" ]; then
    echo "Local task path not found: $ABS_TASK_PATH"
    exit 1
fi

# TASK_FOLDER="$(basename "$ABS_TASK_PATH")"
# Use rsync so we can exclude logs/ and outputs/ directories
echo "Copying task folder '$ABS_TASK_PATH' -> ${REMOTE_TARGET}:${TMP_WORKSPACE}/${TASK_FOLDER} (excluding outputs and re-new logs)..."
rsync -avzq --exclude='logs' --exclude='outputs' -e ssh "$ABS_TASK_PATH" "${REMOTE_TARGET}:${TMP_WORKSPACE}/"
ssh ${REMOTE_TARGET} "mkdir -p \"${TMP_WORKSPACE}/${TASK_FOLDER}/logs\""

# === PHASE 1: Setup Docker Container ===
echo "=== Phase 1: Setting up Docker container on remote host ==="
ssh ${REMOTE_TARGET} "bash ${TMP_WORKSPACE}/run_on_remote_host.sh \"${DOCKER_NAME}\" \"${ISAACLAB_TASK_NAME}\" \"${TASK_FOLDER}\" \"${TMP_WORKSPACE}\" \"${TASK_TRAINING_CONFIG}\" \"setup\""
echo "Container setup complete!"

# === PHASE 2: Start Log Sync ===
echo ""
echo "=== Phase 2: Mounting remote logs via sshfs ==="

# Check if sshfs is installed
if ! command -v sshfs &> /dev/null; then
    echo "Error: sshfs is not installed. Please install it:"
    echo "  Ubuntu/Debian: sudo apt-get install sshfs"
    echo "  Fedora/RHEL: sudo dnf install fuse-sshfs"
    echo "  macOS: brew install macfuse && brew install gromgit/fuse/sshfs-mac"
    exit 1
fi

# Define local logs directory
LOCAL_LOGS_DIR="${ABS_TASK_PATH}/${LOGS_FOLDER_NAME}"
mkdir -p "${LOCAL_LOGS_DIR}"

# Remote logs directory
REMOTE_LOGS_DIR="${TMP_WORKSPACE}/${TASK_FOLDER}/logs"

echo "Mounting ${REMOTE_TARGET}:${REMOTE_LOGS_DIR} to ${LOCAL_LOGS_DIR}"

# Mount remote logs directory using sshfs for real-time access
# Options:
#   -o reconnect: automatically reconnect on connection loss
#   -o ServerAliveInterval=15: keep connection alive
#   -o ServerAliveCountMax=3: retry connection
#   -o follow_symlinks: follow symlinks on remote
sshfs "${REMOTE_TARGET}:${REMOTE_LOGS_DIR}" "${LOCAL_LOGS_DIR}" \
    -o reconnect \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=3 \
    -o follow_symlinks

if [ $? -eq 0 ]; then
    echo "Remote logs mounted successfully! TensorBoard can now access logs in real-time."
else
    echo "Error: Failed to mount remote logs directory"
    exit 1
fi

# Setup cleanup trap to unmount on script exit
cleanup() {
    echo ""
    echo "Unmounting remote logs directory..."
    fusermount -u "${LOCAL_LOGS_DIR}" 2>/dev/null || umount "${LOCAL_LOGS_DIR}" 2>/dev/null || true
    echo "Cleanup complete."
}
trap cleanup EXIT INT TERM

# === PHASE 3: Execute Training ===
echo ""
echo "=== Phase 3: Starting training (logs accessible in real-time via sshfs) ==="
ssh ${REMOTE_TARGET} "bash ${TMP_WORKSPACE}/run_on_remote_host.sh \"${DOCKER_NAME}\" \"${ISAACLAB_TASK_NAME}\" \"${TASK_FOLDER}\" \"${TMP_WORKSPACE}\" \"${TASK_TRAINING_CONFIG}\" \"train\""

echo ""
echo "Training complete! Logs are available at ${LOCAL_LOGS_DIR}"

echo "Script finished."