# Porthole 🚢

A highly configurable containerized SSH tunnel using autossh. Perfect for exposing local services (like those on a NAS) through a remote VPS without port forwarding, protecting your personal IP while making services accessible from anywhere.

## Features

- 🔒 **Secure SSH tunneling** with autossh for automatic reconnection
- 🎯 **Multiple tunnel types**: Remote, Local, Dynamic (SOCKS), and Custom
- 🔧 **Highly configurable** through environment variables
- 🐳 **Easy deployment** with Docker and Docker Compose
- 🔄 **Auto-reconnect** with configurable monitoring and health checks
- 📦 **Lightweight** Alpine-based image
- 🏠 **NAS-friendly** designed for Synology, QNAP, and other NAS environments
- 🌐 **Network flexible** supports both host and bridge networking modes

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- SSH access to a remote server (VPS or public server)
- SSH key pair for authentication

### Basic Setup

1. **Clone this repository:**
   ```bash
   git clone https://github.com/Delivator/porthole.git
   cd porthole
   ```

2. **Create SSH keys directory and add your private key:**
   ```bash
   mkdir -p ssh-keys
   # Copy your existing key or generate a new one
   ssh-keygen -t ed25519 -f ./ssh-keys/id_ed25519 -N "" -C "porthole-tunnel-key"
   chmod 600 ssh-keys/id_ed25519
   ```

3. **Copy your public key to the remote server:**
   ```bash
   ssh-copy-id -i ./ssh-keys/id_ed25519.pub user@your-vps.com
   ```

4. **Configure your tunnel:**
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   nano .env
   ```

5. **Start the tunnel:**
   ```bash
   docker-compose up -d
   ```

6. **Check logs:**
   ```bash
   docker-compose logs -f
   ```

## Configuration

### Environment Variables

#### Required Settings

| Variable | Description | Example |
|----------|-------------|---------|
| `SSH_REMOTE_HOST` | Remote SSH server hostname or IP | `vps.example.com` |
| `SSH_REMOTE_USER` | Remote SSH server username | `myuser` |
| `SSH_REMOTE_PORT` | Remote SSH server port | `22` |

#### Tunnel Configuration

**Multiple Tunnels**

Use `SSH_TUNNELS` to define multiple tunnels in a single container:

| Variable | Description | Example |
|----------|-------------|---------|
| `SSH_TUNNELS` | Comma-separated list of tunnel definitions | `R:8080:localhost:80,R:25565:localhost:25565` |

Format: `TYPE:ARG1:ARG2:ARG3,TYPE:ARG1:ARG2:ARG3,...`

- **Remote tunnel**: `R:remote_port:target_host:target_port` or `remote:remote_port:target_host:target_port`
- **Local tunnel**: `L:local_port:target_host:target_port` or `local:local_port:target_host:target_port`
- **Dynamic tunnel**: `D:local_port` or `dynamic:local_port`

Examples:
```bash
# Single remote tunnel
SSH_TUNNELS=R:8080:localhost:80

# Multiple remote tunnels (web + minecraft server)
SSH_TUNNELS=R:8080:localhost:80,R:25565:localhost:25565,R:8443:localhost:443

