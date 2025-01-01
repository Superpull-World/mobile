# SuperPull Mobile

SuperPull Mobile is a Flutter application that allows users to create and manage NFT listings with dynamic bonding curves on the Solana blockchain.

## Features

- Create NFT listings with images and metadata
- Integrated Solana wallet management
- Dynamic pricing using bonding curves
- Secure storage of wallet credentials
- Modern and intuitive UI

## Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK (latest stable version)
- iOS development setup (for iOS builds):
  - Xcode (latest version)
  - CocoaPods
- Android development setup (for Android builds):
  - Android Studio
  - Android SDK
- A physical device or emulator for testing

## Getting Started

1. Clone the repository:
```bash
git clone <repository-url>
cd superpull_mobile
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart              # Application entry point
├── pages/                 # Screen implementations
│   ├── create_listing_page.dart
│   └── listings_page.dart
├── services/              # Business logic and services
│   ├── wallet_service.dart
│   └── workflow_service.dart
├── models/               # Data models
└── widgets/             # Reusable UI components
```

## Dependencies

The project uses the following main dependencies:

- `solana`: For Solana blockchain interactions
- `bip39`: For wallet mnemonic generation
- `flutter_secure_storage`: For secure storage of sensitive data
- `shared_preferences`: For local data persistence
- `http`: For API communications
- `image_picker`: For image selection functionality

For a complete list of dependencies, see the `pubspec.yaml` file.

## Configuration

The application requires the following configuration:

1. Backend Service URL (in `workflow_service.dart`):
```dart
static const String baseUrl = 'http://localhost:3000'; // Update with your backend URL
```

2. Solana Network Configuration (default is devnet)

## Security

- Wallet mnemonics are securely stored using Flutter Secure Storage
- API communications use HTTPS
- Sensitive data is never stored in plain text

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Support

For support, please open an issue in the repository or contact the development team. 