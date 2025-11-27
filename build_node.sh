#!/bin/bash

# Script to build a specified version of Polkadot node from a given Git branch.
# Target OS: macOS

# --- Configuration ---
DEFAULT_POLKADOT_SDK_DIR="/Volumes/BlockDrive/BlockchainDev/polkadot-sdk"
POLKADOT_SDK_DIR="${POLKADOT_SDK_DIR:-$DEFAULT_POLKADOT_SDK_DIR}"

GIT_REMOTE_NAME="origin" # Assumed remote name for fetching updates

# --- macOS Check ---
if [ "$(uname -s)" != "Darwin" ]; then
  echo "Error: This script is intended for macOS only." >&2
  exit 1
fi

# --- NODE_BUILD_DIRECTORY Check ---
if [ -z "$NODE_BUILD_DIRECTORY" ]; then
  echo "Error: NODE_BUILD_DIRECTORY is not set. Please set it in your environment." >&2
  echo "       It will be used to store the compiled binary." >&2
  exit 1
fi
mkdir -p "$NODE_BUILD_DIRECTORY" # Ensure it exists

# --- POLKADOT_SDK_DIR Check ---
if [ ! -d "$POLKADOT_SDK_DIR" ]; then
  echo "Error: Polkadot SDK directory not found at '$POLKADOT_SDK_DIR'." >&2
  echo "       Please set the POLKADOT_SDK_DIR environment variable or ensure the default path is correct." >&2
  exit 1
fi
if [ ! -d "$POLKADOT_SDK_DIR/.git" ]; then
  echo "Error: '$POLKADOT_SDK_DIR' is not a git repository." >&2
  exit 1
fi

# --- Tool Checks ---
if ! command -v git &> /dev/null; then
  echo "Error: git command not found. Please install git." >&2
  exit 1
fi
if ! command -v cargo &> /dev/null; then
  echo "Error: cargo command not found. Please install Rust and Cargo." >&2
  exit 1
fi

# --- Argument Parsing ---
BRANCH_NAME=""

if [[ "$1" == "--branch-name" ]]; then
  if [[ -z "$2" ]]; then
    echo "Error: --branch-name requires a branch name (e.g., 'v1.18.4', 'main')." >&2
    exit 1
  fi
  BRANCH_NAME="$2"
  shift 2
else
  echo "Error: --branch-name <branch_name> is required." >&2
  echo "Example: $0 --branch-name v1.18.4" >&2
  exit 1
fi

if [[ -n "$1" ]]; then # Check for any remaining unexpected arguments
    echo "Error: Unknown argument '$1'. Only --branch-name <branch_name> is accepted." >&2
    exit 1
fi

# --- Main Execution ---
TARGET_BINARY_FILENAME="polkadot-$BRANCH_NAME"
TARGET_BINARY_FULL_PATH="$NODE_BUILD_DIRECTORY/$TARGET_BINARY_FILENAME"

echo "Requested Polkadot version (Git Branch): $BRANCH_NAME"
echo "Target binary: $TARGET_BINARY_FULL_PATH"
echo "Using Polkadot SDK from: $POLKADOT_SDK_DIR"

# Check if binary already exists
if [ -f "$TARGET_BINARY_FULL_PATH" ]; then
  echo "Info: Binary '$TARGET_BINARY_FILENAME' already exists at '$TARGET_BINARY_FULL_PATH'."
  echo "Skipping build."
  exit 0
fi

echo "Changing to SDK directory: $POLKADOT_SDK_DIR"
pushd "$POLKADOT_SDK_DIR" > /dev/null || { echo "Error: Failed to change to SDK directory." >&2; exit 1; }

# Store current git state (branch or commit)
ORIGINAL_GIT_STATE=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse HEAD)
echo "Current Git state in SDK: $ORIGINAL_GIT_STATE"

# Check for uncommitted changes
echo "Checking for uncommitted changes in SDK repository..."
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Error: Git repository at '$POLKADOT_SDK_DIR' has uncommitted changes." >&2
  echo "Please commit or stash them before running this script." >&2
  popd > /dev/null
  exit 1
fi
echo "Repository is clean."

# Fetch updates from remote
echo "Fetching updates from remote '$GIT_REMOTE_NAME'..."
if ! git fetch "$GIT_REMOTE_NAME"; then
  echo "Warning: Failed to fetch from '$GIT_REMOTE_NAME'. Will proceed with local refs." >&2
  # Not exiting here, as the branch might exist locally.
fi

# Switch to the specified branch
echo "Attempting to switch to branch '$BRANCH_NAME'..."
if ! git switch "$BRANCH_NAME"; then
  echo "Error: Failed to switch to branch '$BRANCH_NAME'." >&2
  echo "Ensure the branch exists locally or can be checked out from remote '$GIT_REMOTE_NAME/$BRANCH_NAME'." >&2
  # No need to checkout ORIGINAL_GIT_STATE here as switch failed, repo state unchanged.
  popd > /dev/null
  exit 1
fi
echo "Successfully switched to branch '$BRANCH_NAME'."
# Optional: If you want to ensure it's aligned with the remote version of this branch:
# echo "Ensuring branch '$BRANCH_NAME' is up-to-date with its remote counterpart..."
# if ! git pull --ff-only; then # Or use git reset --hard @{u} with caution
#   echo "Warning: Could not fast-forward pull branch '$BRANCH_NAME'. Building current local state."
# fi


# Build the binary
echo "Starting Polkadot node release build (this can take a significant amount of time)..."
echo "Command: cargo build --release"
if ! cargo build --release; then
  echo "Error: cargo build --release failed." >&2
  echo "Attempting to restore original Git state..."
  git checkout "$ORIGINAL_GIT_STATE" --quiet
  popd > /dev/null
  exit 1
fi
echo "Build completed successfully."

COMPILED_BINARY_PATH="target/release/polkadot"
if [ ! -f "$COMPILED_BINARY_PATH" ]; then
  echo "Error: Compiled binary not found at '$COMPILED_BINARY_PATH' after build." >&2
  git checkout "$ORIGINAL_GIT_STATE" --quiet
  popd > /dev/null
  exit 1
fi

# Move and rename the binary
echo "Moving compiled binary to $TARGET_BINARY_FULL_PATH"
if ! mv "$COMPILED_BINARY_PATH" "$TARGET_BINARY_FULL_PATH"; then
  echo "Error: Failed to move compiled binary." >&2
  git checkout "$ORIGINAL_GIT_STATE" --quiet
  popd > /dev/null
  exit 1
fi
chmod +x "$TARGET_BINARY_FULL_PATH"

# Cleanup: Restore original Git state
echo "Restoring original Git state '$ORIGINAL_GIT_STATE'..."
if ! git checkout "$ORIGINAL_GIT_STATE" --quiet; then
    echo "Warning: Failed to checkout original Git state '$ORIGINAL_GIT_STATE'. Manual cleanup might be needed in '$POLKADOT_SDK_DIR'." >&2
fi

popd > /dev/null # Return to original directory
echo "--------------------------------------------------------------------"
echo "Polkadot node (from branch: $BRANCH_NAME) built successfully!"
echo "Executable available at: $TARGET_BINARY_FULL_PATH"
echo "--------------------------------------------------------------------"