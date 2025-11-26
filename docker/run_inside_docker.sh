#!/bin/bash

set -e

# Use Isaac Sim's Python wrapper
PYTHON_CMD="/workspace/isaaclab/_isaac_sim/python.sh"

# Task configuration (passed as arguments or environment variables)
TASK_NAME="${1:-${TASK_NAME}}"
TASK_FOLDER="${2:-${TASK_FOLDER}}"
TASK_TRAINING_CONFIG="""${3:-${TASK_TRAINING_CONFIG}}"

echo "Using Python: $PYTHON_CMD ($($PYTHON_CMD --version))"

echo '--- [DOCKER] 1. Setting up tasks ---'
cd /workspace/isaac_task # Go to the mounted IsaacLab directory
$PYTHON_CMD -m pip install -e source/${TASK_FOLDER} > /dev/null 2>&1

echo '--- [DOCKER] 2. Running training ---'

$PYTHON_CMD scripts/rl_games/train.py --task ${TASK_NAME} ${TASK_TRAINING_CONFIG} --headless  > /dev/null 2>&1