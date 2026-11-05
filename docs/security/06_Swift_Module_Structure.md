# 6. Swift module structure

Status: draft for sign-off. Folders are the target layout for Phase 0 and Phase 1. Creating the Xcode project is Phase 0 and does not require this pack to be signed. Filling `Core/Crypto` and `Core/Storage` with vault behaviour is Phase 1 and does.

```
App/                          launch, scene cover, lock-on-return
Features/Onboarding/
Features/Lock/
Features/Home/
Features/Import/
Features/Viewers/
Features/Paywall/
Features/Settings/
Features/Safety/
Features/Backup/
Features/Help/
Features/Retention/
Core/Crypto/                  AES-GCM, PBKDF2, wrap, wipe, recovery words
Core/Storage/                 files, Keychain, Enclave, attempt counter
Core/Analytics/               protocol + no-op; Mixpanel only after consent
DesignSystem/                 tokens from doc 11 section 3
ShareExtension/               separate target, App Group, shared Keychain
CipherRollTests/              XCTest for crypto and storage
```

## Who may call whom

| Module | May | Must not |
|---|---|---|
| `Core/Crypto` | CryptoKit, CommonCrypto, Security (Enclave seal) | SwiftUI, analytics, file paths of user items, logging the secret |
| `Core/Storage` | Crypto, FileManager, Keychain | Decide product copy. Log names or secrets |
| Feature screens | Call `VaultService` | Touch item keys, call `AES.GCM` themselves, write plaintext item files |
| `Core/Analytics` | Send an allowed event after consent | Receive vault contents, PIN, search text, or a real-versus-decoy flag |
| Share extension | The same `VaultService` through the shared group | Delete the original in the source app |

`VaultService` is the single type the features call. It exposes create vault, add item, read item into memory, delete item, change lock secret, recovery setup, unlock with recovery key, and the attempt delay. It does not expose raw keys.

## Build settings that match the design

- iOS 16 or later. Universal: iPhone, iPad, iPhone Duo.
- SwiftUI, MVVM, `ObservableObject`.
- No ads SDK, no ATT, no Firebase, no cloud vault SDK.
- Manrope bundled. Phosphor for icons. Icon B as the default app icon.
- Phase 8 is built with Xcode 27.1 and the iOS 27.1 SDK or later. Earlier phases can be compiled with the team's current Xcode as long as the deployment target stays iOS 16 and the layout rules in doc 11 section 10 are followed when UI starts (Phase 2).

## Tests live next to the core

`CipherRollTests` links `Core/Crypto` and `Core/Storage` and does not need the UI. A test that wants a "device" passcode and a Secure Enclave runs on a real iPhone and is marked as such. Simulator tests cover AES-GCM, KDF, wrap round-trip, the dummy-decoy timing path with a stub Enclave, and the attempt counter using an in-memory Keychain double. The real Keychain class and the real Enclave are called out in document 8 as device tests, and they are not faked into a pass.
