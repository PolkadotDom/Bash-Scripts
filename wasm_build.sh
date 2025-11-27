#!/bin/bash
# Builds a wasm runtime to the set directory, bypasses build blockers.

# Unset SKIP_WASM_BUILD for this run so the runtime builds
unset SKIP_WASM_BUILD

# Run the build command
# "$@" passes all arguments (like --features '...') to cargo
FORCE_WASM_BUILD=1 WASM_TARGET_DIRECTORY="$WASM_BUILD_DIRECTORY" cargo build --release "$@"