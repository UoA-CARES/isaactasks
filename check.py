#!/usr/bin/env python3
import os
import yaml
from pathlib import Path


def find_yaml_files():
    """Find all YAML files in the project and check their structure."""
    project_root = Path("/home/lee/code/isaactasks")
    yaml_files = []
    
    # Find all YAML files
    for yaml_path in project_root.glob("**/*.yaml"):
        if ".git" in str(yaml_path):
            continue
        yaml_files.append(yaml_path)
    
    print(f"Found {len(yaml_files)} YAML files in total.")
    return yaml_files


def analyze_yaml_files(yaml_files):
    """Analyze YAML files and look for environment configuration entries."""
    possible_config_keys = [
        "env_cfg_entry_point",
        "env_cfg_path",
        "env_config",
        "environment_config",
        "config_path",
        "env_module"
    ]
    
    found_configs = []
    
    for yaml_file in yaml_files:
        try:
            with open(yaml_file, 'r') as f:
                try:
                    config = yaml.safe_load(f)
                    
                    # If it's not a dict or is empty, skip
                    if not isinstance(config, dict) or not config:
                        continue
                        
                    # Look for any keys that might contain environment config paths
                    for key in possible_config_keys:
                        if key in config and config[key]:
                            found_configs.append((yaml_file, key, config[key]))
                            
                    # Also check for nested configurations
                    for section, section_data in config.items():
                        if isinstance(section_data, dict):
                            for key in possible_config_keys:
                                if key in section_data and section_data[key]:
                                    found_configs.append((yaml_file, f"{section}.{key}", section_data[key]))
                                    
                except yaml.YAMLError:
                    print(f"Error parsing {yaml_file} - not a valid YAML file")
                    
        except Exception as e:
            print(f"Error reading {yaml_file}: {e}")
    
    return found_configs


if __name__ == "__main__":
    yaml_files = find_yaml_files()
    found_configs = analyze_yaml_files(yaml_files)
    
    if found_configs:
        print("\nFound environment configuration entries:")
        for file_path, key, value in found_configs:
            print(f"\n{file_path}:")
            print(f"  {key}: {value}")
    else:
        print("\nNo environment configuration entries found in any YAML files.")
        
    # Also show the directory structure to help understand file organization
    print("\nProject directory structure (first 2 levels):")
    os.system("find /home/lee/code/isaactasks -maxdepth 2 -type d | sort")