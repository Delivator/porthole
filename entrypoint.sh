#!/bin/bash
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log messages
log() {
    echo -e "${GREEN}[Porthole]${NC} $1"
}

error() {
    echo -e "${RED}[Porthole ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[Porthole WARNING]${NC} $1"
}

# Validate required environment variables
if [ -z "$SSH_REMOTE_HOST" ]; then
    error "SSH_REMOTE_HOST is required"
    exit 1
fi

if [ -z "$SSH_REMOTE_USER" ]; then
    error "SSH_REMOTE_USER is required"
    exit 1
fi

# Setup SSH key
if [ -n "$SSH_PRIVATE_KEY" ]; then
    log "Setting up SSH private key from environment variable"
    echo "$SSH_PRIVATE_KEY" > /root/.ssh/id_rsa
    chmod 600 /root/.ssh/id_rsa
elif [ -f "/ssh-key/id_rsa" ]; then
    log "Using SSH private key from mounted volume"
    cp /ssh-key/id_rsa /root/.ssh/id_rsa
    chmod 600 /root/.ssh/id_rsa
else
    error "No SSH private key provided. Please provide either SSH_PRIVATE_KEY environment variable or mount key to /ssh-key/id_rsa"
    exit 1
fi

# Setup known_hosts
if [ "$SSH_STRICT_HOST_KEY_CHECKING" == "no" ]; then
    log "Strict host key checking is disabled"
    mkdir -p /root/.ssh
    echo "Host *" > /root/.ssh/config
    echo "    StrictHostKeyChecking no" >> /root/.ssh/config
    echo "    UserKnownHostsFile=/dev/null" >> /root/.ssh/config
    chmod 600 /root/.ssh/config
elif [ -f "/ssh-key/known_hosts" ]; then
    log "Using known_hosts from mounted volume"
    cp /ssh-key/known_hosts /root/.ssh/known_hosts
    chmod 644 /root/.ssh/known_hosts
else
    log "Automatically adding host key to known_hosts"
    ssh-keyscan -p "$SSH_REMOTE_PORT" -H "$SSH_REMOTE_HOST" >> /root/.ssh/known_hosts 2>/dev/null || warning "Failed to add host key automatically"
fi

# Build SSH tunnel arguments based on tunnel type
TUNNEL_ARGS=""

# Check if multiple tunnels are defined (new method)
if [ -n "$SSH_TUNNELS" ]; then
    # Multiple tunnels mode - SSH_TUNNELS contains multiple tunnel definitions
    # Format: "R:8080:localhost:8080,R:25565:localhost:25565,L:3306:dbhost:3306"
    log "Multiple tunnels mode enabled"
    
    IFS=',' read -ra TUNNEL_ARRAY <<< "$SSH_TUNNELS"
    TUNNEL_COUNT=0
    
    for tunnel_def in "${TUNNEL_ARRAY[@]}"; do
        # Trim whitespace
        tunnel_def=$(echo "$tunnel_def" | xargs)
        
        # Parse tunnel definition: TYPE:ARG1:ARG2:ARG3
        IFS=':' read -ra TUNNEL_PARTS <<< "$tunnel_def"
        
        tunnel_type="${TUNNEL_PARTS[0]}"
        
        case "$tunnel_type" in
            R|remote)
                # Remote tunnel: R:remote_port:target_host:target_port
                remote_port="${TUNNEL_PARTS[1]}"
                target_host="${TUNNEL_PARTS[2]:-localhost}"
                target_port="${TUNNEL_PARTS[3]}"
                
                if [ -z "$remote_port" ] || [ -z "$target_port" ]; then
                    error "Invalid remote tunnel definition: $tunnel_def"
                    exit 1
                fi
                
                TUNNEL_ARGS="$TUNNEL_ARGS -R ${remote_port}:${target_host}:${target_port}"
                log "  Remote tunnel: VPS:${remote_port} -> ${target_host}:${target_port}"
                TUNNEL_COUNT=$((TUNNEL_COUNT + 1))
                ;;
            L|local)
                # Local tunnel: L:local_port:target_host:target_port
                local_port="${TUNNEL_PARTS[1]}"
                target_host="${TUNNEL_PARTS[2]:-localhost}"
                target_port="${TUNNEL_PARTS[3]}"
                
                if [ -z "$local_port" ] || [ -z "$target_port" ]; then
                    error "Invalid local tunnel definition: $tunnel_def"
                    exit 1
                fi
                
                TUNNEL_ARGS="$TUNNEL_ARGS -L ${local_port}:${target_host}:${target_port}"
                log "  Local tunnel: localhost:${local_port} -> ${target_host}:${target_port}"
                TUNNEL_COUNT=$((TUNNEL_COUNT + 1))
                ;;
            D|dynamic)
                # Dynamic tunnel: D:local_port
                local_port="${TUNNEL_PARTS[1]}"
                
                if [ -z "$local_port" ]; then
                    error "Invalid dynamic tunnel definition: $tunnel_def"
                    exit 1
                fi
                
                TUNNEL_ARGS="$TUNNEL_ARGS -D ${local_port}"
                log "  Dynamic tunnel (SOCKS): localhost:${local_port}"
                TUNNEL_COUNT=$((TUNNEL_COUNT + 1))
                ;;
            *)
                error "Unknown tunnel type in definition: $tunnel_def"
                exit 1
                ;;
        esac
    done
    
    log "Configured $TUNNEL_COUNT tunnel(s)"
    
