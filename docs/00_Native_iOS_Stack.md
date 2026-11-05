# CipherRoll — Native iOS (Swift) stack
Chosen 3 Nov 2026: the developer builds in native Swift. This file replaces section 2 (Stack) of doc 11. Everything else in doc 11, 13, 10, 09 and 06 applies as written.

| Item | Choice |
|---|---|
| Language / UI | Swift 5.9+, SwiftUI. iOS 16+, universal: iPhone, iPad and iPhone Duo (adaptive layouts, see doc 11 section 10) (raise to iOS 17 if you want `@Observable`) |
| Architecture | MVVM with `ObservableObject`; one `VaultService` layer for all storage and crypto. Folders: `App/`, `Features/<Name>/`, `Core/Crypto`, `Core/Storage`, `Core/Analytics`, `DesignSystem/` |
| Encryption | CryptoKit `AES.GCM`, random 256-bit key per item. Item key wrapped by a vault key. Vault key wrapped by a key derived from the lock secret |
| Key derivation | PBKDF2-HMAC-SHA256 via CommonCrypto with a high iteration count, or Argon2id via a vetted Swift package. Random salt per vault |
| Key storage | Keychain Services, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. Optional: Secure Enclave key to wrap the vault key |
| Face ID | LocalAuthentication, shortcut only, PIN always available |
| Files | App container, `.completeFileProtection`, `isExcludedFromBackup = true` |
| Import | `PHPickerViewController` (PhotosUI) and `UIDocumentPickerViewController`. No photo-library permission to import. Delete originals via `PHPhotoLibrary.performChanges`, only after verify and consent |
| Video / files | `AVPlayer` fed by a resource loader or protected temp file deleted on close and on launch. `QLPreviewController` or custom viewers decrypt to memory |
| App switcher | Cover the window with a blur/solid view in `sceneWillResignActive` |
| Share Extension | Share extension target + App Group + shared Keychain access group. Stream large files, do not load into memory |
| Purchases | RevenueCat (`purchases-ios`) on StoreKit 2. Trial UI only if `isEligibleForIntroOffer` |
| Rating | `AppStore.requestReview` (StoreKit) only |
| Analytics | `Analytics` protocol; Mixpanel Swift SDK behind it. Off until consent |
| Camera | `AVCaptureSession` front camera, break-in selfie only after the consent screen |
| Icons | Phosphor Swift package (bold). Mapping in doc 11 section 2 |
| Font | Manrope 500/600/700/800 bundled, registered in Info.plist (`UIAppFonts`) |
| Tests | XCTest for the crypto and storage layer. UI tests for lock and import |
| Notifications | `UNUserNotificationCenter`, local only (trial day-6 reminder, weekly recap) |
| Alternate icon | `UIApplication.setAlternateIconName` for the plain "Utility" icon. Icon B is the default. Assets: `03_Icon` |
| Not used | Ads SDK, ATT, Firebase, any cloud storage of vault data |

## Differences from the Flutter notes
| Flutter note | Native version |
|---|---|
| Riverpod, go_router | SwiftUI `NavigationStack`, `ObservableObject` view models |
| `local_auth` | LocalAuthentication |
| `flutter analyze` | `swiftlint` (optional) and `xcodebuild test` |
| Native code via platform channel | Not needed |
