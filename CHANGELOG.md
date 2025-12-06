# Changelog

All notable changes to kagglelink will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Development strategy documentation in architecture.md
- CI/CD pipeline for testing on main and develop branches
- Branch strategy (main/develop/feature) for safer deployments
- CHANGELOG.md for tracking releases

### Changed
- GitHub Actions now runs on both `main` and `develop` branches

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
