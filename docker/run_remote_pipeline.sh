#!/bin/bash

# --- 1. CONFIGURE YOUR SETTINGS ---

# Your specific task details
# (These are used INSIDE the container)
TASK_NAME="Template-Ant-Direct-v0" # The --task argument for your script
ABS_TASK_PATH="/home/lee/code/isaactasks/ant"


# (You MUST change these variables)
# myuser1@130.216.238.91
REMOTE_USER="myuser1"
REMOTE_HOST="130.216.239.233"

# Path on the remote machine
WORKSPACE_DIR="/home/myuser1/isaac_workspace"

# This is the path INSIDE the container where results are saved by train.py
# You MUST find this path. It's often inside 'logs', 'runs', or 'results'.
# Example: "logs/${TASK_NAME}/"

# --- DO NOT EDIT BELOW THIS LINE ---

set -e # Exit immediately if any command fails

echo "Connecting to ${REMOTE_USER}@${REMOTE_HOST}..."

echo "Creating remote workspace directory..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "mkdir -p ${WORKSPACE_DIR}"

# First, copy the Docker script to the remote host
echo "Copying Docker script to remote host..."
scp "run_inside_docker.sh" ${REMOTE_USER}@${REMOTE_HOST}:${WORKSPACE_DIR}/run_inside_docker.sh
# Ensure the local task folder exists, compute its basename, and copy it to the remote workspace
if [ ! -d "$ABS_TASK_PATH" ]; then
    echo "Local task path not found: $ABS_TASK_PATH"
    exit 1
fi

TASK_FOLDER="$(basename "$ABS_TASK_PATH")"
echo "Copying task folder '$ABS_TASK_PATH' -> ${REMOTE_USER}@${REMOTE_HOST}:${WORKSPACE_DIR}/${TASK_FOLDER} (excluding logs and outputs)..."

# Use rsync so we can exclude logs/ and outputs/ directories
rsync -avz --exclude='logs' --exclude='outputs' -e ssh "$ABS_TASK_PATH" "${REMOTE_USER}@${REMOTE_HOST}:${WORKSPACE_DIR}/"
# Send the entire block of commands to the remote machine via SSH
ssh ${REMOTE_USER}@${REMOTE_HOST} << EOF
    set -e # Exit on error *on the remote machine*

    echo "--- [REMOTE] 1. Setting up workspace ---"
    mkdir -p ${WORKSPACE_DIR}
    cd ${WORKSPACE_DIR}

    if [ ! -d "IsaacLab" ]; then
        echo "Cloning IsaacLab..."
        git clone https://github.com/UoA-CARES/IsaacLab.git
    else
        echo "IsaacLab directory already exists."
    fi

    cd IsaacLab
    echo "--- [REMOTE] 2. Starting Docker container ---"
    # The container created/managed by ./docker/container.py is named "isaac-lab-base"
    CONTAINER_NAME="isaac-lab-base"
    echo "Using container: ${CONTAINER_NAME}"
    ./docker/container.py start

    echo "--- [REMOTE] 3. Running tasks inside Docker ---"
    # Copy the Docker script into the container
    

    docker cp ${WORKSPACE_DIR}/run_inside_docker.sh isaac-lab-base:/workspace/run_inside_docker.sh
    docker cp ${WORKSPACE_DIR}/${TASK_FOLDER} isaac-lab-base:/workspace/isaac_task
    
    # Execute the script inside the container
    docker exec isaac-lab-base /bin/bash /workspace/run_inside_docker.sh \
        "${TASK_NAME}" 
    
    # 4. Copying the logs back to the remote host's workspace
    docker cp isaac-lab-base:/workspace/isaac_task/logs ${WORKSPACE_DIR}/logs

    echo "--- [REMOTE] 4. Stopping Docker ---"
    ./docker/container.py stop
    
    echo "--- Pipeline finished successfully! ---"
    echo "Your results are on the remote host at: ${WORKSPACE_DIR}/IsaacLab/training_results/${TASK_NAME}"
EOF

# # Copy logs back to the local machine
# # TODO
# LOCAL_LOGS_DIR="/home/lee/code/isaactasks/ant/logs/rl_games/ant_direct"
# echo "Copying logs from ${REMOTE_USER}@${REMOTE_HOST}:${WORKSPACE_DIR}/logs -> ${LOCAL_LOGS_DIR}"
# mkdir -p "${LOCAL_LOGS_DIR}"

# scp -r "${REMOTE_USER}@${REMOTE_HOST}:${WORKSPACE_DIR}/logs" "${LOCAL_LOGS_DIR}/" || {
#     echo "Error: failed to copy logs from remote host." >&2
#     exit 1
# }

# echo "Logs successfully copied to ${LOCAL_LOGS_DIR}"

# echo "Script finished."