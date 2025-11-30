#!/bin/bash
# scan-vulnerabilities.sh - Comprehensive vulnerability scanning for your container

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

IMAGE="${1:-python:3.11-slim-bookworm}"

#IMAGE="${1:-python:3.12.3-alpine3.20}"
IMAGE="${1:-nvcr.io/0641216746495070/shi-dh/dh-rag:1.0.0}"

IMAGE="${1:-nvcr.io/0641216746495070/shi-dh/dh-external-rag:1.0.0}"

#IMAGE="${1:-ubuntu:22.04}"
IMAGE="${1:-nginx:alpine}"
IMAGE="${1:-fastapi-app:latest-amd64}"


echo "════════════════════════════════════════════════════════════════"
echo "           COMPREHENSIVE VULNERABILITY SCANNING                 "
echo "════════════════════════════════════════════════════════════════"
echo
echo "🎯 Target Image: $IMAGE"
echo

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to run scanner
run_scanner() {
    local scanner_name=$1
    local scanner_command=$2
    
    echo "────────────────────────────────────────────────────────────────"
    echo -e "${BLUE}[$scanner_name]${NC} Scanning..."
    echo "────────────────────────────────────────────────────────────────"
    eval "$scanner_command"
    echo
}

# 1. GRYPE (Anchore) - Best for comprehensive scanning
echo -e "${GREEN}■ 1. GRYPE SCANNER (Recommended)${NC}"
if command_exists grype; then
    run_scanner "Grype" "grype $IMAGE"
else
    echo "  Installing Grype..."
    curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /tmp
    run_scanner "Grype" "/tmp/grype $IMAGE"
fi

# 2. TRIVY (Aqua Security) - Industry standard
echo -e "${GREEN}■ 2. TRIVY SCANNER${NC}"
if command_exists trivy; then
    run_scanner "Trivy" "trivy image --severity HIGH,CRITICAL $IMAGE"
else
    echo "  Running Trivy via Docker..."
    run_scanner "Trivy" "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --severity HIGH,CRITICAL $IMAGE"
fi

# 3. SNYK - Great for dependency analysis
echo -e "${GREEN}■ 3. SNYK SCANNER${NC}"
if command_exists snyk; then
    echo "  Note: Snyk requires authentication. Run 'snyk auth' first."
    run_scanner "Snyk" "snyk container test $IMAGE --severity-threshold=high"
else
    echo "  Snyk not installed. To install:"
    echo "  npm install -g snyk"
    echo "  snyk auth"
    echo
fi

# 4. Docker Scout (Docker's built-in scanner)
echo -e "${GREEN}■ 4. DOCKER SCOUT${NC}"
echo "────────────────────────────────────────────────────────────────"
if docker scout version >/dev/null 2>&1; then
    docker scout cves $IMAGE
else
    echo "  Docker Scout not available. Update Docker Desktop or run:"
    echo "  docker scout quickview $IMAGE"
fi
echo

# 5. CLAIR (via Docker)
echo -e "${GREEN}■ 5. CLAIR SCANNER${NC}"
echo "────────────────────────────────────────────────────────────────"
echo "  To use Clair (more complex setup):"
echo "  docker run -p 6060:6060 quay.io/coreos/clair"
echo

# 6. Generate and analyze SBOM
echo -e "${GREEN}■ 6. SBOM GENERATION & ANALYSIS${NC}"
echo "────────────────────────────────────────────────────────────────"
if command_exists syft; then
    echo "  Generating SBOM with Syft..."
    syft $IMAGE -o json > sbom.json
    echo "  SBOM saved to sbom.json"
    echo "  Analyzing SBOM for vulnerabilities..."
    grype sbom:sbom.json
else
    echo "  Installing Syft for SBOM generation..."
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /tmp
    /tmp/syft $IMAGE -o json > sbom.json
    echo "  SBOM saved to sbom.json"
fi
echo

# Summary and recommendations
echo "════════════════════════════════════════════════════════════════"
echo "                      SCANNING COMPLETE                         "
echo "════════════════════════════════════════════════════════════════"
echo
echo "📊 What to look for:"
echo "  • CRITICAL vulnerabilities: Fix immediately"
echo "  • HIGH vulnerabilities: Fix in next release"
echo "  • MEDIUM vulnerabilities: Evaluate and plan fixes"
echo "  • LOW vulnerabilities: Monitor and fix when convenient"
echo
echo "🔍 Understanding results:"
echo "  • Wolfi packages are updated daily (fewer CVEs)"
echo "  • Most CVEs will be in Python packages"
echo "  • Check if CVEs are actually exploitable in your context"
echo
echo "🛠️ How to fix vulnerabilities:"
echo "  1. Update base image: Rebuild with latest Wolfi"
echo "  2. Update Python packages: Modify requirements.txt"
echo "  3. Rebuild: ./build-complete.sh"
echo