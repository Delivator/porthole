# Changelog

All notable changes to Porthole will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Multiple tunnels in single container**: New `SSH_TUNNELS` environment variable to define multiple tunnels efficiently
  - Format: `R:8080:localhost:80,R:25565:localhost:25565,L:3306:dbhost:3306`
  - Supports remote (R), local (L), and dynamic (D) tunnels in any combination
  - Much more efficient than running multiple containers
- New example: `docker-compose.multi-tunnel-efficient.yml` demonstrating multiple tunnels

### Changed
- Updated documentation to recommend multiple tunnels approach over multiple containers
- Enhanced README.md with multiple tunnels configuration section
- Updated QUICKSTART.md to show efficient multi-tunnel setup

### Fixed
- Fixed autossh command construction (removed 'ssh' keyword from SSH_CMD variable)

## [1.0.0] - 2025-11-12

### Added
- Initial release of Porthole containerized SSH tunnel
- Docker container based on Alpine Linux with autossh
- Multiple tunnel types support:
  - Remote tunnels (-R) for exposing local services
  - Local tunnels (-L) for accessing remote services
  - Dynamic tunnels (-D) for SOCKS proxy
  - Custom tunnels for advanced configurations
- Comprehensive environment variable configuration
- AutoSSH integration for automatic reconnection
- SSH key-based authentication (file or environment variable)
- Docker Compose deployment configuration
- Complete documentation:
  - README.md with full documentation
  - QUICKSTART.md for quick setup
  - IMPLEMENTATION.md with technical details
- Example configurations:
  - NAS web server exposure
  - Multiple services tunneling
  - SOCKS proxy setup
  - Custom tunnel configurations
- Validation and testing scripts:
  - validate.sh for configuration validation
  - test.sh for Docker build testing
- Security features:
  - .gitignore to protect sensitive files
  - Proper SSH key permissions (600)
  - Configurable strict host key checking
  - No secrets in Docker image
- NAS-friendly deployment (Synology, QNAP, etc.)
- Host and bridge network mode support
- Timezone configuration support
- Comprehensive logging with color-coded output

### Security
- Mandatory SSH key authentication
- Protected SSH keys in .gitignore
- Minimal Alpine-based container image
- Isolated SSH configuration
- Environment variable-based secrets management

[1.0.0]: https://github.com/Delivator/porthole/releases/tag/v1.0.0
