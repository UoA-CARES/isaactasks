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
    nvcr.io/nvidia/isaac-lab:2.2.0 \
    -c "sleep infinity"
echo "      [DONE] New Docker container created."

# Copy the Docker script into the container
docker cp ${TMP_WORKSPACE}/run_inside_docker.sh ${DOCKER_NAME}:/workspace/run_inside_docker.sh
docker cp ${TMP_WORKSPACE}/${TASK_FOLDER} ${DOCKER_NAME}:/workspace/isaac_task
# docker cp ${TMP_WORKSPACE}/${TASK_FOLDER} ${DOCKER_NAME}:/workspace/isaac_task
echo "      [DONE] Files copied into container."

echo "--- [REMOTE] 2. Starting Docker container ---"
docker exec ${DOCKER_NAME} /bin/bash /workspace/run_inside_docker.sh \
    "${ISAACLAB_TASK_NAME}" "${TASK_FOLDER}" "${TASK_TRAINING_CONFIG}"

echo "--- [REMOTE] 3. Transferring logs files into local workspace ---"

# 4. Copying the logs back to the remote host's workspace
docker cp ${DOCKER_NAME}:/workspace/isaac_task/logs ${TMP_WORKSPACE}/logs

echo "--- [REMOTE] 4. Stopping Docker ---"
# stop docker container
docker stop ${DOCKER_NAME}

echo "--- Pipeline finished successfully! ---"
echo "Your results are on the remote host at: ${TMP_WORKSPACE}/logs"
