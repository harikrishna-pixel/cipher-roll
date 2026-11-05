# 3. Key management

Status: draft for sign-off. Not complete. No runtime evidence yet.

## Where keys live

| Material | Location | Class |
|---|---|---|
| Secure Enclave private key | Secure Enclave, Keychain reference | `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`, `kSecAttrTokenIDSecureEnclave` |
| Sealed key bundle (wraps) | Keychain item, one per vault, service `app.cipherroll.vault` | Same class |
| Sealed copy of KEK_recovery (real vaults only) | Keychain item, service `app.cipherroll.recovery` | Same class |
| Attempt counter and next-allowed time | Keychain item, service `app.cipherroll.lockout` | Same class |
| Vault ciphertext | App container `Library/Vaults/<uuid>/` | Complete file protection, excluded from backup |
| Temporary video | `Library/Caches/playback/<uuid>` | Complete file protection, excluded from backup, deleted on close and on every launch |

`UserDefaults` holds UI flags only: onboarding finished, consent choice, selected icon name. It does not hold keys, PINs, salts, or vault titles.

If `LAContext` reports that the device has no passcode, vault creation stops. The screen explains that a device passcode is required. No vault record is written.

The stack document's `WhenUnlockedThisDeviceOnly` is not used. The gate requires the passcode-set class so a device with no passcode cannot hold the wraps, and so removing the passcode causes iOS to delete them.

## Lock secrets

| Method | Rule |
|---|---|
| PIN | Digits only, length at least 6. Length 4 and below is rejected. 8 or more is accepted |
| Calculator-style PIN | The same PIN rules. The screen looks like a calculator. The KDF input is the PIN, after the user presses equals |
| Password | At least 8 characters. Letters and numbers allowed |
| Custom phrase | At least 8 characters, matching Help |
| Pattern | At least 6 dots. A 4-dot pattern is rejected, for the same reason a 4-digit PIN is rejected |
| Face ID or Touch ID | Shortcut only. A biometric Keychain item may hold a wrap of the VMK with `biometryCurrentSet`. The PIN, pattern, password or phrase always remains. The label on screen comes from `LAContext.biometryType` |

Face ID for the decoy stays off. The setup screen says so. See document 5 for why biometrics do not auto-start once a decoy exists.

## PIN change and rotation

1. Unlock with the current secret so the VMK is in memory.
2. Generate a new salt. Derive a new KEK_lock from the new secret.
3. Seal the VMK with the new KEK. Replace the PIN wrap inside the bundle. Re-seal the bundle to the Secure Enclave.
4. Wipe the old KEK, the new KEK, and the VMK copy used for the wrap.
5. Item keys are not rotated on a PIN change. Rotating them would rewrite every file. That is out of V1.

Deleting an item removes its wrapped item key and its ciphertext file. Recently Deleted keeps that wrapped item until the user removes it permanently or the screen's own retention copy says to. The retention length is taken from the Recently Deleted screen in Phase 3. Until then the design treats those items as still sealed. Deleting a file is not forensic erasure of the flash.

## Memory wiping

After a seal, an unseal, or a lock:

- Key bytes that we allocated are passed through `withUnsafeMutableBytes` and `memset_s`.
- `SymmetricKey` values are dropped at the end of the scope.
- Keys are not stored in a global, a singleton cache, or a log.
- Swift and the allocator can have left copies. This is best-effort wiping of the buffers we own. It is not a claim that RAM was forensically cleared.

On lock, or when the scene resigns active, in-memory VMKs and item keys are dropped and the app-switcher cover is shown. The next open requires the vault's own method again. A delay setting (immediately, 1 minute, 5 minutes) may keep the VMK only for that interval, in memory, and drops it when the interval ends or the process dies.

## Temporary video files

V1 may write one decrypted video to the playback directory so `AVPlayer` can read a file URL.

- Random file name. Original name is not used.
- Complete file protection. Excluded from backup.
- Deleted when playback ends, when the viewer closes, when the scene backgrounds, and on the next launch if a crash left the file behind.
- A kill, a crash, or an interrupted play can leave the file until the next launch sweep.

This is an accepted V1 trade-off (doc 11 item 3). Copy, Help, and code comments describe a protected temporary file that is removed when the video closes and when the app starts. They do not say the data is gone beyond recovery.

## Logging

No `print`, `os_log`, or analytics property may contain a PIN, key, recovery words, backup password, file name, note text, vault title, or search string. Crash reporters get the same ban. Security failures log a fixed code (`wrap_failed`, `kdf_failed`, `file_missing`) and nothing else.

## Share extension

The extension uses the same App Group container and the same Keychain access group. It cannot read item bytes until the vault's own lock succeeds inside the extension. Large files are streamed into the sealed item file. The extension never deletes the source item.
