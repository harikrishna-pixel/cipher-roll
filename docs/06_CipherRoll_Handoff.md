# CipherRoll — project handoff (v3, 3 Nov 2026)

**What:** iOS private vault app. Name CipherRoll (trademark check not done yet). Utility app #10. Mac folder: `Documents/Projects/UI Update and Brand Positioning/7.Utility apps/10.Vault/`. This file replaces the older 2 Nov versions. The build list is `13_CipherRoll_Final_Screen_Manifest.md`.

## Decisions (signed)
| Topic | Decision |
|---|---|
| PIN (3 Nov) | Minimum 6 digits, no 4-digit; optional 8+ or alphanumeric |
| Recovery key (3 Nov) | Real vaults only; never covers the decoy; must not reveal it |
| Decoy (3 Nov) | Own PIN and keys, no recovery, clear warning on setup |
| Phase 0A (3 Nov) | Security design documents first, then vault code; no security item complete without test evidence |
| Temp video files (3 Nov) | Protected temp files allowed in V1 as a documented trade-off; no forensic-erasure claim |
| Ads | None in V1 |
| Free plan | 1 vault, 100 photos, 10 videos, 10 files, 10 notes |
| Plans | Weekly $1.99, yearly $19.99 (pre-selected, 7-day trial only if StoreKit-eligible, day-6 reminder), lifetime $39.99. No monthly in V1 |
| Paywalls | Onboarding, exit (once, A/B, control = none), trial used, limit, value, Weekly, Lifetime. Positive copy, auto-renew text, no price repeated outside plan cards |
| Dismiss text | "Maybe later" (onboarding, value, Weekly, Lifetime); "Continue with Free" (exit, trial used, limit) |
| After plan ends | "Nothing was deleted." 1 vault editable, others read-only |
| Lock | Vault's chosen method first; Face ID auto-starts, PIN backup. Types: PIN, pattern, password, phrase, calculator-style PIN |
| Recovery key | One per install, test before "I saved my key" |
| Decoy vault | Pro. Share Extension works on Free |
| Photos | PHPicker, no photo permission to import; optional access only to delete originals |
| Rating | Native iOS prompt only |
| Analytics | Mixpanel with a consent screen (doc 10) |
| Copy | No absolute security claims; "Encrypted" allowed only after the security gate is signed off |
| Icon | **B · CR lock** (chosen 3 Nov). Files in `Logo/`. Add a plain "Utility" alternate icon |
| Store screenshots | Set E (paper style, no tags). "Encrypted" wording ships only after security sign-off. Not part of the developer package |
| Referral | 7 days Pro each, max 10 per year, optional login |
| More from Marberx | Settings only |
| Cloud backup | Later version |
| Stack | **Native Swift (SwiftUI)**, chosen 3 Nov by the developer. Flutter files kept as optional |

## Status
| Stage | State |
|---|---|
| UI: core, batches 2 to 7 (light and dark) | Done. Praba approved the screen list (3 Nov) |
| Docs 09, 10, 11, 13 | Updated 3 Nov |
| Developer package | Built 3 Nov (see doc 13 and the package README) |

## Open items
| Item | Owner |
|---|---|
| Trademark check (Cipher Memories was the closest); buy cipherroll.com/.app | Praba |
| Security gate: AES-256-GCM per item, Keychain, import verify, no temp copies, decoy and recovery tests | Developer |
| Asset rights: fonts, icons, demo photos | Praba |
| Free-plan chip shows the limit nearest to full (spec in doc 11; screens show photos) | Developer |
| Website and daily guides engine (AWS or WHM); Astro seed packs are research only | Later |
| Decide store set and ship "Encrypted" wording after sign-off | Praba |