elif [ "$SSH_TUNNEL_TYPE" == "remote" ] || [ "$SSH_TUNNEL_TYPE" == "R" ]; then
    # Single remote tunnel (backward compatibility)
    if [ -z "$SSH_TUNNEL_LOCAL_PORT" ] || [ -z "$SSH_TUNNEL_REMOTE_PORT" ]; then
        error "SSH_TUNNEL_LOCAL_PORT and SSH_TUNNEL_REMOTE_PORT are required for remote tunnel"
        exit 1
    fi
    TUNNEL_ARGS="-R ${SSH_TUNNEL_REMOTE_PORT}:${SSH_TUNNEL_REMOTE_HOST}:${SSH_TUNNEL_LOCAL_PORT}"
    log "Setting up REMOTE tunnel: Remote port ${SSH_TUNNEL_REMOTE_PORT} -> ${SSH_TUNNEL_REMOTE_HOST}:${SSH_TUNNEL_LOCAL_PORT}"
    
elif [ "$SSH_TUNNEL_TYPE" == "local" ] || [ "$SSH_TUNNEL_TYPE" == "L" ]; then
    # Single local tunnel (backward compatibility)
    if [ -z "$SSH_TUNNEL_LOCAL_PORT" ] || [ -z "$SSH_TUNNEL_REMOTE_PORT" ]; then
        error "SSH_TUNNEL_LOCAL_PORT and SSH_TUNNEL_REMOTE_PORT are required for local tunnel"
        exit 1
    fi
    TUNNEL_ARGS="-L ${SSH_TUNNEL_LOCAL_PORT}:${SSH_TUNNEL_REMOTE_HOST}:${SSH_TUNNEL_REMOTE_PORT}"
    log "Setting up LOCAL tunnel: Local port ${SSH_TUNNEL_LOCAL_PORT} -> ${SSH_TUNNEL_REMOTE_HOST}:${SSH_TUNNEL_REMOTE_PORT}"
    
elif [ "$SSH_TUNNEL_TYPE" == "dynamic" ] || [ "$SSH_TUNNEL_TYPE" == "D" ]; then
    # Single dynamic tunnel (backward compatibility)
    if [ -z "$SSH_TUNNEL_LOCAL_PORT" ]; then
        error "SSH_TUNNEL_LOCAL_PORT is required for dynamic tunnel"
        exit 1
    fi
    TUNNEL_ARGS="-D ${SSH_TUNNEL_LOCAL_PORT}"
    log "Setting up DYNAMIC tunnel (SOCKS proxy) on port ${SSH_TUNNEL_LOCAL_PORT}"
    
elif [ "$SSH_TUNNEL_TYPE" == "custom" ]; then
    # Custom tunnel arguments
    if [ -z "$SSH_CUSTOM_TUNNEL_ARGS" ]; then
        error "SSH_CUSTOM_TUNNEL_ARGS is required when SSH_TUNNEL_TYPE is 'custom'"
        exit 1
    fi
    TUNNEL_ARGS="$SSH_CUSTOM_TUNNEL_ARGS"
    log "Using custom tunnel arguments: $TUNNEL_ARGS"
else
    error "Invalid SSH_TUNNEL_TYPE: $SSH_TUNNEL_TYPE. Valid options: remote, local, dynamic, custom"
    exit 1
fi

# Build the SSH command (without 'ssh' keyword as autossh invokes it)
SSH_CMD="-N -T"
SSH_CMD="$SSH_CMD -p $SSH_REMOTE_PORT"
SSH_CMD="$SSH_CMD $TUNNEL_ARGS"

# Add extra SSH arguments if provided
if [ -n "$SSH_EXTRA_ARGS" ]; then
    SSH_CMD="$SSH_CMD $SSH_EXTRA_ARGS"
    log "Extra SSH arguments: $SSH_EXTRA_ARGS"
fi

# Add user@host
SSH_CMD="$SSH_CMD ${SSH_REMOTE_USER}@${SSH_REMOTE_HOST}"

# Display configuration
log "========================================="
log "Porthole SSH Tunnel Configuration"
log "========================================="
log "Remote Host: ${SSH_REMOTE_USER}@${SSH_REMOTE_HOST}:${SSH_REMOTE_PORT}"
log "Tunnel Type: ${SSH_TUNNEL_TYPE}"
log "AutoSSH Poll Interval: ${AUTOSSH_POLL}s"
log "AutoSSH First Poll: ${AUTOSSH_FIRST_POLL}s"
log "AutoSSH Log Level: ${AUTOSSH_LOGLEVEL}"
log "Timezone: ${TZ}"
log "========================================="

# Test SSH connection first
log "Testing SSH connection..."
if ssh -o ConnectTimeout=10 -o BatchMode=yes -p "$SSH_REMOTE_PORT" "${SSH_REMOTE_USER}@${SSH_REMOTE_HOST}" exit 2>/dev/null; then
    log "SSH connection test successful"
else
    warning "SSH connection test failed, but will continue (this may be due to server configuration)"
fi

# Start autossh
log "Starting autossh with command: autossh -M ${AUTOSSH_PORT} ${SSH_CMD}"
log "Tunnel is now active..."

# Execute autossh with the constructed command
exec autossh -M "${AUTOSSH_PORT}" ${SSH_CMD}
