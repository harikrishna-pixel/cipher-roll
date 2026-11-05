# 1. Threat model

Status: draft for sign-off. Not a completed control. No test evidence yet.

CipherRoll is a local vault for photos, videos, files and notes. There is no account. Nothing in the vault is uploaded. Each device has its own vault.

## Assets

| Asset | Where it lives |
|---|---|
| Item bytes (photo, video, file, note) | App container, sealed with AES-256-GCM |
| Item keys and vault keys | Wrapped. Raw keys only in memory while unlocked |
| Lock secret (PIN, pattern, password, phrase) | Never stored. A verifier and a wrap are stored |
| Recovery key words | Shown until the user tests them and confirms they saved them. Then deleted. Never stored as words |
| Decoy items and decoy keys | Separate records. No recovery wrap |
| Backup file (`.crbackup`) | Outside the app, protected by a password the user chooses |
| Attempt counter | Keychain, same device, passcode required |
| Analytics | Off until the user allows them. Event names and buckets only |

## People and situations

| Who | What they can do | What this design aims for |
|---|---|---|
| Someone glancing at an unlocked phone | Sees the lock screen or the app switcher | App-switcher preview is covered. Calculator-style PIN is an optional look, not a second vault |
| Someone who knows the user and can try PINs on the device | Types guesses, force-quits the app, restarts the phone | Growing delay, stored in the Keychain, shared by every secret so the decoy is not revealed by timing |
| Someone who copies the app container to a computer | Reads files offline, without the Secure Enclave | The key bundle is sealed to the Secure Enclave. The copy does not unwrap |
| Someone who removes the device passcode, deletes the app, or restores a backup onto a new device | iOS deletes This-device-only Keychain items and the Secure Enclave key | Vault files cannot be unwrapped. The written recovery key cannot recreate them. The user is told this before a vault is created |
| The user who forgot the PIN and still has the recovery key, on the same device, with the passcode still set | Types the recovery key | Real vaults unwrap. The decoy does not |
| The user who forgot the decoy PIN | Asks support to reset it | There is no reset. Those items stay locked |
| A coerced user who wants to open the decoy | Must type the decoy PIN on the same lock screen | The screen does not say which secret matched. Face ID does not start by itself when a decoy exists (see open questions) |
| CipherRoll / Marberx | A support request, a crash report, an analytics event | We cannot unwrap a vault. Logs and events omit PINs, keys, names, note text and search words |

## What we do not promise

- A forensic examiner with the unlocked device, a jailbreak, or a chip-off plus a flaw in the Secure Enclave.
- Erasure of flash remnants after a temporary video file is deleted.
- Survival of vault items after the device is lost, replaced, erased, or the app is deleted, unless the user made a `.crbackup` and still has that password.
- That a 6-digit PIN is a strong secret by itself. Six digits is the product minimum. Strength against an offline attacker comes from device binding. Strength against someone holding the unlocked phone comes from the delay. Users who want more choose 8 or more digits, or a longer passcode.

## Decisions already signed (3 Nov 2026)

Minimum 6-digit PIN. Recovery for real vaults only. Decoy has its own PIN and keys and no recovery. Temporary video files are a V1 trade-off. Storage is local and excluded from iCloud backup. Export and restore of a password-protected backup is in V1 (doc 13).
