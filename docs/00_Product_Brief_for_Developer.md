# CipherRoll — product brief (read this first)

**What it is:** a private vault app for iPhone, iPad and iPhone Duo. People lock photos, videos, files and notes behind a PIN (at least 6 digits), pattern, password, phrase or Face ID / Touch ID. Vault contents stay on the device. No account is needed.
**Who it is for:** people who want private photos and files kept out of the normal Photos app. Competitor reference: Vaultaire.
**Name and icon:** CipherRoll. Icon B (CR lock), plus alternate icons (Calculator, Notes, Weather, Utility). Brand colours: navy and gold. Font: Manrope.
**Who we are:** Marberx Technologies. Praba is the product director. He does not code. Ask him product questions in plain words.

## How the app makes money
| Item | Value |
|---|---|
| Ads | None. Never add an ads SDK or an ATT prompt |
| Free plan | 1 vault, 100 photos, 10 videos, 10 files, 10 notes |
| Paid plans | Weekly $1.99, yearly $19.99 (7-day trial only if the Apple ID is eligible), lifetime $39.99. No monthly |
| Pro adds | Unlimited vaults and items, decoy vault |
| Tools | RevenueCat + StoreKit 2 |

## Main promises to the user (do not break these)
1. Vault contents stay on this device. Nothing is uploaded. Each device has its own vault, no sync.
2. Import never deletes the original unless the user says so, and only after the copy is checked.
3. When a plan ends, nothing is deleted. 1 vault stays editable, others become read-only.
4. The lock shows every time the user returns. The vault's own unlock method comes first.
5. The recovery key is the only way back if the PIN is forgotten. It covers real vaults only, never the decoy. We cannot reset it.
6. The decoy vault has its own PIN and keys and no recovery. A forgotten decoy PIN means its items are lost.
7. If the device is lost or replaced, files are gone unless the user made a backup (Export a backup, protected by a password the user chooses).

## Hard rules
- **Phase 0A first:** write the security design documents before any vault code (doc 11 section 1B). Do not mark any security requirement complete without a reproducible test result.
- Build the security gate (doc 11, section 1). Do not use the words "encrypted" or "military-grade" in the app or store until it passes and is signed off. Never claim forensic erasure.
- Build only the screens listed in `01_Common/Docs/13_CipherRoll_Final_Screen_Manifest.md`. Anything marked DO NOT BUILD is old.
- One universal app, adaptive layouts only (doc 11 section 10). Build with Xcode 27.1 and the iOS 27.1 SDK or later.
- Analytics: ask consent first. Never send names, notes, PINs, search words.
- Follow doc 11 for tokens, copy rules and App Review notes (disclose the calculator-style lock and the alternate icons).

## Files in this package
`01_Common` (Docs: read 13, then 11, 10, 09, 06 · Screens in build order, 11 groups · Icon · Overviews) · `02_Native_iOS` (chosen stack: Swift and SwiftUI, Cursor rules and build prompts, Phase 0A to 8) · `03_Flutter_optional` (not used) · `security_gate_questions.md`. See `00_README.md` for what changed on 3 Nov.
