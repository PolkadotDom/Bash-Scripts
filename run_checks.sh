#!/bin/bash

# A script to run the checks necessary before opening a frame PR

# Save the current directory
current_dir=$(pwd)
export SKIP_WASM_BUILD=1

commands=(
  "cargo check"
  "cargo check --tests"
  "cargo clippy --all-targets --all-features --locked --quiet"
  "cargo test"
)

# Run commands in the current directory
for cmd in "${commands[@]}"; do
  echo "Running: $cmd in $current_dir"
  $cmd
  if [ $? -ne 0 ]; then
    echo "Error: Command '$cmd' failed."
    exit 1
  fi
done

cd /home/dom/Documents/Programming/RustProjects/polkadot-sdk

# Run commands at top level
commands=(
  "cargo check"
  "cargo check --tests"
  "cargo clippy --all-features --all-targets --locked --workspace"
  # "cargo clippy --all-targets --all-features --locked --workspace --quiet"
  "cargo +nightly fmt"
)

for cmd in "${commands[@]}"; do
  echo "Running: $cmd"
  $cmd
  if [ $? -ne 0 ]; then
    echo "Error: Command '$cmd' failed."
    exit 1
  fi
done

#set back
export SKIP_WASM_BUILD=0

# Check if a number argument is provided
if [ -n "$1" ]; then
  # Construct the file path using the provided number
  pr_number=$1
  file_path="/home/dom/Documents/Programming/RustProjects/polkadot-sdk/prdoc/pr_${pr_number}.prdoc"

  # Check if the file exists
  if [ ! -f "$file_path" ]; then
    echo "Error: File $file_path does not exist."
    exit 1
  fi

  # Parse the YAML file and extract the package names with a bump
  packages=$(yq -r '.crates[] | select(.bump != null) | .name' "$file_path")

  # Run cargo test on each package with a bump
  for package in $packages; do
    echo "Running: cargo test -p $package"
    cargo test -p $package --quiet
    if [ $? -ne 0 ]; then
      echo "Error: Command 'cargo test -p $package' failed."
      exit 1
    fi
  done
else
  echo "No prdoc number provided. Skipping checks."
fi

echo "All commands executed successfully."
