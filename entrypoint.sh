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
    echo "$SSH_PRIVATE_KEY" > /root/.ssh/id_ed25519
    chmod 600 /root/.ssh/id_ed25519
elif [ -f "/ssh-key/id_ed25519" ]; then
    log "Using SSH private key (id_ed25519) from mounted volume"
    cp /ssh-key/id_ed25519 /root/.ssh/id_ed25519
    chmod 600 /root/.ssh/id_ed25519
elif [ -f "/ssh-key/id_ecdsa" ]; then
    log "Using SSH private key (id_ecdsa) from mounted volume"
    cp /ssh-key/id_ecdsa /root/.ssh/id_ecdsa
    chmod 600 /root/.ssh/id_ecdsa
elif [ -f "/ssh-key/id_rsa" ]; then
    log "Using SSH private key (id_rsa) from mounted volume"
    cp /ssh-key/id_rsa /root/.ssh/id_rsa
    chmod 600 /root/.ssh/id_rsa
else
    error "No SSH private key provided. Please provide either SSH_PRIVATE_KEY environment variable or mount key (id_rsa, id_ed25519, or id_ecdsa) to /ssh-key/"
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
        
        # Parse tunnel definition by splitting on colon
        IFS=':' read -ra TUNNEL_PARTS <<< "$tunnel_def"
        
        tunnel_type="${TUNNEL_PARTS[0]}"
        
        case "$tunnel_type" in
            R|remote)
                # SYNTAX 1 (5 parts): R:bind_ip:remote_port:target_host:target_port
                if [ "${#TUNNEL_PARTS[@]}" -eq 5 ]; then
                    bind_ip="${TUNNEL_PARTS[1]}"
                    remote_port="${TUNNEL_PARTS[2]}"
                    target_host="${TUNNEL_PARTS[3]:-localhost}"
                    target_port="${TUNNEL_PARTS[4]}"
                    
                    TUNNEL_ARGS="$TUNNEL_ARGS -R ${bind_ip}:${remote_port}:${target_host}:${target_port}"
                    log "  Remote tunnel: VPS:${bind_ip}:${remote_port} -> ${target_host}:${target_port}"

                # SYNTAX 2 (4 parts): R:remote_port:target_host:target_port
                elif [ "${#TUNNEL_PARTS[@]}" -eq 4 ]; then
                    remote_port="${TUNNEL_PARTS[1]}"
                    target_host="${TUNNEL_PARTS[2]:-localhost}"
                    target_port="${TUNNEL_PARTS[3]}"
                    
                    TUNNEL_ARGS="$TUNNEL_ARGS -R ${remote_port}:${target_host}:${target_port}"
                    log "  Remote tunnel: VPS:${remote_port} -> ${target_host}:${target_port}"
                else
                    error "Invalid remote tunnel definition (wrong part count): $tunnel_def"
                    exit 1
                fi
                TUNNEL_COUNT=$((TUNNEL_COUNT + 1))
                ;;

            L|local)
                # SYNTAX 1 (5 parts): L:bind_ip:local_port:target_host:target_port
                # Essential if you want other containers to reach this tunnel!
                if [ "${#TUNNEL_PARTS[@]}" -eq 5 ]; then
                    bind_ip="${TUNNEL_PARTS[1]}"
                    local_port="${TUNNEL_PARTS[2]}"
                    target_host="${TUNNEL_PARTS[3]:-localhost}"
                    target_port="${TUNNEL_PARTS[4]}"
                    
                    TUNNEL_ARGS="$TUNNEL_ARGS -L ${bind_ip}:${local_port}:${target_host}:${target_port}"
                    log "  Local tunnel: ${bind_ip}:${local_port} -> ${target_host}:${target_port}"

                # SYNTAX 2 (4 parts): L:local_port:target_host:target_port
                elif [ "${#TUNNEL_PARTS[@]}" -eq 4 ]; then
                    local_port="${TUNNEL_PARTS[1]}"
                    target_host="${TUNNEL_PARTS[2]:-localhost}"
                    target_port="${TUNNEL_PARTS[3]}"
                    
                    TUNNEL_ARGS="$TUNNEL_ARGS -L ${local_port}:${target_host}:${target_port}"
                    log "  Local tunnel: localhost:${local_port} -> ${target_host}:${target_port}"
                else
                    error "Invalid local tunnel definition (wrong part count): $tunnel_def"
                    exit 1
                fi
                TUNNEL_COUNT=$((TUNNEL_COUNT + 1))
                ;;

            D|dynamic)
                # SYNTAX 1 (3 parts): D:bind_ip:local_port
                # Essential for sharing SOCKS proxy with other containers
                if [ "${#TUNNEL_PARTS[@]}" -eq 3 ]; then
                    bind_ip="${TUNNEL_PARTS[1]}"
                    local_port="${TUNNEL_PARTS[2]}"
                    
                    TUNNEL_ARGS="$TUNNEL_ARGS -D ${bind_ip}:${local_port}"
                    log "  Dynamic tunnel (SOCKS): ${bind_ip}:${local_port}"

                # SYNTAX 2 (2 parts): D:local_port
                elif [ "${#TUNNEL_PARTS[@]}" -eq 2 ]; then
                    local_port="${TUNNEL_PARTS[1]}"
                    
                    TUNNEL_ARGS="$TUNNEL_ARGS -D ${local_port}"
                    log "  Dynamic tunnel (SOCKS): localhost:${local_port}"
                else
                    error "Invalid dynamic tunnel definition (wrong part count): $tunnel_def"
                    exit 1
                fi
                TUNNEL_COUNT=$((TUNNEL_COUNT + 1))
                ;;

            *)
                error "Unknown tunnel type in definition: $tunnel_def"
                exit 1
                ;;
        esac
    done
    
    log "Configured $TUNNEL_COUNT tunnel(s)"
else
    error "Invalid SSH_TUNNELS: Valid options: "R:remote_port:target_host:target_port", "L:local_port:target_host:target_port", "D:local_port" or multiple tunnels separated by commas"
    exit 1
fi

# Build the SSH command (without 'ssh' keyword as autossh invokes it)
SSH_CMD="-N -T"
SSH_CMD="$SSH_CMD -p $SSH_REMOTE_PORT"
SSH_CMD="$SSH_CMD $TUNNEL_ARGS"

# Add user@host
SSH_CMD="$SSH_CMD ${SSH_REMOTE_USER}@${SSH_REMOTE_HOST}"

# Display configuration
log "========================================="
log "Porthole SSH Tunnel Configuration"
log "========================================="
log "Remote Host: ${SSH_REMOTE_USER}@${SSH_REMOTE_HOST}:${SSH_REMOTE_PORT}"
log "Tunnels: ${SSH_TUNNELS}"
# Add extra SSH arguments if provided
if [ -n "$SSH_EXTRA_ARGS" ]; then
    SSH_CMD="$SSH_CMD $SSH_EXTRA_ARGS"
    log "Extra SSH arguments: $SSH_EXTRA_ARGS"
fi
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
