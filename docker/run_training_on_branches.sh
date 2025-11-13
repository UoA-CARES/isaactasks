#!/bin/bash

# Define the branches to iterate through
BRANCHES=("unit_5" "unit_4" "unit_6" "dev_activation" "dev_learning_rate" "dev_dt" "dev_mixed_precision")

# Define the repository directory
REPO_DIR="/home/lee/code/isaactasks"

# Define the working directory
WORK_DIR="/home/lee/code/isaactasks/masa_hand"

# Iterate through each branch
for BRANCH in "${BRANCHES[@]}"; do
    echo "=========================================="
    echo "Switching to branch: $BRANCH"
    echo "=========================================="
    
    # Change to repository directory for git operations
    cd "$REPO_DIR"
    
    # Switch to the branch
    git checkout "$BRANCH"
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to checkout branch $BRANCH"
        continue
    fi
    
    # Change to the working directory
    cd "$WORK_DIR"
    
    # Run the training command
    echo "Running training on branch: $BRANCH"
    python scripts/rl_games/train.py --task Template-Masa-Hand-Direct-v0 --headless
    
    # Check if training completed successfully
    if [ $? -eq 0 ]; then
        echo "Training completed successfully on branch: $BRANCH"
    else
        echo "Error: Training failed on branch: $BRANCH"
    fi
    
    echo ""
done

echo "All branches processed."