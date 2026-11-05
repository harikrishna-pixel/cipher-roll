# CipherRoll developer package (v1.3, 3 Nov 2026)

Stack: **native Swift (SwiftUI)**, one universal app for **iPhone, iPad and iPhone Duo**. Read in this order:
1. `00_Product_Brief_for_Developer.md`
2. `01_Common/Docs/13_...Screen_Manifest.md` (what to build, what NOT to build, signed decisions)
3. `01_Common/Docs/11_...Developer_Handoff.md` (security gate section 1, backup section 9, devices section 10)
4. `02_Native_iOS/00_Native_iOS_Stack.md`, then the Cursor prompts.

## Order of work
| Step | What |
|---|---|
| Phase 0A | Security design documents only, no code. Threat model, key management, Secure Enclave check, recovery design, test plan. Praba and the reviewer sign it off. Vault storage is not built before this |
| Phase 0 to 7 | Setup, security core, lock and onboarding, home and import, paywalls, safety and settings, share extension and help, polish |
| Phase 8 | iPad and iPhone Duo pass. Build with Xcode 27.1 and the iOS 27.1 SDK or later |
Rule: no security requirement is marked complete without a reproducible test result.

## Folders
| Folder | What is inside |
|---|---|
| 01_Common/Docs | 13 manifest, 11 handoff, 10 analytics events, 09 Help and FAQ, 06 decisions, 02 standard event names |
| 01_Common/Screens | Light and dark PNGs in 11 groups, build order inside each. 01 Onboarding, 02 Lock and recovery, 03 Home and import, 04 Viewers and vaults, 05 Safety and privacy, 06 Paywalls, 07 Share extension, 08 Retention, 09 Backup and icons, 10 iPad (8 key screens), 11 iPhone Duo (outer and inner) |
| 01_Common/Icon, Overviews | Icon B (CR lock) 1024 PNG, 180 PNG, SVG. Overview images of every batch |
| 02_Native_iOS | Used. Stack doc, `cipherroll_ios.mdc` (copy to `.cursor/rules/`), Cursor phase prompts (Phase 0A to 8) |
| 03_Flutter_optional | Not used. Kept only in case the stack changes |
| security_gate_questions.md | Security questions with the proof to ask for |

Cursor setup: copy `01_Common/Docs` to `docs/` and `01_Common/Screens` + `01_Common/Icon` to `design/`.
Not included on purpose: store screenshots, old versions, research files.

## What changed on 3 Nov (compared with the first package)
| Change | Where |
|---|---|
| PIN is 6 digits minimum (no 4-digit). Optional 8+ or alphanumeric | Doc 11 section 1A, Create PIN screen, Help |
| Recovery key covers real vaults only, never the decoy. Decoy has its own PIN and keys, no recovery | Doc 11 1A, Recovery and Decoy screens |
| Security gate now 9 items with test evidence. Phase 0A added | Doc 11 section 1 and 1B, prompts |
| Temp video files allowed in V1 only as a documented trade-off. No "forensic erasure" claim | Doc 11 item 3 |
| Encrypted backup export and restore, real vaults only | Doc 11 section 9, batch 8 screens |
| Alternate app icons: CR lock, Calculator, Notes, Weather, Utility (free) | Batch 8 screen, doc 11, event `app_icon_changed` |
| iPad and iPhone Duo support in V1 | Doc 11 section 10, screens 10 and 11, Phase 8 |
| Pattern lock, photo grid, analytics consent, Privacy and lock screens | Batch 7 screens |
| iCloud Photos note when deleting originals, device-loss warning | Import done screen, Help |

Open before release: Phase 0A sign-off, security gate with test evidence, trademark check, asset-rights check (fonts, icons, demo photos).
Rules in short: no ads, no absolute security claims until the gate passes, trial UI only if StoreKit says eligible, nothing deleted when a plan ends, Share extension on Free.
