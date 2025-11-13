#!/bin/bash

set -e

# Task configuration (passed as arguments or environment variables)
TASK_NAME="${1:-${TASK_NAME}}"

echo '--- [DOCKER] 1. Setting up tasks ---'
cd /workspace/isaac_task # Go to the mounted IsaacLab directory

echo '--- [DOCKER] 2. Running training ---'
python scripts/rl_games/train.py --task ${TASK_NAME} --headless
