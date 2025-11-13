#!/bin/bash
# filepath: /home/lee/code/isaactasks/run_masa_hand_training.sh

# Array of folders to process
folders=(
    "/home/lee/code/isaactasks/tunning_masa_hand/masa_hand_1"
    "/home/lee/code/isaactasks/tunning_masa_hand/masa_hand_2"
    "/home/lee/code/isaactasks/tunning_masa_hand/masa_hand_3"
    "/home/lee/code/isaactasks/tunning_masa_hand/masa_hand_4"
)

# Iterate through each folder
for folder in "${folders[@]}"; do
    echo "=========================================="
    echo "Processing: $folder"
    echo "=========================================="
    
    # Check if folder exists
    if [ ! -d "$folder" ]; then
        echo "ERROR: Folder $folder does not exist. Skipping..."
        continue
    fi
    
    # Navigate to the folder
    cd "$folder" || { echo "ERROR: Cannot access $folder"; continue; }
    
    # Install the package
    echo "Installing masa_hand from $folder..."
    python -m pip install -e source/masa_hand
    if [ $? -ne 0 ]; then
        echo "ERROR: Installation failed for $folder"
        continue
    fi
    
    # Run the training
    echo "Starting training for $folder..."
    python scripts/rl_games/train.py --task Template-Masa-Hand-Direct-v0 --headless
    if [ $? -ne 0 ]; then
        echo "ERROR: Training failed for $folder"
        continue
    fi
    
    echo "Completed: $folder"
    echo ""
done

echo "=========================================="
echo "All tasks completed!"
echo "=========================================="