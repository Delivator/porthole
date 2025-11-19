# Quick Start Guide

This guide will help you get Porthole up and running in 5 minutes.

## Scenario: Expose NAS Web Interface Through VPS

### Prerequisites

- A VPS or public server with SSH access
- Docker installed on your NAS or local machine
- SSH key pair (or we'll create one)

### Step 1: Clone and Setup

```bash
git clone https://github.com/Delivator/porthole.git
cd porthole
```

### Step 2: Create SSH Key (if you don't have one)

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -f ./ssh-keys/id_rsa -N ""

# Copy public key to your VPS
ssh-copy-id -i ./ssh-keys/id_rsa.pub your-user@your-vps.com
```

### Step 3: Configure Environment

```bash
# Copy example configuration
cp .env.example .env

# Edit configuration
nano .env
```

Set these required values in `.env`:
```bash
SSH_REMOTE_HOST=your-vps.com
SSH_REMOTE_USER=your-username
SSH_TUNNEL_LOCAL_PORT=8080    # Your NAS web interface port
SSH_TUNNEL_REMOTE_PORT=8080   # Port on VPS to access it
```

### Step 4: Start the Tunnel

```bash
# Build and start
docker-compose up -d

# Check logs
docker-compose logs -f
```

You should see:
```
[Porthole] Setting up SSH private key from mounted volume
[Porthole] Setting up REMOTE tunnel: Remote port 8080 -> localhost:8080
[Porthole] Tunnel is now active...
```

### Step 5: Test Access

Access your NAS web interface through your VPS:
```
http://your-vps.com:8080
```

### Stopping the Tunnel

```bash
docker-compose down
```

## Common Configurations

### Multiple Services (Recommended - Single Container)

**NEW:** Use `SSH_TUNNELS` to run multiple tunnels in one container (much more efficient!):

```bash
# In .env
SSH_TUNNELS=R:8080:localhost:80,R:8443:localhost:443,R:2222:localhost:22
```

Or in docker-compose.yml:

```yaml
environment:
  SSH_REMOTE_HOST: vps.example.com
  SSH_REMOTE_USER: myuser
  # Multiple tunnels in ONE container - efficient!
  SSH_TUNNELS: R:8080:localhost:80,R:8443:localhost:443,R:2222:localhost:22
```

This exposes:
- Web server on VPS:8080 → local:80
- HTTPS on VPS:8443 → local:443  
- SSH on VPS:2222 → local:22

### Multiple Services (Legacy - Multiple Containers)

If you prefer separate containers (less efficient):

```yaml
services:
  # Web interface
  porthole-web:
    build: .
    image: porthole:latest
    restart: unless-stopped
    environment:
      SSH_REMOTE_HOST: ${SSH_REMOTE_HOST}
      SSH_REMOTE_USER: ${SSH_REMOTE_USER}
      SSH_TUNNEL_TYPE: remote
      SSH_TUNNEL_LOCAL_PORT: 80
      SSH_TUNNEL_REMOTE_PORT: 8080
    volumes:
      - ./ssh-keys:/ssh-key:ro
    network_mode: host

  # SSH access
  porthole-ssh:
    build: .
    image: porthole:latest
    restart: unless-stopped
    environment:
      SSH_REMOTE_HOST: ${SSH_REMOTE_HOST}
      SSH_REMOTE_USER: ${SSH_REMOTE_USER}
      SSH_TUNNEL_TYPE: remote
      SSH_TUNNEL_LOCAL_PORT: 22
      SSH_TUNNEL_REMOTE_PORT: 2222
    volumes:
      - ./ssh-keys:/ssh-key:ro
    network_mode: host
```

### SOCKS Proxy

For a SOCKS proxy (secure browsing):

```bash
# In .env
SSH_TUNNEL_TYPE=dynamic
SSH_TUNNEL_LOCAL_PORT=1080
```

Then configure your browser to use `localhost:1080` as SOCKS5 proxy.

## Troubleshooting

### Connection refused

1. Check VPS firewall allows the remote port
2. Verify SSH key is correct
3. Test SSH manually: `ssh -i ./ssh-keys/id_rsa user@vps.com`

### Tunnel not forwarding

1. Verify local service is running
2. Check port numbers are correct
3. Ensure network_mode is set appropriately

### Auto-reconnect issues

Adjust monitoring in `.env`:
```bash
AUTOSSH_POLL=30
AUTOSSH_LOGLEVEL=3
```

## Security Best Practices

1. Use SSH keys, never passwords
2. Restrict VPS firewall to only needed ports
3. Use strong SSH key (4096-bit RSA or ED25519)
4. Enable `SSH_STRICT_HOST_KEY_CHECKING=yes` in production
5. Regularly update the Docker image

## Getting Help

- Check [README.md](README.md) for full documentation
- Review [examples/](examples/) directory
- Open an issue on GitHub
