# GitHub Research Security Workflows

This repository provides reusable GitHub workflows and pre-commit hooks designed to help research teams prevent accidental data leaks, enforce version control standards, and comply with institutional security guidelines.

It is part of a broader effort to support researchers in securely managing software and data when working with GitHub.

## Contents

### Reusable GitHub Workflow

- `.github/workflows/check-forbidden-filetypes.yml`  
  A reusable workflow that fails if forbidden file types are committed. It uses the composite github action `filetype-check/` as suggested by GitHub security guidelines. It can be called from other workflows in the organization. For usage see below.

### Composite GitHub Action

- `filetype-check/`  
  A composite GitHub Action that scans the Git index for forbidden file extensions. It reads from a shared `forbidden-extensions.txt` file. Used by check-forbidden-filetypes workflow

### Pre-commit Hook

- `pre-commit-check/check-filetypes.sh`  
  A shell-based pre-commit hook to block commits that include forbidden file types. Also uses the shared extension list.

### Pre-push Hook

- `pre-push-check/check-filetypes-prepush.sh`  
  A shell-based pre-commit hook to block commits that include forbidden file types. Also uses the shared extension list.


### Shared Extension List

- `central-gitignore.txt`  
  A centralized list of sensitive file extensions (e.g. `.csv`, `.json`, `.nii.gz`) used by both the action, the pre-commit, and the pre-push hook.

## Usage

### Using the GitHub Workflow in a Repository

To use the reusable workflow in another repository, create a workflow file like this:

```yaml
name: Check for forbidden filetypes

on:
  push:
    branches: [main]
  pull_request:

jobs:
  security-check:
    uses: bavadeve/org-security-workflows/.github/workflows/check-forbidden-filetypes.yml@main
```

Replace `@main` with a version tag for stability if available.

### Using the Pre-commit Hook

In your repository's `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/bavadeve/org-security-workflows
    rev: v0.2.5
    hooks:
      - id: check-forbidden-filetypes

repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-added-large-files
        args: ['--maxkb=100']
      - id: check-merge-conflict
```

Then install:

```bash
pip install pre-commit
pre-commit install
pre-commit install --hook-type pre-push
```


This ensures commits are checked locally before being pushed.

## How It Works

### The Central Gitignore

The `central-gitignore.txt` file contains two sections:

```gitignore
# BEGIN FORBIDDEN
*.csv
*.xlsx
*.json
!package.json    # Exception: this file is allowed
# END FORBIDDEN

# Everything below is convenience-only (not enforced)
.DS_Store
__pycache__/
output/
```

**Only patterns between `# BEGIN FORBIDDEN` and `# END FORBIDDEN`** are enforced by the hooks and GitHub Action. Everything else is just helpful `.gitignore` patterns that won't block commits.

### Exceptions

Some files are blocked by default but have exceptions for common safe files:

| Blocked | Exceptions |
|---------|------------|
| `*.json` | `package.json`, `package-lock.json`, `tsconfig.json`, etc. |
| `*.xml` | `pom.xml`, `web.xml`, `*.csproj`, etc. |
| `.env` | (no exceptions) |

See `central-gitignore.txt` for the full list.

## What Happens When a File is Blocked

### Pre-commit hook

```
══════════════════════════════════════════════════════════════
  ERROR: Forbidden file types detected!
══════════════════════════════════════════════════════════════

The following files match forbidden data patterns:

  ✗ data/patients.csv

These file types are blocked to prevent accidental data leaks.

If this is a false positive, contact your data steward.
To bypass (NOT recommended): git commit --no-verify
```

### GitHub Action

The workflow will fail with a red ❌ and annotate the problematic files.

## Remediation

If sensitive data was accidentally committed:

### If the repo is public

1. **Immediately** make the repo private
2. Contact your data steward / privacy officer
3. Follow the steps below to clean history

### Cleaning Git history

```bash
# Install git-filter-repo (recommended over filter-branch)
pip install git-filter-repo

# Remove a specific file from all history
git filter-repo --path data/patients.csv --invert-paths

# Force push (coordinate with collaborators first!)
git push --force --all
```

See [GitHub's guide on removing sensitive data](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository).

## Troubleshooting

### Pre-commit hook not running
```bash
pre-commit install
pre-commit install --hook-type pre-push
```

### Hook using outdated rules
```bash
pre-commit clean
pre-commit install
pre-commit install --hook-type pre-push
```

### Need to bypass (use with caution!)
```bash
git commit --no-verify
git push --no-verify
```

### For testing

```bash
touch dummy.csv # create dummy data file
git add dummy.csv # should be stopped by .gitignore
git add -f dummy.csv # push through .gitignore
git commit -m 'test data upload' # should be stopped by pre-commit
git commit --no-verify -m 'test data upload' # push through pre-commit
git push origin main # should be stopped by pre-push
git push origin main --no-verify # push through pre-push --> file is uploaded and should trigger a GitHub Action
```

## Notes for Windows / GitHub Desktop Users

On Windows, pre-commit hooks will not run correctly in default GitHub Desktop shell environments. To enable proper behavior:

1. Install Git Bash (from https://gitforwindows.org/)
2. In GitHub Desktop: File → Options → Git → Shell → select "Git Bash"

Alternatively, use Git Bash or WSL directly for committing.

## Security Layers

| Layer              | Purpose                                               | Limitations                                      |
|-------------------|--------------------------------------------------------|--------------------------------------------------|
| `.gitignore`       | Prevents common sensitive files from being tracked     | Can be bypassed with `git add -f`                |
| Pre-commit hook   | Blocks dangerous files from being committed locally     | Requires local setup, can be skipped             |
| GitHub Action     | Catches violations on push or PR                        | Cannot block direct pushes unless protected      |
| Branch protection | Prevents merging PRs that fail security checks          | Must be configured per repository                |

These layers provide increasing levels of safety, from developer machines to repository-level enforcement.

## License

MIT License - See [LICENSE](LICENSE)

