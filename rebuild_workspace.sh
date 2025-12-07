#!/bin/bash
# filepath: /home/lee/code/isaactasks/rebuild_workspace.sh

# Function to check if main has unpushed commits

# Switch to main and check for unpushed commits
git checkout main

# Rebuild workspace branch
git push origin --delete workspace || true
git branch -D workspace
git fetch origin
git checkout -b workspace origin/main
python reward_func_purge.py
git add -A && git commit -m "workspace"

# Optional: Push to remote (creates remote branch if it doesn't exist)
git push -u origin workspace

# Return to main branch
git checkout main

echo "Workspace branch rebuilt successfully!"