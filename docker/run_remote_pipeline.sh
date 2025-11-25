#!/bin/bash

# TODO: logs sychonization
# --- 1. CONFIGURE YOUR SETTINGS ---
# Change it every time you run a new experiment
TASK_DOCKER_NAME="isaac"
TASK_NAME="Template-Allegro-Hand-Direct-v0" # The --task argument for your script
TASK_FOLDER="allegro_hand"          # The folder name of your task (the folder inside isaactasks/)
LOGS_FOLDER_NAME="logs/rl_games/allegro_hand_direct"
TASK_TRAINING_CONFIG=""

LOCAL_WORKSPACE="/home/lee/code/isaactasks"
# Path on the remote machine
WORKSPACE_DIR="${HOME}/.temp_isaac"

# (You MUST change these variables)
# myuser1@130.216.238.91
REMOTE_TARGET="lee@127.0.0.1"


# This is the path INSIDE the container where results are saved by train.py
# You MUST find this path. It's often inside 'logs', 'runs', or 'results'.
# Example: "logs/${TASK_NAME}/"

# --- DO NOT EDIT BELOW THIS LINE ---

set -e # Exit immediately if any command fails

echo "Connecting to ${REMOTE_TARGET}..."

echo "Creating remote workspace directory..."
ssh ${REMOTE_TARGET} "if [ -d \"${WORKSPACE_DIR}\" ]; then echo 'Removing existing ${WORKSPACE_DIR}...'; rm -rf \"${WORKSPACE_DIR}\"; fi"
ssh ${REMOTE_TARGET} "mkdir -p \"${WORKSPACE_DIR}\""

# First, copy the Docker scripts to the remote host
echo "Copying Docker scripts to remote host..."
scp -q "run_inside_docker.sh" ${REMOTE_TARGET}:${WORKSPACE_DIR}/run_inside_docker.sh
scp -q "run_on_remote_host.sh" ${REMOTE_TARGET}:${WORKSPACE_DIR}/run_on_remote_host.sh
# Ensure the local task folder exists, compute its basename, and copy it to the remote workspace
ABS_TASK_PATH="${LOCAL_WORKSPACE}/${TASK_FOLDER}"
if [ ! -d "$ABS_TASK_PATH" ]; then
    echo "Local task path not found: $ABS_TASK_PATH"
    exit 1
fi

# TASK_FOLDER="$(basename "$ABS_TASK_PATH")"
echo "Copying task folder '$ABS_TASK_PATH' -> ${REMOTE_TARGET}:${WORKSPACE_DIR}/${TASK_FOLDER} (excluding logs and outputs)..."

# Use rsync so we can exclude logs/ and outputs/ directories
rsync -avzq --exclude='logs' --exclude='outputs' -e ssh "$ABS_TASK_PATH" "${REMOTE_TARGET}:${WORKSPACE_DIR}/"

# Execute the remote script on the remote host
echo "Executing remote pipeline script..."
ssh ${REMOTE_TARGET} "bash ${WORKSPACE_DIR}/run_on_remote_host.sh \"${TASK_DOCKER_NAME}\" \"${TASK_NAME}\" \"${TASK_FOLDER}\" \"${WORKSPACE_DIR}\" \"${TASK_TRAINING_CONFIG}\""

# Copy logs back to the local machine
LOCAL_LOGS_DIR="${LOCAL_WORKSPACE}/${TASK_FOLDER}/${LOGS_FOLDER_NAME}"
echo "Copying logs from ${REMOTE_TARGET}:${WORKSPACE_DIR}/logs -> ${LOCAL_LOGS_DIR}"
mkdir -p "${LOCAL_LOGS_DIR}"
scp -r -q "${REMOTE_TARGET}:${WORKSPACE_DIR}/${LOGS_FOLDER_NAME}/*" "${LOCAL_LOGS_DIR}/" || {
    echo "Error: failed to copy logs from remote host." >&2
    exit 1
}

echo "Logs successfully copied to ${LOCAL_LOGS_DIR}"

echo "Script finished."