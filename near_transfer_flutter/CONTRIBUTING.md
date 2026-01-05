# Contributing to NearTransfer

Thank you for your interest in contributing to NearTransfer! This document provides guidelines for contributing to the project.

## 📋 Code of Conduct

Please be respectful and considerate in all interactions. We are committed to providing a welcoming and inclusive environment for everyone.

## 🔧 Development Setup

### Prerequisites

- Flutter SDK 3.9.2 or higher
- Dart SDK 3.0 or higher
- Android Studio or VS Code with Flutter extensions
- Git

### Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/neartransfer_flutter.git
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Create a new branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## 📝 Commit Guidelines

We follow conventional commit messages:

### Format
```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### Examples
```
feat(transfer): add pause/resume functionality for large files
fix(discovery): resolve UDP broadcast timeout on Android 12+
docs(readme): update installation instructions
perf(streaming): optimize chunk size for faster transfers
refactor(services): extract signaling logic to separate service
```

## 🏗️ Architecture Guidelines

### Feature Structure
```
lib/features/<feature_name>/
├── screens/           # UI screens
├── widgets/           # Feature-specific widgets
├── providers/         # State management (if needed)
└── services/          # Feature-specific services (if needed)
```

### Shared Components
- Place reusable widgets in `lib/shared/widgets/`
- Place shared services in `lib/shared/services/`
- Place data models in `lib/shared/models/`

### Naming Conventions
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Functions/Variables: `camelCase`
- Constants: `SCREAMING_SNAKE_CASE` or `kCamelCase`

## 🧪 Testing

- Write unit tests for services and utilities
- Write widget tests for UI components
- Write integration tests for critical flows

Run tests:
```bash
flutter test
```

## 📤 Pull Request Process

1. Ensure all tests pass
2. Update documentation if needed
3. Follow the commit guidelines
4. Create a detailed PR description
5. Request review from maintainers

## 📄 License

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

Thank you for contributing! 🎉
