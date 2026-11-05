# 9. Backup export and restore

Status: draft for sign-off. Product approval is already in doc 13 (3 Nov 2026): export and restore are in V1. This file is the security design those screens must follow. It is not an implementation, and it is not a passed test.

Until gate items 1 to 7 pass, the interface says "protected by your password". It does not say "encrypted".

## Why it exists

Vault files are excluded from iCloud backup. The recovery key opens wraps on this device. It does not rebuild files on a new device. A user who wants a copy makes a `.crbackup` and keeps that password.

Export all (a zip of originals) stays a separate action. It is not this format.

## Export

Entry: Settings, Export a backup.

1. The user picks one or more real vaults. The decoy is not in the list. The screen does not mention a decoy.
2. The user sets a backup password, at least 10 characters, entered twice. The password is not the PIN. A forgotten password cannot be reset. The screen says that before the file is made.
3. The app builds a payload of those vaults' items by decrypting with the VMK and immediately sealing into the backup, streaming item bytes so a large video is not held whole in memory.
4. The user saves the file to Files or the share sheet.

Free and paid users may export. The data is theirs. Event names: `backup_export_started`, `backup_export_completed`, `backup_saved`. Properties are buckets and `files` or `share`. No file name, password, or vault name.

## File format

| Field | Value |
|---|---|
| Magic | `CRBK` |
| Version | 1 |
| KDF | PBKDF2-HMAC-SHA256, random 16-byte salt, iteration count stored in the header (about 1 second on device, floor 600,000) |
| Seal | AES-256-GCM under the 32-byte KEK. Nonce and tag stored in the header. Associated data is the magic and the version |
| Payload | Length-prefixed item records: type, display name, bytes. Vault titles included so restore can name the new vault |

A wrong password fails the GCM tag. The error shown is the same for a wrong password and does not describe the header. A truncated or bad file returns `bad_file`.

The payload does not contain decoy items, decoy keys, or the device recovery words. Restore cannot recreate a decoy from this file.

## Restore

Entry: Settings, Restore from backup.

1. The user picks a file and types the password.
2. On a valid tag, items are written as a new vault named "Personal (restored)". If that name is taken, append a number. Existing vaults are not overwritten or merged.
3. The new vault uses a PIN the user sets on this device, under the normal minimum. Its VMK is new. Item keys are new. Bytes are sealed with the normal item format.
4. The app offers a new recovery key for this install's real vaults, using the setup rules in document 5, if this restored vault is a real vault (it is).
5. Items above the free limits follow the plan-ended rule: they stay viewable and exportable. One vault stays editable. Extra vaults are read-only while the plan is free. Nothing is deleted because a plan ended.

Events: `backup_restore_started`, `backup_restore_completed`, `backup_restore_failed` with `reason` `wrong_password` or `bad_file`.

## Interruptions

Export writes to a temporary file in the app container and moves it into place only after the final tag is written. A kill mid-export leaves no new vault and the incomplete temp is swept on launch.

Restore writes into a new vault directory and publishes that vault only after every item verifies. A kill mid-restore deletes the incomplete new directory on next launch and does not modify vaults that were already there.

## Limits

The backup password is the only secret for that file. Device binding does not apply to it, because the file is meant to move. A weak password can be guessed offline. The 10-character minimum and the slow KDF are the controls. The UI tells the user to keep the file and the password in different places, matching Help.