# Mixed tunnels (remote + local + SOCKS)
SSH_TUNNELS=R:8080:localhost:80,L:3306:dbhost:3306,D:1080
```

**Single Tunnel (Legacy mode)**

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `SSH_TUNNEL_TYPE` | Type of tunnel: `remote`, `local`, `dynamic`, `custom` | `remote` | `remote` |
| `SSH_TUNNEL_LOCAL_PORT` | Local port to tunnel | - | `8080` |
| `SSH_TUNNEL_REMOTE_PORT` | Remote port to expose/connect | - | `8080` |
| `SSH_TUNNEL_REMOTE_HOST` | Remote endpoint host | `localhost` | `localhost` |
| `SSH_CUSTOM_TUNNEL_ARGS` | Custom SSH tunnel arguments (when type=custom) | - | `-R 8080:localhost:80` |

#### SSH Authentication

| Variable | Description | Default |
|----------|-------------|---------|
| `SSH_PRIVATE_KEY` | SSH private key as environment variable (alternative to volume mount) | - |
| `SSH_STRICT_HOST_KEY_CHECKING` | Enable strict host key checking | `no` |
| `SSH_EXTRA_ARGS` | Additional SSH arguments | - |

#### AutoSSH Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `AUTOSSH_POLL` | Poll interval in seconds | `60` |
| `AUTOSSH_FIRST_POLL` | First poll delay in seconds | `30` |
| `AUTOSSH_GATETIME` | Gateway timeout (0=disabled) | `0` |
| `AUTOSSH_PORT` | Monitoring port (0=disabled) | `0` |
| `AUTOSSH_LOGLEVEL` | Log level (0-3) | `1` |

### Tunnel Types

#### Remote Tunnel (`-R`)
Expose a local service on the remote server. Perfect for NAS deployments.

```yaml
SSH_TUNNEL_TYPE=remote
SSH_TUNNEL_LOCAL_PORT=8080        # Local service port
SSH_TUNNEL_REMOTE_PORT=8080       # Port on VPS to listen on
SSH_TUNNEL_REMOTE_HOST=localhost  # Usually localhost
```

**Use case:** Access your NAS web interface through your VPS
```
Internet → VPS:8080 → SSH Tunnel → NAS:8080
```

#### Local Tunnel (`-L`)
Access a remote service locally.

```yaml
SSH_TUNNEL_TYPE=local
SSH_TUNNEL_LOCAL_PORT=3306        # Local port to listen on
SSH_TUNNEL_REMOTE_PORT=3306       # Remote service port
SSH_TUNNEL_REMOTE_HOST=localhost  # Or internal hostname
```

**Use case:** Access a remote database securely
```
localhost:3306 → SSH Tunnel → VPS → Database:3306
```

#### Dynamic Tunnel (`-D`)
Create a SOCKS proxy for secure browsing.

```yaml
SSH_TUNNEL_TYPE=dynamic
SSH_TUNNEL_LOCAL_PORT=1080  # SOCKS proxy port
```

**Use case:** Route browser traffic through VPS
```
Browser → SOCKS:1080 → SSH Tunnel → VPS → Internet
```

#### Custom Tunnel
Define your own tunnel arguments for complex setups.

```yaml
SSH_TUNNEL_TYPE=custom
SSH_CUSTOM_TUNNEL_ARGS=-R 8080:localhost:80 -R 8443:localhost:443 -L 3306:db.internal:3306
```

## Use Cases

### 1. NAS Web Interface Exposure

Expose your NAS web interface through a VPS without opening ports on your home network:

```yaml
environment:
  SSH_REMOTE_HOST: vps.example.com
  SSH_REMOTE_USER: myuser
  SSH_TUNNEL_TYPE: remote
  SSH_TUNNELS: R:8080:localhost:5000 # NAS web interface (port 5000) → VPS port 8080, access via vps.example.com:8080
```

### 2. Multiple Services

**NEW:** Use `SSH_TUNNELS` to expose multiple services:

```yaml
environment:
  SSH_REMOTE_HOST: vps.example.com
  SSH_REMOTE_USER: myuser
  # Multiple tunnels in ONE container!
  SSH_TUNNELS: R:8080:localhost:80,R:8443:localhost:443,R:25565:localhost:25565
```

**Example tunnels:**
- Web server (local:80 → VPS:8080)
- HTTPS (local:443 → VPS:8443)
- Minecraft server (local:25565 → VPS:25565)

### 3. Secure Remote Access

Create a SOCKS proxy for secure browsing:

```yaml
environment:
  SSH_TUNNEL_TYPE: dynamic
  SSH_TUNNEL_LOCAL_PORT: 1080
