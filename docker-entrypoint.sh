#!/bin/bash
# Docker entrypoint script for BXE Manager container
# Validates required mounts and environment before starting

set -e

# Color codes for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "=== BXE Manager Container Startup ==="

# Check if /tools is mounted
if [ ! -d "/tools" ]; then
    echo -e "${RED}ERROR: /tools directory not found!${NC}"
    echo -e "${YELLOW}The /tools directory must be mounted from the host.${NC}"
    echo ""
    echo "To fix this, run the container with:"
    echo "  docker run -v /tools:/tools ..."
    echo ""
    echo "Or add to docker-compose.yml:"
    echo "  volumes:"
    echo "    - /tools:/tools:ro"
    exit 1
fi

# Check if /tools contains expected files
VITIS_SCRIPT="/tools/source-vitis-2023.1.sh"
if [ ! -f "${VITIS_SCRIPT}" ]; then
    echo -e "${YELLOW}WARNING: ${VITIS_SCRIPT} not found!${NC}"
    echo "Xilinx Vitis tools may not be available."
    echo "bxe-firesim.sh expects this file to exist."
    echo ""
fi

# Check if /tools is read-only (recommended for safety)
if touch /tools/.write_test 2>/dev/null; then
    rm -f /tools/.write_test
    echo -e "${YELLOW}WARNING: /tools is mounted read-write${NC}"
    echo "Consider mounting /tools read-only with: -v /tools:/tools:ro"
    echo ""
else
    echo -e "${GREEN}✓ /tools mounted read-only${NC}"
fi

echo -e "${GREEN}✓ /tools directory mounted successfully${NC}"
echo ""

# Execute the command passed to the container
exec "$@"
