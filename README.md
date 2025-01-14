# SuperPull Mobile

SuperPull Mobile is a Flutter application that enables users to participate in NFT auctions with dynamic bonding curves on the Solana blockchain. The app integrates with Temporal.io workflows for reliable transaction processing and state management.

## Technical Architecture

### State Management
- **Riverpod**: Used for dependency injection and state management
- **StateNotifier**: For complex state handling with immutable state updates
- **FutureProvider**: For async data fetching with automatic caching

### Service Layer
- **WorkflowService**: Manages long-running operations via Temporal.io
  - Handles workflow execution, querying, and signaling
  - Implements polling with backoff for workflow status
  - Provides error handling and retry mechanisms

- **TokenService**: Manages SPL/MPL token interactions
  - Implements 5-minute caching for token metadata
  - Handles fallback to cached data on errors
  - Provides automatic metadata refresh

- **WalletService**: Secure wallet management
  - BIP39 mnemonic generation and storage
  - Secure key derivation and storage
  - Integration with Solana web3.js

- **AuthService**: Authentication and session management
  - JWT-based authentication
  - Secure token storage
  - Automatic session refresh

### Application Flows

#### 1. Authentication Flow
```
User Login/Registration -> JWT Generation -> Secure Storage -> Session Management
```
- Supports social authentication providers
- Implements secure token refresh mechanism
- Handles session expiration and auto-logout

#### 2. Wallet Management Flow
```
Create/Import Wallet -> Generate/Validate Mnemonic -> Secure Storage -> Key Derivation
```
- Supports BIP39 mnemonic generation
- Implements hierarchical deterministic wallets
- Provides secure key storage and recovery

#### 3. Auction Creation Flow
```
Image Upload -> Metadata Generation -> Workflow Initiation -> Status Tracking -> Completion
```
1. User uploads auction image
2. System generates and uploads metadata to Arweave
3. Temporal workflow creates Merkle tree
4. Creates collection NFT
5. Initializes auction with bonding curve parameters
6. Returns auction details for UI display

#### 4. Token Management Flow
```
Fetch Token List -> Metadata Retrieval -> Cache Management -> UI Updates
```
1. Retrieves list of accepted tokens
2. Fetches SPL token information (supply, decimals)
3. Retrieves MPL metadata if available
4. Implements fallback to default values
5. Caches results for 5 minutes
6. Provides automatic refresh mechanism

#### 5. Bidding Flow
```
Price Check -> Balance Verification -> Transaction Creation -> Signature -> Submission
```
1. Retrieves current token price
2. Verifies user balance
3. Creates bid transaction
4. Gets user signature
5. Submits to blockchain
6. Monitors transaction status

#### 6. Auction Status Tracking
```
Periodic Polling -> State Updates -> Cache Management -> UI Refresh
```
1. Polls auction status every 30 seconds
2. Updates local state cache
3. Triggers UI updates
4. Handles auction completion
5. Manages token distribution

## Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK (3.0.0 or higher)
- Solana CLI tools (optional, for testing)
- iOS/Android development setup
- Temporal.io server (for workflow execution)

## Development Setup

1. Clone and setup dependencies:
```bash
git clone <repository-url>
cd superpull_mobile
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

2. Environment Configuration:
```dart
// lib/config/env.dart
const API_URL = String.fromEnvironment('API_URL',
    defaultValue: 'https://api.superpull.world');
```

3. Run with specific environment:
```bash
flutter run --dart-define=API_URL=https://api.dev.superpull.world
```

## Project Structure

```
lib/
├── main.dart                # Application entry point
├── config/                  # Configuration and environment
│   └── env.dart
├── models/                  # Freezed data models
│   ├── token_metadata.dart
│   └── auction_state.dart
├── providers/              # Riverpod providers
│   ├── token_provider.dart
│   └── auth_provider.dart
├── services/              # Business logic layer
│   ├── workflow_service.dart
│   ├── token_service.dart
│   └── wallet_service.dart
├── pages/                 # UI screens
└── widgets/              # Reusable components
```

## Security Considerations

### Wallet Security
- Mnemonics stored using Flutter Secure Storage
- Keys never exposed to JavaScript bridge
- Automatic session timeout

### API Security
- JWT-based authentication
- HTTPS-only communication
- Request signing for blockchain transactions

### Error Handling
- Graceful degradation with cached data
- Comprehensive error logging
- User-friendly error messages

## Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

## Workflow Architecture

The app uses a workflow-based architecture for reliable transaction processing:

1. **Workflow Initialization**
   - Client initiates workflow
   - Server generates workflow ID
   - Client polls for status

2. **State Management**
   - Workflows maintain transaction state
   - Automatic retry on failures
   - Consistent state across crashes

3. **Error Handling**
   - Graceful degradation
   - Automatic retries
   - Fallback to cached data

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed contribution guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. 