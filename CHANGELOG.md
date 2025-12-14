# Changelog

All notable changes to kagglelink will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Fixed interactive prompt during `gum` package installation (added `--yes` to gpg command) to support re-running setup in non-interactive environments.

## [1.1.0] - 2025-12-07

### Added
- **Docker-based test environment** for isolated testing (Dockerfile.test, docker-compose.test.yml)
- **Bats testing framework** with comprehensive unit and integration tests
- **GitHub Actions CI/CD pipeline** running tests on every PR and push
- **Unit tests** for argument parsing, environment filtering, SSH permissions, URL validation, version tracking
- **Integration tests** for idempotency, SSH configuration, and fixture-based validation
- Development strategy documentation in architecture.md
- Branch strategy (main/develop/feature) for safer deployments
- CHANGELOG.md for tracking releases

### Changed
- GitHub Actions now runs Docker-containerized tests on both `main` and `develop` branches
- Development workflow now requires passing tests before merge to main
- Test environment mirrors Kaggle's Debian runtime (python:3.10-slim-bullseye)

### Developer Experience
- Fish/zsh users can now develop safely (tests run in isolated bash container)
- Zero risk of developer machine contamination from sudo operations
- Identical test environment across local development and CI/CD

### Technical Debt Deferred
- Version pinning for Zrok binary (moved to future epic)
- Idempotency improvements for sshd_config (moved to future epic)
- Profile.d integration for environment variables (moved to future epic)

## [1.0.0] - 2025-12-05

Initial stable release with active users.

### Features
- One-line curl setup for Kaggle notebooks
- Secure Zrok tunnel for SSH access
- RSA 4096-bit key-based authentication
- Environment variable propagation for GPU access
- VS Code Remote-SSH support
- Automatic dependency installation (openssh-server, zrok, nvtop, screen, lshw, uv)
- VS Code extension installation support
- Idempotent configuration (partial)

### Known Limitations
- Environment variable setup appends to .bashrc (not fully idempotent)
- No version checking in scripts
- No rollback mechanism
- Limited test coverage

---

## Release Guidelines

### Version Numbering
- **Major (X.0.0)**: Breaking changes requiring user migration
- **Minor (1.X.0)**: New features, backward compatible
- **Patch (1.0.X)**: Bug fixes only

### Release Process
1. Update version in `setup.sh`: `KAGGLELINK_VERSION="X.Y.Z"`
2. Update this CHANGELOG with release date
3. Commit: `git commit -am "Release vX.Y.Z"`
4. Tag: `git tag -a vX.Y.Z -m "Release X.Y.Z"`
5. Push: `git push origin main --tags`
6. Create GitHub Release with changelog excerpt

### Changelog Categories
- **Added**: New features
- **Changed**: Changes in existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security improvements
