# 4. Secure Enclave feasibility

Status: draft for sign-off. This is a design result, not a device test. Document 8 lists the tests still to run.

## What the Secure Enclave can and cannot do

The Secure Enclave on iPhone and current iPad can hold a P-256 private key and perform the private operation on device. `SecKeyCreateEncryptedData` can seal a small blob to that key (ECIES). The private key is not returned to the app.

The Secure Enclave does not accept bulk vault files, and it does not implement the app's AES-GCM item encryption. CryptoKit `AES.GCM` runs on the CPU with a key the app holds only after unwrap.

The Secure Enclave does not, by itself, count PIN guesses. If an attacker already has the PIN wrap in the clear, they can run PBKDF2 on another computer. Sealing that wrap to the Enclave is what stops that copy-and-guess path.

## Device-bound unwrap

On vault creation, after the passcode check:

1. Create a Secure Enclave key if one does not exist for this install. Access control is private-key use, this device only, only when a passcode is set. Biometry is not required for this key, because the PIN must work when Face ID fails.
2. Build the inner bundle: salts, iteration count, AES-GCM wrap of the VMK under KEK_lock, and for a real vault the AES-GCM wrap under KEK_recovery.
3. Seal that bundle with `SecKeyCreateEncryptedData` and the Enclave public key.
4. Store the sealed bundle in the Keychain under `WhenPasscodeSetThisDeviceOnly`.

Unlock reverses the order. The Enclave opens the bundle on this device. Then KEK_lock opens the VMK. Both steps must succeed.

A simulator or a device without a Secure Enclave cannot use this path. V1 does not silently drop to a weaker wrap. Vault creation fails with a fixed error code and a plain explanation. Shipping devices for this app (iPhone, iPad, iPhone Duo) have a Secure Enclave. The test plan records one run on a real device.

## Rate limiting (on the device)

The Enclave design does nothing for a person who is typing on the phone. The app stores a counter:

| Failures so far | Wait before the next attempt |
|---|---|
| 1 to 4 | None, beyond the time the KDF already takes |
| 5 | 30 seconds |
| Each further failure | Double the wait, capped at 15 minutes |

The counter and the next-allowed time live in the Keychain, so a force-quit or a reboot keeps them. One counter covers the lock screen. Real and decoy attempts share it, so the wait does not reveal which secret was tried.

The wait is enforced before the UI accepts another try. A wrong secret and a right secret that is still inside the wait look the same: the pad does not unlock.

This slows someone who is holding the phone. It does not slow someone who has pulled the sealed bundle off the device, because that person still cannot open the Enclave layer. It also does not stop someone who can run code on the already unlocked device and ask the Enclave to open the bundle, then guess the PIN against the inner wrap in memory. That case is outside the promise (document 1).

Deleting the app deletes the Keychain items. The counter does not survive app deletion. Doc 11's phrase "reinstall of the same session" is read here as: the counter survives a kill and a relaunch, including a reboot. It is listed as an open point for Praba only if "reinstall" was meant to survive Delete App.

## What recovery is lost because of this design

The recovery key unwraps real VMKs only while all of the following are still true:

- This is the same device.
- The device still has its passcode (iOS deletes `WhenPasscodeSetThisDeviceOnly` items and the Enclave key when the passcode is removed).
- The app has not been deleted.
- The user still has the recovery words.

| Situation | PIN | Written recovery key | Vault files |
|---|---|---|---|
| Passcode removed | Unwrap is gone, because iOS deleted the Keychain items | Same. The words have nothing left to open | Files may still be on disk and cannot be opened. Tell the user at setup |
| iPhone or iPad replaced | New device | The key cannot recreate files. Enclave keys do not move | Gone, unless a `.crbackup` was saved |
| Recovery key lost, PIN still known | Works | Cannot change a forgotten PIN later | Stay on this device |
| PIN and recovery key both lost | No | No | No vendor reset |
| App deleted and reinstalled | No | No | Deleted with the app. Only a `.crbackup` can bring items back |
| Restore from an iCloud or Finder backup onto a device | This-device-only Keychain items and the Enclave key are not restored | Cannot open a restored bundle | Vault files are excluded from backup, so they are not in that restore |
| Restore from `.crbackup` | User sets a PIN on this device | A new recovery key is offered | Items are added as a new vault. Nothing already on the device is overwritten |

You cannot have both "the written recovery key still works after the passcode is removed" and "a copied container cannot be guessed offline". The second one is the gate. The first one is given up, and the setup copy must say so in plain words.

## Feasibility result

Device-bound unwrap is feasible on iOS 16 and later with Security.framework and CryptoKit. No extra crypto library is required for the Enclave step. Bulk AES-GCM stays in CryptoKit. Offline PIN guessing of a copied vault is blocked by the Enclave seal. Online guessing is slowed by PBKDF2 and by the Keychain-backed delay. Recovery across devices is not provided by this design; the backup file in document 9 is the path for a new device.
