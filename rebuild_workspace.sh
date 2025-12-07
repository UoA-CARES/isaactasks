#!/bin/bash
# filepath: /home/lee/code/isaactasks/rebuild_workspace.sh

# Function to check if main has unpushed commits
check_unpushed_commits() {
    git fetch origin main
    local unpushed=$(git log origin/main..main --oneline)
    if [ -n "$unpushed" ]; then
        echo "Error: Main branch has unpushed commits. Please push them first."
        echo "$unpushed"
        exit 1
    fi
}

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Switch to main and check for unpushed commits
git checkout main
check_unpushed_commits

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