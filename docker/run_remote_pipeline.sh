#!/bin/bash

# --- 1. CONFIGURE YOUR SETTINGS ---
TASK_ID_STR="isaac"

# Your specific task details
# (These are used INSIDE the container)
TASK_NAME="Template-Ant-Direct-v0" # The --task argument for your script
ABS_TASK_PATH="/home/lee/code/isaactasks/ant"
# TODO
LOCAL_LOGS_DIR="/home/lee/code/isaactasks/ant/logs/rl_games/ant_direct"


# (You MUST change these variables)
# myuser1@130.216.238.91
REMOTE_USER="lee"
REMOTE_HOST="127.0.0.1"

# Path on the remote machine
WORKSPACE_DIR="${HOME}/.temp_isaac"

# This is the path INSIDE the container where results are saved by train.py
# You MUST find this path. It's often inside 'logs', 'runs', or 'results'.
# Example: "logs/${TASK_NAME}/"

# --- DO NOT EDIT BELOW THIS LINE ---

set -e # Exit immediately if any command fails

echo "Connecting to ${REMOTE_USER}@${REMOTE_HOST}..."

echo "Creating remote workspace directory..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "if [ -d \"${WORKSPACE_DIR}\" ]; then echo 'Removing existing ${WORKSPACE_DIR}...'; rm -rf \"${WORKSPACE_DIR}\"; fi"
ssh ${REMOTE_USER}@${REMOTE_HOST} "mkdir -p \"${WORKSPACE_DIR}\""

# First, copy the Docker scripts to the remote host
echo "Copying Docker scripts to remote host..."
scp -q "run_inside_docker.sh" ${REMOTE_USER}@${REMOTE_HOST}:${WORKSPACE_DIR}/run_inside_docker.sh
scp -q "run_on_remote_host.sh" ${REMOTE_USER}@${REMOTE_HOST}:${WORKSPACE_DIR}/run_on_remote_host.sh
# Ensure the local task folder exists, compute its basename, and copy it to the remote workspace
if [ ! -d "$ABS_TASK_PATH" ]; then
    echo "Local task path not found: $ABS_TASK_PATH"
    exit 1
fi

TASK_FOLDER="$(basename "$ABS_TASK_PATH")"
echo "Copying task folder '$ABS_TASK_PATH' -> ${REMOTE_USER}@${REMOTE_HOST}:${WORKSPACE_DIR}/${TASK_FOLDER} (excluding logs and outputs)..."

# Use rsync so we can exclude logs/ and outputs/ directories
rsync -avz --exclude='logs' --exclude='outputs' -e ssh "$ABS_TASK_PATH" "${REMOTE_USER}@${REMOTE_HOST}:${WORKSPACE_DIR}/"

# Execute the remote script on the remote host
echo "Executing remote pipeline script..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "bash ${WORKSPACE_DIR}/run_on_remote_host.sh \"${TASK_ID_STR}\" \"${TASK_NAME}\" \"${TASK_FOLDER}\" \"${WORKSPACE_DIR}\""

# Copy logs back to the local machine
echo "Copying logs from ${REMOTE_USER}@${REMOTE_HOST}:${WORKSPACE_DIR}/logs -> ${LOCAL_LOGS_DIR}"
mkdir -p "${LOCAL_LOGS_DIR}"
scp -r -q "${REMOTE_USER}@${REMOTE_HOST}:${WORKSPACE_DIR}/logs" "${LOCAL_LOGS_DIR}/" || {
    echo "Error: failed to copy logs from remote host." >&2
    exit 1
}

echo "Logs successfully copied to ${LOCAL_LOGS_DIR}"

echo "Script finished."