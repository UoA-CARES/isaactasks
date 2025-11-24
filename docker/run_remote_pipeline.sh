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

    echo "--- [REMOTE] 1. Setting up environments ---"
    mkdir -p ${WORKSPACE_DIR}
    cd ${WORKSPACE_DIR}
    echo "      [DONE] Files copied into remote workspace."

    docker pull nvcr.io/nvidia/isaac-lab:2.2.0

    # Remove existing container if it exists
    docker rm -f ${TASK_ID_STR} 2>/dev/null || true

    docker run -d --name ${TASK_ID_STR} --entrypoint bash --gpus all -e "ACCEPT_EULA=Y" --network=host \
        -e "PRIVACY_CONSENT=Y" \
        -v ~/docker/isaac-sim/cache/kit:/isaac-sim/kit/cache:rw \
        -v ~/docker/isaac-sim/cache/ov:/root/.cache/ov:rw \
        -v ~/docker/isaac-sim/cache/pip:/root/.cache/pip:rw \
        -v ~/docker/isaac-sim/cache/glcache:/root/.cache/nvidia/GLCache:rw \
        -v ~/docker/isaac-sim/cache/computecache:/root/.nv/ComputeCache:rw \
        -v ~/docker/isaac-sim/logs:/root/.nvidia-omniverse/logs:rw \
        -v ~/docker/isaac-sim/data:/root/.local/share/ov/data:rw \
        -v ~/docker/isaac-sim/documents:/root/Documents:rw \
        nvcr.io/nvidia/isaac-lab:2.2.0 \
        -c "sleep infinity"
    echo "      [DONE] New Docker container created."

    # Copy the Docker script into the container
    docker cp ${WORKSPACE_DIR}/run_inside_docker.sh ${TASK_ID_STR}:/workspace/run_inside_docker.sh
    docker cp ${WORKSPACE_DIR}/${TASK_FOLDER} ${TASK_ID_STR}:/workspace/isaac_task
    docker cp ${WORKSPACE_DIR}/${TASK_FOLDER} ${TASK_ID_STR}:/workspace/isaac_task
    echo "      [DONE] Files copied into container."
    
    echo "--- [REMOTE] 2. Starting Docker container ---"
    docker exec ${TASK_ID_STR} /bin/bash /workspace/run_inside_docker.sh \
        "${TASK_NAME}" "${TASK_FOLDER}"

    echo "--- [REMOTE] 3. Transferring logs files into local workspace ---"
    
    # 4. Copying the logs back to the remote host's workspace
    docker cp ${TASK_ID_STR}:/workspace/isaac_task/logs ${WORKSPACE_DIR}/logs
    
    echo "--- [REMOTE] 4. Stopping Docker ---"
    # delete docker container
    docker rm -f ${TASK_ID_STR} 2>/dev/null || true
    
    echo "--- Pipeline finished successfully! ---"
    echo "Your results are on the remote host at: ${WORKSPACE_DIR}/IsaacLab/training_results/${TASK_NAME}"
EOF

# Copy logs back to the local machine
echo "Copying logs from ${REMOTE_USER}@${REMOTE_HOST}:${WORKSPACE_DIR}/logs -> ${LOCAL_LOGS_DIR}"
mkdir -p "${LOCAL_LOGS_DIR}"
scp -r -q "${REMOTE_USER}@${REMOTE_HOST}:${WORKSPACE_DIR}/logs" "${LOCAL_LOGS_DIR}/" || {
    echo "Error: failed to copy logs from remote host." >&2
    exit 1
}

echo "Logs successfully copied to ${LOCAL_LOGS_DIR}"

echo "Script finished."