```

Configure your browser to use `localhost:1080` as SOCKS5 proxy.

### 4. Development Environment

Access internal development services:

```yaml
environment:
  SSH_TUNNEL_REMOTE_HOST: db.internal.example.com
  SSH_TUNNELS: L:5432:db.internal.example.com:5432 # Local port 5432 → Remote DB
```

## Examples

See the `examples/` directory for complete configurations:

- `docker-compose.nas-webserver.yml` - Single web server exposure
- `docker-compose.multiple-services.yml` - Multiple service tunnels
- `docker-compose.socks-proxy.yml` - SOCKS proxy setup
- `docker-compose.custom-tunnel.yml` - Custom tunnel configuration

## Deployment on NAS

### Synology NAS

1. Install Docker package from Package Center
2. Create a new folder in File Station for Porthole
3. Upload files via File Station or use git
4. Open Docker app, go to Image, and build from Dockerfile
5. Create container using your docker-compose.yml configuration

Or use SSH to deploy directly:

```bash
ssh admin@nas-ip
cd /volume1/docker/porthole
git clone https://github.com/Delivator/porthole.git .
# Configure .env and ssh-keys/id_ed25519
docker-compose up -d
```

### QNAP NAS

1. Install Container Station
2. Create a new application using the docker-compose.yml
3. Configure environment variables in Container Station UI
4. Mount SSH key volume
5. Start the container

### Other NAS Systems

Most modern NAS systems support Docker. Follow your NAS documentation for Docker deployment, then use the provided docker-compose.yml file.

## Security Considerations

1. **SSH Keys**: Always use SSH key authentication, never passwords
2. **Key Protection**: Never commit private keys to git - they're in `.gitignore`
3. **Host Key Checking**: Enable `SSH_STRICT_HOST_KEY_CHECKING=yes` in production
4. **Firewall**: Only expose necessary ports on your VPS
5. **Updates**: Regularly update the container image
6. **Monitoring**: Check logs regularly for unauthorized access attempts

## Troubleshooting

### Connection Fails

```bash
# Check logs
docker-compose logs -f

# Test SSH connection manually
docker-compose exec porthole ssh -p 22 user@vps.example.com

# Verify SSH key permissions
ls -la ssh-keys/
```

### Tunnel Not Working

1. Verify ports are correct
2. Check firewall rules on VPS
3. Ensure service is running on local port
4. Test with `curl localhost:LOCAL_PORT`
5. Check autossh logs for errors

### Auto-reconnect Issues

Adjust AutoSSH settings:

```yaml
AUTOSSH_POLL: 30          # Check more frequently
AUTOSSH_LOGLEVEL: 3       # Enable debug logging
SSH_EXTRA_ARGS: -o ServerAliveInterval=60 -o ServerAliveCountMax=3
```

## Building from Source

```bash
# Build the image
docker build -t porthole:latest .

# Or with docker-compose
docker-compose build
```

## Advanced Configuration

### Custom SSH Config

Mount a custom SSH config file:

```yaml
volumes:
  - ./ssh-keys:/ssh-key:ro
  - ./ssh_config:/root/.ssh/config:ro
```

### Using Environment Variable for SSH Key

Instead of mounting a file:

```yaml
environment:
  SSH_PRIVATE_KEY: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    your-private-key-here
    -----END OPENSSH PRIVATE KEY-----
```

### Health Checks

Add health check to docker-compose.yml:

```yaml
healthcheck:
  test: ["CMD", "pgrep", "autossh"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 10s
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [autossh](https://www.harding.motd.ca/autossh/) for reliable SSH tunneling
- Inspired by the need for secure, easy remote access to home services
- Thanks to the open-source community

## Support

If you encounter issues or have questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review the [examples](examples/) directory
3. Open an issue on GitHub

---

**Note**: Always ensure you comply with your VPS provider's terms of service and applicable laws when creating tunnels.
