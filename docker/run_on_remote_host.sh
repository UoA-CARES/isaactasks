#!/bin/bash

# This script runs on the remote host to:
# 1. Set up Docker environment
# 2. Pull and run Isaac Lab container
# 3. Execute training tasks
# 4. Copy results back to remote workspace

set -e # Exit on error

# --- Parse arguments ---
DOCKER_NAME="$1"
ISAACLAB_TASK_NAME="$2"
TASK_FOLDER="$3"
TMP_WORKSPACE="$4"
TASK_TRAINING_CONFIG="$5"
MODE="${6:-all}"  # Mode: "setup", "train", or "all" (default)

# --- SETUP PHASE ---
if [ "$MODE" = "setup" ] || [ "$MODE" = "all" ]; then
    echo "--- [REMOTE] 1. Setting up environments ---"

    docker pull nvcr.io/nvidia/isaac-lab:2.2.0

    # Remove existing container if it exists
    docker rm -f ${DOCKER_NAME} 2>/dev/null || true

    docker run -d --name ${DOCKER_NAME} --entrypoint bash --gpus all -e "ACCEPT_EULA=Y" --network=host \
        -e "PRIVACY_CONSENT=Y" \
        -v ~/docker/isaac-sim/cache/kit:/isaac-sim/kit/cache:rw \
        -v ~/docker/isaac-sim/cache/ov:/root/.cache/ov:rw \
        -v ~/docker/isaac-sim/cache/pip:/root/.cache/pip:rw \
        -v ~/docker/isaac-sim/cache/glcache:/root/.cache/nvidia/GLCache:rw \
        -v ~/docker/isaac-sim/cache/computecache:/root/.nv/ComputeCache:rw \
        -v ~/docker/isaac-sim/logs:/root/.nvidia-omniverse/logs:rw \
        -v ~/docker/isaac-sim/data:/root/.local/share/ov/data:rw \
        -v ~/docker/isaac-sim/documents:/root/Documents:rw \
        -v ${TMP_WORKSPACE}/${TASK_FOLDER}:/workspace/isaac_task:rw \
        nvcr.io/nvidia/isaac-lab:2.2.0 \
        -c "sleep infinity"
    echo "      [DONE] New Docker container created."

    # Copy the Docker script into the container
    docker cp ${TMP_WORKSPACE}/run_inside_docker.sh ${DOCKER_NAME}:/workspace/run_inside_docker.sh
    echo "      [DONE] Files copied into container."

    if [ "$MODE" = "setup" ]; then
        echo "--- [REMOTE] Setup complete. Container ready for training. ---"
        exit 0
    fi
fi

# --- TRAINING PHASE ---
if [ "$MODE" = "train" ] || [ "$MODE" = "all" ]; then
    echo "--- [REMOTE] 2. Starting training in Docker container ---"
    docker exec ${DOCKER_NAME} /bin/bash /workspace/run_inside_docker.sh \
        "${ISAACLAB_TASK_NAME}" "${TASK_FOLDER}" "${TASK_TRAINING_CONFIG}"

    echo "--- [REMOTE] 3. Stopping Docker ---"
    # stop docker container
    # Final sync to ensure all logs are captured
    echo "Performing final sync..."
    sleep 2
    docker stop ${DOCKER_NAME}


    echo "--- Pipeline finished successfully! ---"
    echo "Logs are being synchronized automatically to your local machine."
fi
