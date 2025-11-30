#!/usr/bin/env bash
set -euo pipefail

ARCH=amd64
PKG_OUT=packages
IMAGE_NAME=fastapi-app
TAR_OUT=image.tar



echo "==> Building Wolfi package with Melange..."
melange build melange.yaml \
  --arch $ARCH \
  --signing-key ~/.melange/keys/melange.rsa \
  --out-dir $PKG_OUT

echo "==> Building OCI image with APKO..."
apko build \
  --arch $ARCH \
  apko.yaml \
  $IMAGE_NAME:latest \
  $TAR_OUT

echo "==> Loading into Docker..."
docker load < $TAR_OUT
NEW_IMAGE_NAME="fastapi-app:latest-amd64"
echo ""
echo "==> DONE! Run:"
echo "docker run -p 8080:8080 $NEW_IMAGE_NAME"
