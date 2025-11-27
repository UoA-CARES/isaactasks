#!/usr/bin/env python3

"""
This script purges the content of compute_rewards functions in Python files.
It keeps only the function signature and return statement, removing the body.
"""

import os
import re
import sys
import shutil
from pathlib import Path


def find_python_files(root_dir="."):
    """Find all Python files in the directory tree."""
    root = Path(root_dir)
    return list(root.rglob("*.py"))


def purge_compute_rewards(file_path):
    """
    Remove the body of compute_rewards function, keeping only signature and return.
    Returns True if modifications were made, False otherwise.
    """
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Check if file contains compute_rewards function
    if 'def compute_rewards' not in content:
        return False

    # Pattern to match the function definition with optional decorator
    # This captures multi-line function signatures and the entire body
    pattern = r'(@torch\.jit\.script\s*\n)?(def compute_rewards\([^)]*(?:\n[^)]*)*\)(?:\s*->\s*[^:]+)?:)(.*?)(return\s+[^\n]+)'

    def process_function(match):
        decorator = match.group(1) if match.group(1) else ''
        signature = match.group(2)
        body = match.group(3)
        return_stmt = match.group(4)

        # Reconstruct with minimal body
        # Add pass statement for valid Python syntax
        return decorator + signature + '\n    \n    ' + return_stmt

    # Use DOTALL flag to match across newlines
    new_content = re.sub(pattern, process_function, content, flags=re.DOTALL)

    # Check if any changes were made
    if new_content == content:
        return False

    # Write the modified content
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)

    return True


def main():
    """Main execution function."""
    print("Starting reward function purge...\n")

    # Get the directory to search (default to current directory)
    search_dir = sys.argv[1] if len(sys.argv) > 1 else "."

    # Find all Python files
    python_files = find_python_files(search_dir)

    if not python_files:
        print(f"No Python files found in {search_dir}")
        return

    print(f"Found {len(python_files)} Python files to check\n")

    modified_count = 0
    error_count = 0

    for file_path in python_files:
        # Skip backup files
        if file_path.suffix == '.backup':
            continue

        try:
            # Check if file contains compute_rewards
            with open(file_path, 'r', encoding='utf-8') as f:
                if 'def compute_rewards' not in f.read():
                    continue

            print(f"Processing: {file_path}")

            # Create backup
            backup_path = file_path.with_suffix(file_path.suffix + '.backup')
            shutil.copy2(file_path, backup_path)

            # Process the file
            if purge_compute_rewards(file_path):
                print(f"  ✓ Successfully purged compute_rewards in {file_path}")
                modified_count += 1
            else:
                print(f"  - No changes needed for {file_path}")
                # Remove backup if no changes were made
                backup_path.unlink()

        except Exception as e:
            print(f"  ✗ Error processing {file_path}: {e}")
            error_count += 1
            # Restore from backup if it exists
            if backup_path.exists():
                shutil.copy2(backup_path, file_path)
                print(f"    Restored from backup")

    print(f"\n{'='*60}")
    print(f"Reward function purge complete!")
    print(f"Files modified: {modified_count}")
    print(f"Errors: {error_count}")

    if modified_count > 0:
        print(f"\nNote: Backup files (.backup) have been created.")
        print(f"Review changes and delete backups if satisfied:")
        print(f"  find . -name '*.py.backup' -delete")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
