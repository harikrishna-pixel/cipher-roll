# Security gate: questions Praba asks the developer (before building vault storage)
Reply Yes or No to each, with proof. "Encrypted" goes in the store only after the 8 questions below and the 3 added on 3 Nov are all Yes (9-item gate in doc 11, section 1).
| # | Question | Proof needed |
|---|---|---|
| 1 | Every item encrypted with AES-256-GCM, own key per item? | Package name, plus a test that a stored file cannot be opened without unlocking |
| 2 | Keys in iOS Keychain, wrapped by a key from the user's PIN (PBKDF2 or Argon2)? | Keychain setting used and key derivation used |
| 3 | No readable copy left after opening a video or file? | App folder check after viewing and after closing |
| 4 | Import: copy, verify, then offer delete originals; killed halfway leaves originals untouched? | Kill-app test result |
| 5 | Wrong-PIN counter survives restart; app-switcher preview hidden? | Short screen recording |
| 6 | Decoy fully separate; nothing (timing, logs, analytics) shows which vault opened? | Written answer plus analytics log check |
| 7 | Recovery key works end to end (shown once, test, reset PIN)? | Screen recording |
| 8 | Mixpanel off until Allow; no names, PINs, notes or search words sent? | Network log with consent declined and accepted |
Also confirm: vault files excluded from iCloud backup; Export all works; calculator lock built as an optional setting.
Any "No" or proof that is only "we do that": treat as not done.

## Added 3 Nov (reviewer approved)
| Question | Proof |
|---|---|
| 6-digit minimum PIN? Recovery key real vaults only? Decoy own PIN and keys, no recovery? | Design doc + tests |
| Secure Enclave: feasible? How is offline PIN guessing slowed? What recovery is lost? | Phase 0A document |
| Results for: passcode removed, iPhone replaced, recovery key lost, reinstall, restore from backup | Test log |
