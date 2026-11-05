# 2. Encryption architecture and key tree

Status: draft for sign-off. Algorithms named here are the design. They are not "done" until the tests in document 8 pass.

## Primitives

| Job | Choice |
|---|---|
| Item and metadata sealing | CryptoKit `AES.GCM`, 256-bit key, 96-bit random nonce per seal, 128-bit tag |
| Associated data | Item id (UUID bytes) so one item's ciphertext cannot be moved onto another item |
| Lock-secret stretching | PBKDF2-HMAC-SHA256 via CommonCrypto. Salt 16 random bytes. Output 32 bytes. Iteration floor 600,000 (OWASP 2023 for this hash). On first run, raise the count until one derivation takes about 300 ms on that device, and store the count with the wrap |
| Backup-password stretching | Same PBKDF2, tuned to about 1 second, because export is rare. Argon2id is deferred (see open questions in document 7) |
| Device binding | Secure Enclave P-256 key, `SecKeyCreateEncryptedData` with `eciesEncryptionCofactorVariableIVX963SHA256AESGCM`. The private key is not exportable |
| Randomness | `SecRandomCopyBytes` |
| File protection | `NSFileProtectionComplete` (`.completeFileProtection`), `isExcludedFromBackup = true` |
| Keychain class | `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` |

PBKDF2 is the V1 default because it is in the OS. A third-party Argon2 package is not required to build the gate. Argon2id can replace PBKDF2 later without changing the key tree, if a reviewed package is accepted. The stored record keeps a KDF identifier so a later change can sit beside old wraps.

The lock secret is hashed with SHA-256 to a fixed 32-byte input before PBKDF2, so a short PIN and a long passphrase take the same KDF time.

## Key tree

```
Device passcode (iOS)
  └── Keychain WhenPasscodeSetThisDeviceOnly
        └── Secure Enclave P-256 key (non-exportable)
              └── seals the key bundle (device binding)

Lock secret  --PBKDF2--> KEK_lock     --AES-GCM--> unwraps VMK
Recovery key --PBKDF2--> KEK_recovery --AES-GCM--> unwraps VMK of each real vault
                                              (no wrap for the decoy)

VMK --AES-GCM--> unwraps each item key
item key --AES-GCM--> seals file bytes and the note body

Backup password --PBKDF2--> KEK_backup --AES-GCM--> seals the .crbackup payload
  (this key exists only for that file; it is not a vault key)
```

| Key | Size | Created | Stored raw? |
|---|---|---|---|
| Item key | 256-bit | One per item, `SymmetricKey(size: .bits256)` | No. Stored only as an AES-GCM wrap under that vault's VMK |
| VMK (vault key) | 256-bit | One per vault | No. Stored as wraps under KEK_lock and, for real vaults, under KEK_recovery |
| KEK_lock | 256-bit | Derived when locking or unlocking | Memory only. Wiped after the wrap or unwrap |
| KEK_recovery | 256-bit | Derived from the recovery key | A device-bound copy is sealed to the Secure Enclave so a later real vault can be wrapped without asking for the words again. The words themselves are not stored after confirmation |
| KEK_backup | 256-bit | Derived when exporting or restoring | Memory only, for that operation |

Decoy vault: its own VMK, its own salt, its own KEK from its own PIN. There is no KEK_recovery wrap. Backup export never reads the decoy store.

## On-disk layout

All filenames in the vault directory are random UUIDs. The directory is not named `decoy` or given a vault title.

| Record | Contents |
|---|---|
| Item file | Magic `CRI1`, format version, nonce, ciphertext, tag. No original filename |
| Vault record | Sealed under the VMK: item id, type, wrapped item key, encrypted display name, dates, album id, deleted flag. Associated data is the vault id |
| Key bundle | Version, KDF name, iteration count, salts, PIN wrap of the VMK, recovery wrap of the VMK (real vaults only), then that whole bundle sealed to the Secure Enclave public key |

Photos and ordinary files decrypt into memory. Video may use one protected temporary file (document 3). Notes are bytes inside the sealed vault record, or an item file if the note is large. Search tokens, if any are added later, are derived on device after unlock and are never written in plaintext and never sent.

## Unlock check without a decoy leak

The lock screen belongs to the active real vault. After the delay allows an attempt:

1. Derive KEK for the typed secret (fixed-length input).
2. Always open two wraps: the active real vault, and the decoy wrap or a dummy wrap of the same size when no decoy exists.
3. Choose the match after both opens finish. CryptoKit's tag check is the comparison.
4. Success and failure return on the same path. The UI does not say which vault matched. A match on the decoy opens the decoy store. A match on the real vault opens that vault. No match increments the shared counter.

Dummy work when there is no decoy keeps the time from showing that a decoy exists. The dummy key is random, sealed once at install, and never matches.

## What a PIN change does

A new salt and a new KEK_lock re-wrap the same VMK. Item keys and file ciphertext stay as they are. The recovery wrap is left as it is. Old KEK bytes are wiped.

Changing the recovery key, if a later version offers it, generates a new recovery key, re-wraps every real VMK, and leaves the decoy untouched. V1 shows the key at setup and does not rotate it in a settings screen unless a screen in the manifest is added for that. None is in the current manifest.

## Export all versus backup

Export all (doc 11 section 5) writes a zip of the decrypted originals to the share sheet. That zip is plaintext in the place the user chooses. It is a user action, not the vault format.

Export a backup (document 9) writes a `.crbackup` file sealed under a password. It includes real vaults only.
