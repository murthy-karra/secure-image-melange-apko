#!/bin/zsh


set -eu

# Get the short 7-character commit hash (e.g., "a1b2c3d")
export GIT_HASH=$(git rev-parse --short HEAD)
DIRTY="false"
export MELANGE_VER="v0.34.0"

# Optional: If you have uncommitted changes, set dirty to true
if [[ -n $(git status -s) ]]; then
    DIRTY="true"
fi

sed \
  -e "s/__GIT_HASH__/$GIT_HASH/" \
  -e "s/__DIRTY__/$DIRTY/" \
  build/melange.yaml > melange.yaml

echo "Annotations set: commit=$GIT_HASH dirty=$DIRTY"

# # 1. Build Melange Package
# # We override the version in melange.yaml with our Git Hash
docker run --rm --privileged \
  -v "${PWD}":/work -w /work \
  -v "$HOME/.melange/keys/melange.rsa":/melange.rsa \
  cgr.dev/chainguard/melange:$MELANGE_VER \
  build melange.yaml \
  --signing-key /melange.rsa \
  --keyring-append build/melange.rsa.pub \
  --out-dir ./packages \
  --arch x86_64

# Get package name and hash from melange.yaml file
PKG=$(docker run --rm \
  -v "$PWD":/work \
  -w /work \
  mikefarah/yq -r '.package.name' melange.yaml)


if [ "$DIRTY" = "true" ]; then
  TAG="${GIT_HASH}-dirty"
else
  TAG="${GIT_HASH}"
fi

echo "Package: ${PKG}:${TAG}"


docker run --rm \
    -v ${PWD}:/work \
    -w /work \
    cgr.dev/chainguard/apko \
    build build/apko.yaml \
    ${PKG}:${TAG} \
    ${PKG}.${TAG}.tar \
    --arch x86_64

docker load < ${PKG}.${TAG}.tar



