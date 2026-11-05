# 5. Recovery design

Status: draft for sign-off. The flow is specified. It is not complete until the tests in document 8 pass.

## What the recovery key is

One recovery key per install. It is 256 random bits, shown as 24 English words (BIP39 wordlist and checksum) so a typo can be caught before a wrong unwrap. The words are a secret. They are not a vault name and they are not a PIN.

The key covers every real vault on that install. It does not cover the decoy. It does not bring back deleted items. It does not recreate files on a new device. Support cannot see it or reset it.

## Setup

1. After the first real vault's VMK exists, draw the 256-bit key and show the 24 words once on screen.
2. The user can copy them or save them to Files. Those actions are the user's. The app does not put the words in Photos.
3. "I saved my key" stays disabled until the user types the words back and the app unwraps the VMK with them (`recovery_key_tested`).
4. Until that confirmation, a temporary copy of the words is held only as a Keychain item in the same passcode-set class, so a kill during setup can show the same words again. This is still the one key, not a new one.
5. When the user confirms, that temporary item is deleted. The words cannot be shown again. What remains is the recovery wrap of each real VMK, plus the Secure Enclave seal of KEK_recovery used only to wrap a real vault created later.

A later real vault, created while a real vault is unlocked, uses the sealed KEK_recovery to wrap the new VMK. The user is not asked to read the words out again. KEK_recovery is never wrapped under a vault PIN, so knowing one vault's PIN does not reveal the recovery key or open the other real vaults.

The decoy path never reads `app.cipherroll.recovery`.

## Using the key

The lock screen offers "Use recovery key" for the active real vault. The user types the 24 words. The app derives KEK_recovery, opens the recovery wrap, and then requires a new lock secret (minimum rules in document 3). The new secret re-wraps the VMK. The recovery wrap stays valid so the same words still work.

If the words are wrong, the shared attempt counter moves. The error text is the same generic failure used for a wrong PIN. It does not say whether a decoy exists.

The decoy has no recovery screen and no recovery wrap. Its setup copy states that a forgotten decoy PIN means those items cannot be recovered.

## What must not leak

- The recovery words do not contain a flag, a length, or a word that means "decoy".
- File names, Keychain account names shown in logs, and analytics properties do not include `decoy`.
- `vault_unlocked` records `method` as `face_id` or `secret` only. It never records which vault opened.
- Doc 10 lists `decoy_created`. Gate item 6 says analytics must not carry a clue that the decoy exists. This pack keeps the event out until Praba chooses otherwise (document 7). Existence of the feature in the UI for a Pro user is a product surface; the analytics payload still must not name it if the gate is read strictly.

## Face ID when a decoy exists

Face ID, if turned on, unwraps the real vault that enrolled it. Starting Face ID automatically would open the real vault while a coerced user is trying to type the decoy PIN.

Design: once a decoy exists, the lock screen does not start biometrics by itself. The vault's PIN, pattern, password or phrase is shown first. An explicit biometric button remains for the real vault that enrolled it. The decoy does not enroll biometrics.

This is a deliberate narrowing of "Face ID starts at once". It applies only when a decoy exists. With no decoy, biometrics still start at once and the secret stays available as the backup. This needs Praba's confirmation (document 7).

## Decoy

| | Real vault | Decoy |
|---|---|---|
| PIN | User's, at least 6 digits | A different PIN, at least 6 digits |
| Keys | Own VMK | Own VMK |
| Recovery | Yes | No |
| Backup export | Included if the user selects that vault | Never included, and the export UI does not mention it |
| Face ID | Optional shortcut | Off |
| Analytics | `vault_unlocked` with method only | Same event, same properties |

The decoy is Pro. The share extension does not offer it as a target unless that vault is the one already unlocked in the extension.
