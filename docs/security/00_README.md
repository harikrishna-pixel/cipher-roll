# Phase 0A — security design pack

Status: **draft for sign-off. Not signed.** Date: 4 Nov 2026.
Phase 1 storage code exists. Unit rows in `08_Test_Plan.md` have simulator run logs A, B, and C. Run log C covers the backup file checks. Device, UI, and store-listing rows are not run. Device backup checks are not run. No security gate item is complete.

Praba (product) and the reviewer have not signed this pack. Phase 1 was built on request before those signatures. The table below stays pending.

| Role | Name | Date | Decision |
|---|---|---|---|
| Product | Praba | | Pending |
| Reviewer | | | Pending |

## Documents

| # | File | What it decides |
|---|---|---|
| 1 | `01_Threat_Model.md` | What we protect, who we resist, what we do not promise |
| 2 | `02_Encryption_Architecture_and_Key_Tree.md` | AES-256-GCM, item key, vault key, lock key, recovery key |
| 3 | `03_Key_Management.md` | Keychain class, PIN change, rotation, memory wiping |
| 4 | `04_Secure_Enclave_Feasibility.md` | Device-bound unwrap, rate limit, what recovery is lost |
| 5 | `05_Recovery_Design.md` | Real vaults only, decoy has no recovery |
| 6 | `06_Swift_Module_Structure.md` | Modules and what each one may touch |
| 7 | `07_Implementation_Phases.md` | What is allowed before and after sign-off |
| 8 | `08_Test_Plan.md` | Scenarios and the evidence each one must produce |
| 9 | `09_Backup_Export_and_Restore.md` | `.crbackup` design. Approved in doc 13 on 3 Nov. Wording stays "protected by your password" until the gate passes |

## Rules this pack follows

- PIN is at least 6 digits. A 4-digit PIN is rejected. 8 or more digits, or a longer passcode with letters, is allowed.
- Recovery covers real vaults only. It never covers the decoy, and the key material must not show that a decoy exists.
- The decoy has its own PIN and its own keys. It has no recovery key. A forgotten decoy PIN means those items stay locked.
- V1 keeps vault files on this device and marks them excluded from iCloud backup.
- A protected temporary file is allowed for video playback only. Cleanup is mandatory. This pack does not claim forensic erasure.
- Keychain items use `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`. If the device has no passcode, the app warns the user and does not create a vault.
- The stack note that says `WhenUnlockedThisDeviceOnly` is overridden by the security gate (doc 11, item 2).

## Allowed user-facing sentences

"Locked on your iPhone." "Vault contents stay on this iPhone." "Unlocks with Face ID." On iPad and iPhone Duo, warnings that are not phone-only say "this device".

These words stay out of the app and the store until items 1 to 7 of the gate pass and a reviewer signs that result: "encrypted", "military-grade", "unhackable", "nobody can see".
