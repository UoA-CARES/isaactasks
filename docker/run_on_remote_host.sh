#!/bin/bash

# This script runs on the remote host to:
# 1. Set up Docker environment
# 2. Pull and run Isaac Lab container
# 3. Execute training tasks
# 4. Copy results back to remote workspace

set -e # Exit on error

# --- Parse arguments ---
TASK_ID_STR="$1"
TASK_NAME="$2"
TASK_FOLDER="$3"
WORKSPACE_DIR="$4"

if [ -z "$TASK_ID_STR" ] || [ -z "$TASK_NAME" ] || [ -z "$TASK_FOLDER" ] || [ -z "$WORKSPACE_DIR" ]; then
    echo "Usage: $0 <TASK_ID_STR> <TASK_NAME> <TASK_FOLDER> <WORKSPACE_DIR>"
    exit 1
fi

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
