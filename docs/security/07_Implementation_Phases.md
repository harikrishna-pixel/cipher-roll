# 7. Implementation phases

Status: draft for sign-off. Phase 0A is this pack. Later phases are not started by this document.

| Phase | Work | Vault storage code |
|---|---|---|
| 0A | These documents | None. This phase |
| 0 | Xcode project, folders, Manrope, design tokens, Phosphor, analytics protocol with a no-op, Icon B | None |
| 1 | `Core/Crypto` and `Core/Storage`, XCTest, gate items 1 to 7 | Only after this pack is signed |
| 2 | Lock and onboarding screens | Uses Phase 1 |
| 3 | Home, import, viewers | Uses Phase 1 |
| 4 | Paywalls, RevenueCat, StoreKit 2 | No change to the key tree |
| 5 | Decoy UI, privacy, settings, app icons. Backup UI only after this pack is signed | Uses document 9 |
| 6 | Share extension, retention, Help | Same Keychain access group |
| 7 | Accessibility and the QA list in doc 11 section 13 | Gate table filled with real results |
| 8 | iPad and iPhone Duo layouts | No second crypto stack |

A security row is marked complete only when document 8 has a test name and a recorded result. "We do that" is not a result.

Phase 0 may be built before sign-off because it does not create a vault. Phase 1 waits.

## Open questions for Praba

These are the points that change the design if the answer is different. Recommended answers are the ones written into documents 2 to 5 and 9.

1. **Backup in V1.** Doc 13 already approves export and restore. Document 9 is that design. Help article `backup` still says a backup does not exist yet. Confirm the feature stands, and that Phase 6 will correct that Help answer.
2. **KDF.** V1 uses PBKDF2-HMAC-SHA256 in CommonCrypto, at least 600,000 iterations, about 300 ms on device. Confirm we should not add an Argon2 package in V1.
3. **Face ID and the decoy.** When a decoy exists, Face ID does not start by itself, so a coerced unlock can type the decoy PIN. With no decoy, Face ID still starts at once. Confirm.
4. **`decoy_created`.** Doc 10 wants that event once. Gate item 6 says analytics must not show a clue about the decoy. This pack does not send the event. Confirm.
5. **Pattern length.** At least 6 dots, for the same reason the PIN is at least 6 digits. Confirm.
6. **Password length.** At least 8 characters, same as the custom phrase in Help. Confirm.
7. **Recovery words.** 24 English words. Confirm that format for the screen.
8. **Passcode removed.** The vault cannot be opened, even with the PIN and the written recovery key, because iOS deletes the Keychain items. Confirm the setup warning may say that.
9. **Keychain class.** The gate (`WhenPasscodeSetThisDeviceOnly`) wins over the stack note (`WhenUnlockedThisDeviceOnly`). Confirm.
10. **Attempt counter.** It survives a kill and a reboot. It does not survive deleting the app. Confirm that reading.

Encrypted export is not an open product question anymore. It is in document 9 because doc 13 approved it on 3 Nov. The remaining question is confirmation that Help and the store copy stay on "protected by your password" until the gate passes.
