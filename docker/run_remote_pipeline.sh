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
echo "Copying task folder '$ABS_TASK_PATH' -> ${REMOTE_TARGET}:${TMP_WORKSPACE}/${TASK_FOLDER} (excluding logs and outputs)..."
rsync -avzq --exclude='logs' --exclude='outputs' -e ssh "$ABS_TASK_PATH" "${REMOTE_TARGET}:${TMP_WORKSPACE}/"

# Execute the remote script on the remote host
echo "Executing remote pipeline script..."
ssh ${REMOTE_TARGET} "bash ${TMP_WORKSPACE}/run_on_remote_host.sh \"${DOCKER_NAME}\" \"${ISAACLAB_TASK_NAME}\" \"${TASK_FOLDER}\" \"${TMP_WORKSPACE}\" \"${TASK_TRAINING_CONFIG}\""

# Copy logs back to the local machine
LOCAL_LOGS_DIR="${LOCAL_WORKSPACE}/${LOGS_FOLDER_NAME}"
echo "Copying logs from ${REMOTE_TARGET}:${TMP_WORKSPACE}/logs -> ${LOCAL_LOGS_DIR}"
mkdir -p "${LOCAL_LOGS_DIR}"

# Copy the subfolder and rename it to TASK_LOG_NAME
scp -r -q "${REMOTE_TARGET}:${TMP_WORKSPACE}/logs" "${LOCAL_LOGS_DIR}" || {
    echo "Error: failed to copy logs from remote host." >&2
    exit 1
}

echo "Logs successfully copied to ${LOCAL_LOGS_DIR}"

echo "Script finished."