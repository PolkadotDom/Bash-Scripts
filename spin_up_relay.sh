#!/bin/bash

# Spin up a relay node.
# This script builds a node, optionally rebuilds its chain spec
# from the specified chain-spec-generator directory,
# waits 3 seconds, opens Polkadot.js Apps, and then starts the node
# in the background.

# Example usage, can run from anywhere
# spin_up_relay --branch-name stable2503 --spec-id polkadot-dev --rebuild-spec

# --- Configuration ---
DEFAULT_POLKADOT_SDK_DIR="/Volumes/BlockDrive/BlockchainDev/polkadot-sdk"
POLKADOT_SDK_DIR="${POLKADOT_SDK_DIR:-$DEFAULT_POLKADOT_SDK_DIR}"

# Directory for running the chain spec generation command
DEFAULT_CHAIN_SPEC_GENERATOR_DIR="/Volumes/BlockDrive/BlockchainDev/fellowship-runtimes/chain-spec-generator"
CHAIN_SPEC_GENERATOR_DIR="${CHAIN_SPEC_GENERATOR_DIR_ENV:-$DEFAULT_CHAIN_SPEC_GENERATOR_DIR}"


# --- Default values for arguments ---
ARG_BRANCH_NAME=""
ARG_SPEC_ID=""
FLAG_REBUILD_SPEC=false
NODE_PID=0 # Global variable to store Node PID for the trap

# --- Cleanup function for trap ---
cleanup() {
  echo # Newline after ^C
  echo "Ctrl+C detected. Stopping Polkadot node (PID: $NODE_PID)..."
  if ps -p "$NODE_PID" > /dev/null; then # Check if process exists
    kill "$NODE_PID"
    wait "$NODE_PID" 2>/dev/null # Wait for it to actually terminate
    echo "Node (PID: $NODE_PID) stopped."
  else
    echo "Node (PID: $NODE_PID) was not running or already stopped."
  fi
  exit 0 # Clean exit after cleanup
}

# --- Usage function ---
usage() {
  echo "Usage: $0 --branch-name <branch_name> --spec-id <spec_identifier> [--rebuild-spec]"
  echo "Example: $0 --branch-name main --spec-id polkadot-dev --rebuild-spec"
  echo "         $0 --branch-name v1.2.3 --spec-id my-custom-spec"
  exit 1
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --branch-name)
      ARG_BRANCH_NAME="$2"; shift 2; if [[ -z "$ARG_BRANCH_NAME" ]]; then usage; fi ;;
    --spec-id)
      ARG_SPEC_ID="$2"; shift 2; if [[ -z "$ARG_SPEC_ID" ]]; then usage; fi ;;
    --rebuild-spec)
      FLAG_REBUILD_SPEC=true; shift ;;
    *) echo "Error: Unknown option: $1" >&2; usage ;;
  esac
done

# --- Validate mandatory arguments ---
if [ -z "$ARG_BRANCH_NAME" ]; then echo "Error: --branch-name is required." >&2; usage; fi
if [ -z "$ARG_SPEC_ID" ]; then echo "Error: --spec-id is required." >&2; usage; fi

# --- Check for Environment Variables & Directories ---
if [ -z "$NODE_BUILD_DIRECTORY" ]; then echo "Error: NODE_BUILD_DIRECTORY is not set." >&2; exit 1; fi
if [ -z "$CHAIN_SPEC_BUILD_DIRECTORY" ]; then echo "Error: CHAIN_SPEC_BUILD_DIRECTORY is not set." >&2; exit 1; fi
if [ ! -d "$POLKADOT_SDK_DIR" ]; then echo "Error: Polkadot SDK dir '$POLKADOT_SDK_DIR' not found." >&2; exit 1; fi
if [ "$FLAG_REBUILD_SPEC" = true ] && [ ! -d "$CHAIN_SPEC_GENERATOR_DIR" ]; then
  echo "Error: Chain Spec Generator directory not found at '$CHAIN_SPEC_GENERATOR_DIR' (needed for --rebuild-spec)." >&2;
  echo "       You can set CHAIN_SPEC_GENERATOR_DIR_ENV to override the default." >&2;
  exit 1;
fi

echo "--- Script Execution ---"
echo "Target Polkadot Node Branch: $ARG_BRANCH_NAME"
echo "Chain Spec Identifier:       $ARG_SPEC_ID"
echo "Rebuild Chain Spec:        $FLAG_REBUILD_SPEC"
echo "Node Build Directory:        $NODE_BUILD_DIRECTORY"
echo "Chain Spec Build Directory:  $CHAIN_SPEC_BUILD_DIRECTORY"
echo "Polkadot SDK Directory:      $POLKADOT_SDK_DIR"
if [ "$FLAG_REBUILD_SPEC" = true ]; then
  echo "Chain Spec Generator Dir:    $CHAIN_SPEC_GENERATOR_DIR"
fi
echo "--------------------------"

