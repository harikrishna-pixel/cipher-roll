# 8. Test plan

Status: **unit rows below have a run log. Backup file checks have run log C. Device, UI, and store-listing rows are still not run.** Device backup checks (delete the app, reinstall, second device) are not run. A row is evidence only when its result names a real run.

Nothing in this pack marks a security gate item as done. A gate item stays open while any of its rows is still "Not run".

## Gate items 1 to 7 (Phase 1 unit tests, plus the device rows)

| Gate | Test to write | Proves | Result |
|---|---|---|---|
| 1 | `testItemFileIsNotTheOriginalBytes` | A stored photo file does not contain the source header. Opening it without the VMK throws | Pass — run log A |
| 1 | `testEachItemHasItsOwnKey` | Two items use different wrapped keys. Swapping ciphertext fails the tag because associated data is the item id | Pass — run log A |
| 2 | `testKeychainClassIsPasscodeSetThisDeviceOnly` | The add attributes include `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` | Pass — run log A. Query dictionary only. No real Keychain write |
| 2 | Device: remove passcode | After the passcode is removed and the device restarts, unwrap fails and no vault is readable | Not run |
| 2 | `testRefusesVaultWhenNoPasscode` | Creation returns the fixed error and writes no bundle | Pass — run log A. Passcode check is a stub |
| 3 | `testNoPlaintextFileAfterRead` | After read-to-memory of a photo or file, the app container has no byte-identical copy | Pass — run log A |
| 3 | `testVideoTempDeletedOnClose` | The playback file exists during play and is gone after close | Pass — run log A |
| 3 | `testVideoTempSweptOnLaunch` | A file left in the playback directory is removed at launch | Pass — run log A. Sweeper call, not a killed process |
| 3 | Device: kill during playback, then relaunch | Container check shows the temp file gone after the next launch. Note in the result that this is not forensic erasure | Not run |
| 4 | `testImportKillLeavesOriginals` | Process interrupted after copy starts and before verify: source file still present, vault has no item | Pass — run log A. Stage then sweep. Process was not killed |
| 4 | `testDeleteOriginalsOnlyAfterVerify` | Delete-originals API is not called when the hash check fails | Pass — run log A |
| 5 | `testDelaySurvivesNewStore` | Five failures set a 30 second wait. A new counter instance loaded from the same store still waits | Pass — run log A. Second `VaultService` on the same memory store. Not a reboot |
| 5 | Device: kill and reboot | Wrong-PIN count is unchanged after force-quit and after reboot. Short screen recording | Not run |
| 5 | UI test, Phase 2 | App switcher snapshot is the cover, not the vault | Not run |
| 6 | `testDecoyHasNoRecoveryWrap` | Decoy bundle has a lock wrap and no recovery wrap | Pass — run log A |
| 6 | `testUnlockPayloadIsIdentical` | The analytics struct for a real unlock and a decoy unlock compares equal | Pass — run log A. Struct compare. No analytics network |
| 6 | `testBothWrapsAreTried` | A spy KDF records two derivations when a decoy exists, and two when only a dummy exists | Pass — run log A |
| 7 | `testRecoveryRoundTrip` | Generate, test by re-entry, unlock, set a new PIN, old PIN fails, new PIN works, decoy VMK unchanged | Pass — run log A |
| 7 | `testRecoveryDoesNotOpenDecoy` | Recovery words do not unwrap the decoy | Pass — run log A |
| 7 | UI, Phase 2 | "I saved my key" is disabled until the test succeeds. Screen recording | Not run |

### Run log A — 4 Nov 2026

Applies to every gate row marked "Pass — run log A".

- Git revision: none. This folder is not a git repository.
- Device: iPhone 17 Simulator, arm64, id `9D49818B-3C45-48FB-B9B9-5902F48C96C9`.
- OS: iOS 26.3.1 (build 23D8133). Xcode 26.3 (17C529).
- Command: `xcodebuild -project CipherRoll.xcodeproj -scheme CipherRoll -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath build test -only-testing:CipherRollTests`
- Result: 25 passed, 0 failed (`SecurityCoreTests` and `DesignSystemTests`).
- Encryption tests inject 1,000 PBKDF2 iterations. `testProductionIterationFloor` checks that the production floor constant is at least 600,000 and that the scaling function returns the floor when a sample would fall short. It does not execute 600,000 iterations.
- Bundle sealing in these tests is software AES-GCM (`SoftwareBundleSealer`). The Secure Enclave sealer was not used.
- Same run, also pass, not a gate row: `testPINMinimumIsSixDigits`, `testChangeLockSecretKeepsItemBytes`, `testProductionIterationFloor`.

