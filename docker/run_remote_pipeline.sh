#!/bin/bash
# Usage: ./run_remote_pipeline.sh TASK_NAME TASK_FOLDER TASK_LOG_NAME \
#          LOGS_FOLDER_NAME TASK_TRAINING_CONFIG LOCAL_WORKSPACE \
#          WORKSPACE_DIR REMOTE_TARGET
#
# Parameters:
#   TASK_NAME            - Task identifier (e.g., Template-Ant-Direct-v0)
#   TASK_FOLDER          - Folder name inside isaactasks/ (e.g., ant, allegro_hand)
#   TASK_LOG_NAME        - Name for the local log directory when copying back (e.g., eval_1, run_1)
#   LOGS_FOLDER_NAME     - Path to logs folder on remote (e.g., ant/logs/rl_games/ant_direct)
#   TASK_TRAINING_CONFIG - Training config file (use "" for default)
#   LOCAL_WORKSPACE      - Local workspace path (e.g., /home/lee/code/isaactasks)
#   WORKSPACE_DIR        - Temporary directory on remote machine (e.g., ${HOME}/.temp_isaac)
#   REMOTE_TARGET        - SSH target (user@host, e.g., lee@127.0.0.1)
#
# Examples:
#   ./run_remote_pipeline.sh Template-Ant-Direct-v0 ant eval_1 \
#     logs/rl_games/ant_direct "" /home/lee/code/isaactasks \
#     ${HOME}/.temp_isaac lee@127.0.0.1
#
#   ./run_remote_pipeline.sh Template-Allegro-Hand-Direct-v0 allegro_hand run_1 \
#     logs/rl_games/allegro_hand_direct "" /home/lee/code/isaactasks \
#     ${HOME}/.temp_isaac lee@127.0.0.1

# Parse command-line arguments
if [ "$#" -ne 8 ]; then
    echo "Error: Expected 8 arguments, got $#"
    echo "Usage: $0 TASK_NAME TASK_FOLDER TASK_LOG_NAME LOGS_FOLDER_NAME TASK_TRAINING_CONFIG LOCAL_WORKSPACE WORKSPACE_DIR REMOTE_TARGET"
    echo ""
    echo "Example:"
    echo "  $0 Template-Ant-Direct-v0 ant eval_1 \\"
    echo "    ant/logs/rl_games/ant_direct \"\" /home/lee/code/isaactasks \\"
    echo "    \${HOME}/.temp_isaac lee@127.0.0.1"
    exit 1
fi

TASK_NAME="$1"                # The --task argument for your script
TASK_FOLDER="$2"              # The folder name of your task (the folder inside isaactasks/)
TASK_LOG_NAME="$3"            # Name for the local log directory when copying back
LOGS_FOLDER_NAME="$4"         # Logs folder path
TASK_TRAINING_CONFIG="$5"     # Training config (can be empty string)
LOCAL_WORKSPACE="$6"          # Local workspace path
WORKSPACE_DIR="$7"            # Path on the remote machine
REMOTE_TARGET="$8"            # Remote target (user@host)

TASK_DOCKER_NAME="isaac"


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
LOCAL_LOGS_DIR="${LOCAL_WORKSPACE}/${LOGS_FOLDER_NAME}"
echo "Copying logs from ${REMOTE_TARGET}:${WORKSPACE_DIR}/logs -> ${LOCAL_LOGS_DIR}"
mkdir -p "${LOCAL_LOGS_DIR}"
# Get the single sub-folder name from remote
echo "Remote logs subfolder: ssh "${REMOTE_TARGET}" "ls -1 ${WORKSPACE_DIR}/${LOGS_FOLDER_NAME}/ | head -n 1""
REMOTE_SUBFOLDER=$(ssh "${REMOTE_TARGET}" "ls -1 ${WORKSPACE_DIR}/${LOGS_FOLDER_NAME}/ | head -n 1") || {
    echo "Error: failed to list remote logs directory." >&2
    exit 1
}
echo "Remote logs subfolder: ${REMOTE_SUBFOLDER}"

# Copy the subfolder and rename it to TASK_LOG_NAME
scp -r -q "${REMOTE_TARGET}:${WORKSPACE_DIR}/${LOGS_FOLDER_NAME}/${REMOTE_SUBFOLDER}" "${LOCAL_LOGS_DIR}/${TASK_LOG_NAME}" || {
    echo "Error: failed to copy logs from remote host." >&2
    exit 1
}

echo "Logs successfully copied to ${LOCAL_LOGS_DIR}"

echo "Script finished."