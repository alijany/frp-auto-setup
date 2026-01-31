# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-31

### Added
- Initial release of FRP Auto Setup Script
- Automated FRP server installation and configuration
- Automated FRP client installation and configuration
- Auto-detection of system architecture (amd64, arm64, arm)
- Systemd service integration for both server and client
- Configurable installation via command-line arguments
- Environment variable support for version, architecture, and install directory
- Dashboard configuration with password protection
- Authentication token support for secure client-server communication
- Comprehensive error handling and user feedback
- Color-coded console output for better readability
- Log file management and rotation
- Examples for common use cases
- Quick start guide
- Detailed README with usage instructions

### Features
- Support for custom ports (server, HTTP, HTTPS, dashboard)
- Custom domain configuration for clients
- Flexible local port mapping
- Service monitoring and management via systemd
- Automatic service restart on failure
- Comprehensive logging

### Documentation
- README.md with full usage instructions
- QUICKSTART.md for rapid deployment
- SERVER.md with server configuration examples
- CLIENT.md with client configuration examples
- MIT License
- .gitignore for clean repository

### Security
- Required password for dashboard access
- Optional token-based authentication
- Service runs with configurable permissions
- Support for encrypted connections

[1.0.0]: https://github.com/YOUR_USERNAME/frp-auto-setup/releases/tag/v1.0.0