## Scenarios the reviewer asked for (3 Nov)

| Scenario | How | Expected | Result |
|---|---|---|---|
| Passcode removed | Device test, gate 2 | Vault does not open with PIN or recovery words | Not run |
| iPhone replaced | New device, no `.crbackup` | Items are absent. Recovery words do not recreate them | Not run |
| Recovery key lost | Unlock with PIN only | Vault opens. There is no second copy of the words in the app | Not run |
| App deleted and reinstalled | Delete app, install again | Items are gone. Keychain items are gone | Not run |
| Restore from iCloud or Finder backup | Restore onto a device | Vault files are not back, or are back and still cannot unwrap, because backup exclusion and This-device-only Keychain both apply. Record which one happened | Not run |
| Restore from `.crbackup` | Export, delete app, install, restore | Items appear as a new vault. Wrong password does not restore. Decoy items are absent | Not run |
| Wrong PIN after kill and reboot | Device recording | Counter and delay still apply | Not run |
| Temp video after kill, crash, and interrupted playback | Device, container listing | File removed on next launch. Result text avoids any erasure claim | Not run |
| Decoy versus real analytics | Proxy or test sink, consent on | Payloads match. No name, PIN, note, or search word. Consent off: no analytics request | Not run |

## Backup tests (document 9, after Phase 1 exists)

| Test | Expected | Result |
|---|---|---|
| Export, delete app, reinstall, restore | New vault, items readable with the new PIN | Not run. Needs a device |
| Wrong password | Error, no items added, no detail about the file | Pass — run log C. `wrongPassword` only. The error text does not mention the salt or the header. The vault count does not change |
| Truncated file | Fixed `bad_file` error | Pass — run log C |
| Kill during export | No half-imported vault. Partial file is not treated as valid | Pass as a staged stop — run log C. Writing stops after the header, the finished file is not created, reading the partial returns `bad_file`, and sweep removes it. The process was not killed |
| Kill during restore | Vaults that were already on the device are unchanged | Pass as a staged halt — run log C. Stopping after the new vault is created leaves an `incomplete` marker. The next sweep removes that vault. The original item is still readable. The process was not killed |
| Large video | Memory stays bounded (stream). Record the peak | Chunked frames — run log C. A payload larger than one chunk is sealed as separate frames, and the plaintext marker is not in the file. Peak memory was not measured, so this is not a device pass |
| Decoy exists during export | Decoy items are not in the file. UI never says "decoy" | Pass — run log C. A decoy session cannot export. The real vault's file does not contain the decoy bytes. Backup screen copy has no "decoy". With a decoy present, the lock screen still tries only two secrets, so the restored vault is opened by its own id in the test |

## Copy review (gate item 9)

Search the app target and the store text for `encrypted`, `military`, `unhackable`, and `nobody can see`. Expected before sign-off of the gate: no matches in UI strings. Design documents may use those words.

| Search | Result |
|---|---|
| Curated UI copy (`LockCopy`, settings, paywall, help, share, invite) | Pass — run log B. `testReviewedCopyAvoidsBannedClaims` |
| App target `CipherRoll/**/*.swift` | Pass — run log B. One hit: `SecKeyCreateEncryptedData` in `EnclaveSealer.swift`, an API name, not UI copy |
| App Store title, subtitle, keywords, screenshots | Not run. No store listing is in this folder |

Gate item 9 stays open while the store-listing row is "Not run".

## Phase 7 QA (doc 11 section 13)

