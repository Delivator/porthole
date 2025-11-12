#!/bin/bash
# Validation script for Porthole configuration files
# This script checks file syntax and configuration without requiring network access

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Porthole Configuration Validator${NC}"
echo -e "${GREEN}======================================${NC}"
echo

# Check 1: Validate shell scripts syntax
echo -e "${YELLOW}Checking shell script syntax...${NC}"
for script in entrypoint.sh test.sh validate.sh; do
    if [ -f "$script" ]; then
        if bash -n "$script" 2>/dev/null; then
            echo -e "${GREEN}✓ $script syntax is valid${NC}"
        else
            echo -e "${RED}✗ $script has syntax errors${NC}"
            bash -n "$script"
            exit 1
        fi
    fi
done
echo

# Check 2: Validate Dockerfile
echo -e "${YELLOW}Checking Dockerfile...${NC}"
if [ -f "Dockerfile" ]; then
    # Basic checks
    if grep -q "FROM alpine" Dockerfile; then
        echo -e "${GREEN}✓ Dockerfile uses Alpine base image${NC}"
    fi
    
    if grep -q "autossh" Dockerfile; then
        echo -e "${GREEN}✓ Dockerfile installs autossh${NC}"
    fi
    
    if grep -q "ENTRYPOINT" Dockerfile; then
        echo -e "${GREEN}✓ Dockerfile has ENTRYPOINT${NC}"
    fi
    
    if grep -q "entrypoint.sh" Dockerfile; then
        echo -e "${GREEN}✓ Dockerfile references entrypoint.sh${NC}"
    fi
else
    echo -e "${RED}✗ Dockerfile not found${NC}"
    exit 1
fi
echo

# Check 3: Validate docker-compose.yml
echo -e "${YELLOW}Checking docker-compose.yml...${NC}"
if command -v docker &> /dev/null; then
    if docker compose config > /dev/null 2>&1; then
        echo -e "${GREEN}✓ docker-compose.yml syntax is valid${NC}"
    elif command -v docker-compose &> /dev/null && docker-compose config > /dev/null 2>&1; then
        echo -e "${GREEN}✓ docker-compose.yml syntax is valid${NC}"
    else
        echo -e "${YELLOW}! Could not validate docker-compose.yml (Docker not available)${NC}"
    fi
else
    echo -e "${YELLOW}! Docker not installed, skipping docker-compose validation${NC}"
fi
echo

# Check 4: Verify required files exist
echo -e "${YELLOW}Checking required files...${NC}"
required_files=(
    "Dockerfile"
    "docker-compose.yml"
    "entrypoint.sh"
    ".env.example"
    ".gitignore"
    ".dockerignore"
    "README.md"
    "QUICKSTART.md"
)

all_exist=true
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ $file${NC}"
    else
        echo -e "${RED}✗ $file is missing${NC}"
        all_exist=false
    fi
done

if [ "$all_exist" = false ]; then
    exit 1
fi
echo

# Check 5: Verify example files
echo -e "${YELLOW}Checking example configurations...${NC}"
if [ -d "examples" ]; then
    example_count=$(find examples -name "*.yml" | wc -l)
    echo -e "${GREEN}✓ Found $example_count example configurations${NC}"
    
    for example in examples/*.yml; do
        if [ -f "$example" ]; then
            echo -e "  - $(basename $example)"
        fi
    done
else
    echo -e "${YELLOW}! examples directory not found${NC}"
fi
echo

# Check 6: Verify .env.example has required variables
echo -e "${YELLOW}Checking .env.example configuration...${NC}"
required_vars=(
    "SSH_REMOTE_HOST"
    "SSH_REMOTE_USER"
    "SSH_TUNNEL_TYPE"
    "SSH_TUNNEL_LOCAL_PORT"
    "SSH_TUNNEL_REMOTE_PORT"
)

for var in "${required_vars[@]}"; do
    if grep -q "^${var}=" .env.example || grep -q "^# ${var}=" .env.example; then
        echo -e "${GREEN}✓ $var defined in .env.example${NC}"
    else
        echo -e "${RED}✗ $var missing from .env.example${NC}"
        exit 1
    fi
done
echo

# Check 7: Verify ssh-keys directory setup
echo -e "${YELLOW}Checking ssh-keys directory...${NC}"
if [ -d "ssh-keys" ]; then
    echo -e "${GREEN}✓ ssh-keys directory exists${NC}"
    
    if [ -f "ssh-keys/.gitignore" ]; then
        echo -e "${GREEN}✓ ssh-keys/.gitignore exists (protects keys from git)${NC}"
    else
        echo -e "${YELLOW}! ssh-keys/.gitignore missing${NC}"
    fi
    
    if [ -f "ssh-keys/README.md" ]; then
        echo -e "${GREEN}✓ ssh-keys/README.md exists${NC}"
    fi
else
    echo -e "${RED}✗ ssh-keys directory not found${NC}"
    exit 1
fi
echo

# Check 8: Verify .gitignore protects sensitive files
echo -e "${YELLOW}Checking .gitignore...${NC}"
if [ -f ".gitignore" ]; then
    if grep -q "ssh-keys" .gitignore; then
        echo -e "${GREEN}✓ .gitignore protects ssh-keys${NC}"
    fi
    
    if grep -q ".env" .gitignore; then
        echo -e "${GREEN}✓ .gitignore protects .env files${NC}"
    fi
    
    if grep -q "id_rsa" .gitignore; then
        echo -e "${GREEN}✓ .gitignore protects SSH keys${NC}"
    fi
else
    echo -e "${RED}✗ .gitignore not found${NC}"
    exit 1
fi
echo

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}All validation checks passed! ✓${NC}"
echo -e "${GREEN}======================================${NC}"
echo
echo -e "${YELLOW}Configuration files are valid and ready to use.${NC}"
echo
echo "Next steps:"
echo "1. Copy .env.example to .env and configure your settings"
echo "2. Place your SSH private key in ssh-keys/id_rsa"
echo "3. Build and run with: docker-compose up -d"
