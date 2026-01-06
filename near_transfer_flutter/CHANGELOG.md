# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- iOS support
- macOS support
- Linux support
- Group transfer improvements
- Transfer resume across app restarts

---

## [1.0.0] - 2026-01-05

### Added
- **Core Features**
  - Direct TCP socket file transfer (10-50 MB/s)
  - HTTP fallback for reliable transfers
  - UDP broadcast device discovery
  - TCP subnet scanning for reliable detection

- **File Transfer**
  - Multi-file batch transfers
  - Real-time progress tracking with speed indicator
  - Pause/Resume functionality
  - Transfer history with SQLite persistence

- **App Sharing**
  - Share installed apps as APK files
  - Browse user and system applications
  - Quick search functionality

- **File Manager**
  - Built-in file explorer
  - Category filters (Images, Videos, Audio, Documents)
  - Multi-select for quick sharing

- **Clipboard Sync**
  - Cross-device text sharing
  - Auto-sync toggle
  - Clipboard history

- **Contact Sharing**
  - Export contacts to VCF format
  - Import contacts from other devices
  - Bulk transfer support

- **Additional Features**
  - Shake Connect (shake devices to pair)
  - Network Speed Test
  - Premium subscription (ad-free experience)
  - Background transfer service
  - Local notifications for transfer status

- **Platform Support**
  - Android (API 21+)
  - Windows 10+

### Technical
- Clean Architecture with feature-first structure
- Provider for state management
- SQLite with FFI for desktop support
- Google AdMob integration
- In-App Purchase support

---

## [0.1.0] - 2025-12-01

### Added
- Initial project setup
- Basic file transfer functionality
- Device discovery prototype

---

[Unreleased]: https://github.com/Nishanth619/file_share/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Nishanth619/file_share/releases/tag/v1.0.0
[0.1.0]: https://github.com/Nishanth619/file_share/releases/tag/v0.1.0
