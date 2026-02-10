# 🚀 Push Commit Build Deploy

## Quick Start

This script automates the complete workflow: commit changes, push to Git, build the application, and deploy to Firebase.

### Usage

```bash
# With commit message as argument
./push_commit_build_deploy.sh "feat: add new feature"

# Interactive mode (will prompt for message)
./push_commit_build_deploy.sh
```

## What It Does

The script performs these steps in order:

1. **Security Check** - Validates no secrets or sensitive files are being committed
2. **Clean** - Removes temporary files (build artifacts, analysis files)
3. **Stage** - Stages all changes with `git add -A`
4. **Commit** - Commits with your provided message
5. **Push** - Pushes to the current branch on origin
6. **Build** - Builds Flutter web app in release mode
7. **Deploy** - Deploys to Firebase (hosting, functions, firestore rules/indexes)

## Security Features

The script includes multiple safety checks to prevent committing:
- `functions/node_modules/`
- `serviceAccountKey.json`
- `*firebase-adminsdk*.json`
- `functions/.env*`
- `functions/.runtimeconfig.json`

If any of these files are staged or tracked, the script will exit with an error.

## Requirements

- Git
- Flutter SDK
- Firebase CLI
- npm (for Functions dependencies)

## Exit Codes

- `0` - Success (or nothing to commit)
- `1` - Error (security check failed, build failed, or deploy failed)

## Examples

```bash
# Deploy a new feature
./push_commit_build_deploy.sh "feat: add user authentication"

# Deploy a bug fix
./push_commit_build_deploy.sh "fix: resolve payment issue"

# Deploy with default message
./push_commit_build_deploy.sh

# The script will prompt: "Commit message: "
# Press Enter to use default: "chore: automated deployment"
```

## Related Scripts

- `commit_push_build_deploy.sh` - Similar comprehensive script
- `git_commit_push_build_deploy.sh` - Alternative with Mapbox token support
- `quick_deploy.sh` - Fast deploy without full build
- `deploy.sh` - Deploy only (no git operations)

## Notes

- The script runs in "strict mode" (`set -euo pipefail`) - any command failure will stop execution
- Build artifacts are cleaned before deployment
- Functions dependencies are installed with `npm ci` if `package-lock.json` exists
- Flutter web is built in release mode for optimal performance
- All Firebase targets are deployed: hosting, functions, firestore rules, and indexes
