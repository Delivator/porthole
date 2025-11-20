# Porthole - Implementation Summary

## Overview
Porthole is a containerized SSH tunnel solution using autossh, designed for exposing local services (especially on NAS devices) through a remote VPS without requiring port forwarding.

## Architecture

### Components
1. **Dockerfile**: Alpine Linux-based container with autossh, SSH client, and bash
2. **entrypoint.sh**: Intelligent startup script with validation and configuration
3. **docker-compose.yml**: Deployment orchestration
4. **Configuration**: Environment variable-based setup

### Tunnel Types Supported
1. **Remote Tunnel (-R)**: Expose local service on remote server
2. **Local Tunnel (-L)**: Access remote service locally
3. **Dynamic Tunnel (-D)**: SOCKS proxy
4. **Custom**: User-defined tunnel arguments

## Security Features

### Implemented
- ✅ SSH key-based authentication (mandatory)
- ✅ Private keys protected by .gitignore
- ✅ Proper file permissions (600 for private keys)
- ✅ Configurable strict host key checking
- ✅ No secrets in Docker image
- ✅ Minimal attack surface (Alpine base)
- ✅ Environment variables for sensitive data
- ✅ SSH config isolation

### Best Practices
- Private key can be provided via volume mount OR environment variable
- Default strict host checking disabled for ease of use (can be enabled)
- Clear error messages for missing credentials
- Automated host key scanning when needed

## Configuration Options

### Required
- `SSH_REMOTE_HOST`: Target SSH server
- `SSH_REMOTE_USER`: SSH username
- SSH private key (via volume or env var)

### Tunnel Configuration
- `SSH_TUNNEL_TYPE`: remote, local, dynamic, or custom
- `SSH_TUNNEL_LOCAL_PORT`: Local port number
- `SSH_TUNNEL_REMOTE_PORT`: Remote port number
- `SSH_TUNNEL_REMOTE_HOST`: Tunnel endpoint (default: localhost)
- `SSH_CUSTOM_TUNNEL_ARGS`: For complex setups

### AutoSSH Settings
- `AUTOSSH_POLL`: Connection check interval (default: 60s)
- `AUTOSSH_FIRST_POLL`: Initial check delay (default: 30s)
- `AUTOSSH_GATETIME`: Gateway timeout (default: 0)
- `AUTOSSH_PORT`: Monitoring port (default: 0)
- `AUTOSSH_LOGLEVEL`: Verbosity (0-3, default: 1)

### Advanced
- `SSH_EXTRA_ARGS`: Additional SSH options
- `SSH_STRICT_HOST_KEY_CHECKING`: Enable/disable (default: no)
- `TZ`: Container timezone (default: UTC)

## Use Cases

### 1. NAS Web Interface Exposure
Expose Synology/QNAP web interface through VPS
```
NAS:5000 → Tunnel → VPS:8080 → Public Access
```

### 2. Multiple Services
Run multiple tunnel containers for different services:
- Web servers
- Media servers (Plex, Jellyfin)
- SSH access
- Databases
- Home automation

### 3. Secure Remote Access
SOCKS proxy for secure browsing through VPS

### 4. Development Access
Access internal development resources remotely

## Deployment Scenarios

### Docker Compose (Standard)
```bash
docker-compose up -d
```

### Synology NAS
1. Docker package installation
2. Import docker-compose.yml
3. Configure via Container Manager UI

### QNAP NAS
1. Container Station
2. Create application from compose file
3. Configure environment variables

### Portainer
1. Add stack
2. Paste docker-compose.yml
3. Configure environment variables

## Testing

### Validation Script
```bash
./validate.sh
```
Checks:
- Shell script syntax
- Dockerfile structure
- docker-compose.yml syntax
- Required files presence
- Environment configuration
- Security settings (.gitignore)

### Build Test
```bash
./test.sh
```
Performs:
- Docker installation check
- Image build
- Package verification
- Entrypoint validation
- Error handling test

## Network Modes

### Host Network (Recommended for NAS)
Direct access to all local services without port mapping
```yaml
network_mode: host
```

### Bridge Network
Explicit port mapping for isolated environments
```yaml
ports:
  - "1080:1080"
```

## Monitoring and Troubleshooting

### Log Access
```bash
docker-compose logs -f
docker logs porthole-tunnel
```

### Common Issues
1. **Connection refused**: Check firewall, verify ports
2. **Authentication failed**: Verify SSH key and permissions
3. **Auto-reconnect not working**: Adjust AUTOSSH_POLL settings
4. **Service not accessible**: Verify tunnel type and ports

### Debug Mode
```yaml
AUTOSSH_LOGLEVEL: 3
SSH_EXTRA_ARGS: -vvv
```

## Performance

### Resource Usage
- **Image size**: ~50-60 MB (Alpine-based)
- **Memory**: ~10-20 MB runtime
- **CPU**: Minimal (idle most of time)
- **Network**: Depends on tunneled traffic

### Scalability
- Multiple tunnels: Multiple tunnels in a single container
- High availability: Use autossh automatic reconnection
- Load balancing: Not applicable (point-to-point tunnel)

## Limitations

1. Requires SSH access to remote server
2. Remote server must allow port forwarding (GatewayPorts)
3. Network latency adds to tunneled connections
4. Single point of failure (VPS availability)

## Future Enhancements (Potential)

- Health check endpoint
- Metrics/monitoring integration
- Web UI for configuration
- Multi-hop tunnel support
- WireGuard/OpenVPN alternatives
- Automatic VPS setup scripts

## License
MIT License - Free for personal and commercial use