# Step 1: Build node binary
echo "Step 1: Building/Sourcing node binary for branch '$ARG_BRANCH_NAME'..."
build_node.sh --branch-name "$ARG_BRANCH_NAME"
BUILD_NODE_STATUS=$?
if [ $BUILD_NODE_STATUS -ne 0 ]; then echo "Error: build_node.sh failed ($BUILD_NODE_STATUS)." >&2; exit $BUILD_NODE_STATUS; fi
BUILT_NODE_NAME="polkadot-$ARG_BRANCH_NAME"
BUILT_NODE_EXECUTABLE_PATH="$NODE_BUILD_DIRECTORY/$BUILT_NODE_NAME"
if [ ! -f "$BUILT_NODE_EXECUTABLE_PATH" ]; then echo "Error: Node binary '$BUILT_NODE_EXECUTABLE_PATH' not found." >&2; exit 1; fi
echo "Node binary available at: $BUILT_NODE_EXECUTABLE_PATH"
echo "--------------------------"

# Step 2: Conditionally rebuild chain spec
CHAIN_SPEC_JSON_FILENAME="$ARG_SPEC_ID.json"
CHAIN_SPEC_JSON_PATH="$CHAIN_SPEC_BUILD_DIRECTORY/$CHAIN_SPEC_JSON_FILENAME"
if [ "$FLAG_REBUILD_SPEC" = true ]; then
  echo "Step 2: Rebuilding chain spec for '$ARG_SPEC_ID'..."
  mkdir -p "$CHAIN_SPEC_BUILD_DIRECTORY" # Ensure output directory exists

  echo "Changing to Chain Spec Generator directory: $CHAIN_SPEC_GENERATOR_DIR"
  echo "Command: cargo run --release --features polkadot -- \"$ARG_SPEC_ID\" > \"$CHAIN_SPEC_JSON_PATH\""

  pushd "$CHAIN_SPEC_GENERATOR_DIR" > /dev/null || { echo "Error: Failed to cd to $CHAIN_SPEC_GENERATOR_DIR" >&2; exit 1; }
  
  # The command `cargo run --release --features polkadot -- <identifier>` is run here
  if cargo run --release --features polkadot -- "$ARG_SPEC_ID" > "$CHAIN_SPEC_JSON_PATH"; then
    echo "Chain spec rebuild successful."
  else
    SPEC_REBUILD_STATUS=$?
    echo "Error: Chain spec rebuild (cargo run --release --features polkadot -- \"$ARG_SPEC_ID\") failed with status $SPEC_REBUILD_STATUS." >&2
    rm -f "$CHAIN_SPEC_JSON_PATH" # Clean up potentially partial file
    popd > /dev/null # Return to original directory
    exit $SPEC_REBUILD_STATUS
  fi
  popd > /dev/null # Return to original directory
else
  echo "Step 2: Skipping chain spec rebuild."
fi

if [ ! -s "$CHAIN_SPEC_JSON_PATH" ]; then # Check if file exists and is not empty
    echo "Error: Chain spec file not found or is empty at '$CHAIN_SPEC_JSON_PATH'." >&2
    echo "       Consider using the --rebuild-spec flag if it needs to be generated." >&2; exit 1;
fi
echo "Chain spec to be used: $CHAIN_SPEC_JSON_PATH"
echo "--------------------------"

# Step 3: Wait for 3 seconds
echo "Step 3: Waiting for 3 seconds before opening Polkadot.js Apps..."
sleep 3
echo "--------------------------"

# Step 4: Open Polkadot.js Apps in Chrome
echo "Step 4: Opening Polkadot.js Apps..."
if ! open -a "Google Chrome" "https://polkadot.js.org/apps/?rpc=ws%3A%2F%2Flocalhost%3A9944#/accounts"; then
    echo "Warning: Failed to open URL in Google Chrome. Attempting with default browser..."
    if ! open "https://polkadot.js.org/apps/?rpc=ws%3A%2F%2Flocalhost%3A9944#/accounts"; then
        echo "Warning: Failed to open URL. Please open manually: https://polkadot.js.org/apps/?rpc=ws%3A%2F%2Flocalhost%3A9944#/accounts"
    fi
fi
echo "--------------------------"

# Step 5: Run the node (in the background)
echo "Step 5: Starting node '$BUILT_NODE_NAME' in the background..."
echo "Cmd: $BUILT_NODE_EXECUTABLE_PATH --chain \"$CHAIN_SPEC_JSON_PATH\" --dev &"

"$BUILT_NODE_EXECUTABLE_PATH" --chain "$CHAIN_SPEC_JSON_PATH" --dev &
NODE_PID=$! # Capture PID of the last backgrounded process
export NODE_PID 

# Set the trap: when SIGINT (Ctrl+C) is received, call the cleanup function
trap cleanup SIGINT

# Brief pause and check if process started
sleep 1
if ! ps -p "$NODE_PID" > /dev/null; then
   echo "Warning: Node process (PID $NODE_PID) did not start or exited quickly." >&2
fi
echo "Node started in background with PID: $NODE_PID"
echo "This script will now wait. Press Ctrl+C in this terminal to stop the node and exit."
echo "--------------------------"

# Step 6: Wait for the node to exit (or for Ctrl+C to be caught by the trap)
wait "$NODE_PID"
WAIT_EXIT_STATUS=$?

trap - SIGINT # Clear the trap

if [ $WAIT_EXIT_STATUS -ne 0 ] && [ $WAIT_EXIT_STATUS -ne 130 ]; then
    echo "Node (PID: $NODE_PID) exited with status $WAIT_EXIT_STATUS."
elif [ $WAIT_EXIT_STATUS -eq 0 ]; then
    echo "Node (PID: $NODE_PID) exited normally."
fi

echo "Script finished."