#!/usr/bin/env python3
import yaml
import re

# Load forbidden extensions
with open("forbidden-extensions.txt") as f:
    lines = f.readlines()

patterns = []

for line in lines:
    line = line.strip()

    # skip comments, blank lines, section headers
    if not line or line.startswith("#"):
        continue

    # multi-dot extensions (nii.gz, tar.gz, etc.)
    # just prefix with '*.'
    patterns.append(f"*.{line}")

# Build GitHub ruleset
ruleset = {
    "name": "Block Forbidden File Types",
    "target": "push",
    "enforcement": "active",
    "conditions": {
        "file_paths": {"included": patterns},
        "branches": {"includes": ["*"]},
    },
    "rules": [
        {
            "type": "file_path_restriction",
            "parameters": {"restricted_file_patterns": patterns},
        }
    ],
}

print(yaml.dump(ruleset, sort_keys=False))
