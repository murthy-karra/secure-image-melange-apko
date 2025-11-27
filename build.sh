#!/bin/zsh

# Get the short 7-character commit hash (e.g., "a1b2c3d")
export VER=$(git rev-parse --short HEAD)

# Optional: If you have uncommitted changes, append "-dirty" so you don't get confused
if [[ -n $(git status -s) ]]; then
    export VER="${VER}-dirty"
fi

echo "Building Commit: $VER"