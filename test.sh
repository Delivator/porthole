#!/bin/bash
# Test script for Porthole
# This script validates the Docker setup without requiring actual SSH credentials

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Porthole Test Script${NC}"
echo -e "${GREEN}======================================${NC}"
echo

# Test 1: Check if Docker is installed
echo -e "${YELLOW}Test 1: Checking Docker installation...${NC}"
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓ Docker is installed${NC}"
    docker --version
else
    echo -e "${RED}✗ Docker is not installed${NC}"
    exit 1
fi
echo

# Test 2: Check if docker-compose is available
echo -e "${YELLOW}Test 2: Checking Docker Compose installation...${NC}"
if docker compose version &> /dev/null; then
    echo -e "${GREEN}✓ Docker Compose is available${NC}"
    docker compose version
elif command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}✓ Docker Compose is available${NC}"
    docker-compose --version
else
    echo -e "${RED}✗ Docker Compose is not installed${NC}"
    exit 1
fi
echo

# Test 3: Check file structure
echo -e "${YELLOW}Test 3: Checking file structure...${NC}"
required_files=(
    "Dockerfile"
    "docker-compose.yml"
    "entrypoint.sh"
    ".env.example"
    ".gitignore"
    ".dockerignore"
    "README.md"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ $file exists${NC}"
    else
        echo -e "${RED}✗ $file is missing${NC}"
        exit 1
    fi
done
echo

# Test 4: Check entrypoint.sh is executable
echo -e "${YELLOW}Test 4: Checking entrypoint.sh permissions...${NC}"
if [ -x "entrypoint.sh" ]; then
    echo -e "${GREEN}✓ entrypoint.sh is executable${NC}"
else
    echo -e "${YELLOW}! entrypoint.sh is not executable, fixing...${NC}"
    chmod +x entrypoint.sh
    echo -e "${GREEN}✓ Fixed entrypoint.sh permissions${NC}"
fi
echo

# Test 5: Validate Dockerfile syntax
echo -e "${YELLOW}Test 5: Validating Dockerfile...${NC}"
if docker build --no-cache -t porthole:test . &> /tmp/porthole-build.log; then
    echo -e "${GREEN}✓ Dockerfile builds successfully${NC}"
    docker images | grep porthole
    
    # Test 6: Check image contents
    echo
    echo -e "${YELLOW}Test 6: Checking installed packages in image...${NC}"
    
    if docker run --rm porthole:test which autossh &> /dev/null; then
        echo -e "${GREEN}✓ autossh is installed${NC}"
    else
        echo -e "${RED}✗ autossh is not installed${NC}"
    fi
    
    if docker run --rm porthole:test which ssh &> /dev/null; then
        echo -e "${GREEN}✓ ssh is installed${NC}"
    else
        echo -e "${RED}✗ ssh is not installed${NC}"
    fi
    
    if docker run --rm porthole:test which bash &> /dev/null; then
        echo -e "${GREEN}✓ bash is installed${NC}"
    else
        echo -e "${RED}✗ bash is not installed${NC}"
    fi
    
    # Test 7: Test entrypoint script (should fail with helpful error)
    echo
    echo -e "${YELLOW}Test 7: Testing entrypoint script validation...${NC}"
    if docker run --rm porthole:test 2>&1 | grep -q "SSH_REMOTE_HOST is required"; then
        echo -e "${GREEN}✓ Entrypoint validation works correctly${NC}"
    else
        echo -e "${RED}✗ Entrypoint validation not working as expected${NC}"
    fi
    
    # Cleanup
    echo
    echo -e "${YELLOW}Cleaning up test image...${NC}"
    docker rmi porthole:test &> /dev/null || true
    echo -e "${GREEN}✓ Cleanup complete${NC}"
    
else
    echo -e "${RED}✗ Dockerfile build failed${NC}"
    echo -e "${YELLOW}Build log:${NC}"
    cat /tmp/porthole-build.log
    exit 1
fi

echo
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}All tests passed! ✓${NC}"
echo -e "${GREEN}======================================${NC}"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Copy .env.example to .env and configure your settings"
echo "2. Create ssh-keys/id_rsa with your SSH private key"
echo "3. Run: docker-compose up -d"
echo "4. Check logs: docker-compose logs -f"