| Check | Result |
|---|---|
| Analytics consent declined sends nothing | Pass — run log B. In-process gate. `testDeclinedConsentSendsNothingAndAllowedEventsHaveNoContent` and `testDeclinedConsentIsNotSent`. Mixpanel is not linked. No network proxy was used |
| Analytics consent allowed sends names only | Pass — run log B, same in-process sink. Unlock properties are `method` = `face_id` or `secret` only. A property key such as `filename` or `query` is rejected by `AnalyticsPrivacy.namesContent` |
| Decoy versus real analytics payload | Pass as a struct compare — run log A, `testUnlockPayloadIsIdentical`. Network payload still not run |
| Share extension at the free limit | Pass — run log B for the rule: the original is not removed, and the limit message says nothing was removed. `testShareLimitLeavesTheOriginal`. A live share-sheet session was not run |
| Wrong PIN delay survives a new store | Pass — run log A, `testDelaySurvivesNewStore`. Six wrong PINs on a device, and survival across reboot, are not run |
| Kill app during import | Pass as a staged sweep — run log A, `testImportKillLeavesOriginals`. The process was not killed |
| Contrast, 44 pt target, Reduce Motion duration | Pass — run log B. `testBodyTextPairsClearContrast`, `testMotionAndTouchTargetMatchTheHandoff`. Gold buttons use navy `#14233B`. Reduce Motion fade is 150 ms. This is not a VoiceOver or Dynamic Type session on a device |
| Largest accessibility Dynamic Type | Not run on a device. Long import names wrap, and the consent, photo-denied, notification, and share-unlock screens scroll |
| VoiceOver on lock, import, paywall, share | Not run with VoiceOver on. Labels were added for the calculator keys, paywall plans, import rows, and the share sheet |
| Airplane-mode purchase | Not run |
| Trial-used Apple ID | Not run |
| Restore on a second device | Not run |
| Delete app and reinstall | Not run. The delete-app warning is in Help and on Security and storage |

### Run log B — 4 Nov 2026

Applies to every row marked "Pass — run log B".

- Git revision: none. This folder is not a git repository.
- Device: iPhone 17 Simulator, arm64, id `9D49818B-3C45-48FB-B9B9-5902F48C96C9`.
- OS: iOS 26.3.1 (build 23D8133). Xcode 26.3 (17C529).
- Command: `xcodebuild -project CipherRoll.xcodeproj -scheme CipherRoll -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath build test -only-testing:CipherRollTests`
- Result: 73 passed, 0 failed. The share extension target compiled in the same build.
- The analytics check is an in-process sink. No proxy, and Mixpanel was not started.
- Copy search of the app target was a source search on 4 Nov 2026, plus `testReviewedCopyAvoidsBannedClaims`.

### Run log C — 4 Nov 2026

Applies to the backup rows marked "run log C".

- Git revision: none. This folder is not a git repository.
- Device: iPhone 17 Simulator, arm64, id `9D49818B-3C45-48FB-B9B9-5902F48C96C9`.
- OS: iOS 26.3.1 (build 23D8133). Xcode 26.3 (17C529).
- Command: `xcodebuild -project CipherRoll.xcodeproj -scheme CipherRoll -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath build test -only-testing:CipherRollTests`
- Result: 84 passed, 0 failed. Log: `/tmp/cipheroll-backup-test.log`.
- Backup KDF in these tests is 1,000 iterations. The production floor constant is 600,000 and was not executed.
- The pack is still unsigned. No security gate item is complete.

## App Review notes (for the submission, not a gate pass)

- Calculator-style lock: optional calculator-style PIN screen for privacy. The app is a vault, not a calculator. It is off until the user turns it on in Settings, Privacy and lock. Help says it is not a real calculator. There is no PIN built into the app. Prepare the review device with PIN `135790`, then turn the calculator screen on. The `=` key submits that PIN.
- Subscriptions: weekly, yearly, and lifetime. The paywall shows the price, the period, auto-renew text, Cancel anytime in Settings, Restore, and Manage. No monthly plan.
- Alternate icons: Calculator, Notes, Weather, Utility. iOS shows its own icon-changed alert. The name under the icon stays CipherRoll.
- Analytics: default off. Allow on the first-launch consent screen, or later in Settings. This build does not start Mixpanel.
- Break-in selfie: off by default. A photo is taken only after the user turns it on, and it stays on the iPhone.
- No account is required. An invite email, if entered, stays on the device and is not sent. Invites do not grant Pro in this build.
- Backup: Settings, Export a backup, writes a file protected by a password the user chooses. A forgotten password cannot be reset. Restore adds a new vault and does not overwrite what is already there. Export all items is still a separate action. Do not describe the app as encrypted, military-grade, or unhackable.

## How a result is recorded

Add a line under the row: date, git revision, device model, OS version, command (`xcodebuild test -only-testing:...`) or "manual", and pass or fail. Attach the container listing or the recording name. Then, and only then, the matching gate row in the Phase 1 report may say pass.
