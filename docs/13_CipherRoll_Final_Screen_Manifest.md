# CipherRoll — final screen manifest (v1.1, 3 Nov 2026)

This is the one list the developer builds from. Anything marked **DO NOT BUILD** is old and stays only in `old/` folders. If a PNG, a doc paragraph or the canvas disagrees with this list, this list wins.
Canvas: CipherRoll UI (v29). Mac: `Documents/Projects/UI Update and Brand Positioning/7.Utility apps/10.Vault/UI/`. Every screen has light and dark.

## A. Build these (final)
| Order | Folder | Screens |
|---|---|---|
| 1 | Screens batch 2 | 01 Onboarding demo, 02 Question 1 (private), 03 Question 2 (unlock), 04 Photos permission, 05 First lock done |
| 2 | Screens batch 3 | 01 Create PIN, 02 Import progress, 03 Import done, 04 Face ID offer, 11 Import paused |
| 3 | Core screens | 01 Choose lock type, 02 Recovery key setup, 10 Lock PIN, 11 Lock custom phrase, 12 Lock calculator-style PIN |
| 4 | Screens batch 6 | 09 Lock Face ID first |
| 5 | Core screens | 05 Home trial, 06 Home free plan, 07 Import picker, 08 Import over limit |
| 6 | Screens batch 3 | 12 Usage sheet (ring), 13 Home free (calm chip), 07 Settings, 08 Security and storage, 09 Recently Deleted, 10 Referral reward |
| 7 | Screens batch 2 | 06 Photo viewer, 07 Video player, 08 File viewer, 09 Note editor, 10 Select mode, 11 Vault switcher, 12 Usage sheet |
| 8 | Screens batch 4 | 01 Home trial ends tomorrow, 02 Decoy vault, 03 Break-in selfie permission, 04 Photos permission denied, 05 Empty vault, 06 Albums, 07 Search, 08 Restore none found, 09 Paywall offline |
| 9 | Screens batch 6 | 01 Paywall onboarding, 02 Paywall exit, 03 Paywall trial used, 04 Paywall limit reached, 05 Paywall value framing, 06 Paywall Weekly selected, 07 Paywall Lifetime selected, 08 Trial ended |
| 10 | Screens batch 6 | 10 Share to CipherRoll, 11 Share saved |
| 11 | Screens batch 5 | 01 Welcome back daily, 02 Welcome back after 9 days, 03 Weekly value recap, 06 Invite a friend, 07 Notifications permission, 08 Notification examples, 09 Toasts and messages, 11 More from Marberx |
| 11b | Screens batch 7 | 01 Pattern lock, 02 Photo grid, 03 Analytics consent, 04 Privacy and lock settings (new 3 Nov) |
| 11c | Screens batch 8 (new 3 Nov) | 01 Choose app icon (CR lock, Calculator, Notes, Weather, Utility), 02 Export a backup, 03 Backup ready, 04 Restore from backup, 05 Restore wrong password, 06 Restored. Folder `09_Backup_and_icons` |
| 11d | Screens batch 9 (new 3 Nov) | iPad 11 inch key screens: 01 Lock, 02 Home, 03 Photo grid, 04 Photo viewer, 05 Import, 06 Paywall, 07 Settings, 08 Export a backup. Folder `10_iPad_and_Duo`. All other screens follow the iPhone designs with the adaptive rules in doc 11 section 10 |
| 11e | Screens batch 10 (new 3 Nov) | iPhone Duo outer (closed, vertical bar) and inner (open): Lock, Home, Photo grid, Photo viewer, Paywall. Folder `11_iPhone_Duo` |
| 12 | Store screenshots (not for developer) | Set E chosen 3 Nov (paper style). Sets A to D are older. iPhone Duo set (outer 1398 x 2034, inner 2007 x 2853, 4 each) in `UI/Store screenshots iPhone Duo`. Ship the "Encrypted" wording only after security sign-off |
| 13 | Store screenshots B | 01 to 07, same art, headlines 1 and 5 say "Encrypted". **Ship only after security sign-off (doc 11 section 1)**. Then also update title/subtitle, Help "encryption" answer and doc 11 section 8 |

## B. DO NOT BUILD (superseded)
| Old screen | Where | Replaced by |
|---|---|---|
| 03 Paywall onboarding, 04 Paywall exit, 09 Paywall limit reached | Core screens | Batch 6 01, 02, 04 |
| 05 Trial ended, 06 Paywall trial used | Screens batch 3 | Batch 6 08, 03 |
| 10 Paywall value framing | Screens batch 5 | Batch 6 05 |
| 04 Rating pre-prompt, 05 Feedback if not yet | Screens batch 5 | Native iOS rating prompt only (SKStoreReviewController). No pre-prompt, no star gate. Optional "Send feedback" lives in Settings |
| Any 3-day trial text | all | 7-day trial, only if StoreKit says eligible |
| Any monthly plan | all | Weekly, yearly, lifetime only |
| Anything in an `old/` folder, `old_zips/` | Mac | — |
| Old store screenshots | `Store screenshots/old/` | New 7 |
| Old logo files | `Logo/` except `CipherRoll_Icon_Round2.png` | Pending icon choice |
| Any ads, ATT prompt, "Pro" or credit label in store art | all | None in V1 |

## C. Signed decisions (v3)
| Topic | Decision |
|---|---|
| Name | CipherRoll (trademark check pending) |
| Ads | None in V1 |
| Free plan | 1 vault, 100 photos, 10 videos, 10 files, 10 notes |
| Plans | Weekly $1.99, yearly $19.99 (pre-selected, 7-day trial if eligible, reminder on day 6), lifetime $39.99. No monthly |
| Dismiss text | "Maybe later" on onboarding, value, Weekly, Lifetime. "Continue with Free" on exit, trial used, limit |
| Exit paywall | A/B test, control = none |
| After plan ends | Nothing deleted. 1 vault editable, others read-only |
| Lock on open | Vault's chosen method first. Face ID starts at once, PIN is the backup |
| Share Extension | Free plan. Decoy vault is Pro |
| Calculator lock | In V1. Settings entry, App Review notes with a test PIN, honest description |
| Photos | PHPicker needs no photo permission. Optional access only for "delete originals" |
| Rating | Native prompt only, after a success moment |
| Analytics | Mixpanel, consent screen + privacy label (see doc 10) |
| Referral | 7 days Pro each, max 10 per year |
| More from Marberx | Settings only |
| Icon | **B · CR lock** (chosen 3 Nov): `Logo/CipherRoll_Icon_B_1024.png`. Also a plain "Utility" alternate icon (developer draws a simple version) |

## D. Copy rules (all screens)
1. No absolute claims: no "encrypted", "unhackable", "military-grade", "nobody can see". Allowed: "Vault contents stay on this iPhone", "Unlocks with Face ID", "Locked on your iPhone".
2. Say "Nothing was deleted" when a plan ends. No fear words.
3. Paywalls always show price, period, auto-renew and "Cancel anytime in Settings". Weekly button: "Continue with Weekly". Lifetime: "Get lifetime access", "One payment of $39.99".
4. Trial line only when `isEligibleForIntroOffer` is true.
5. Break-in selfie: "The photo stays on this iPhone and is not uploaded."
6. Search: "Search runs on this iPhone."

## E. Accessibility rules (apply to every screen)
| Rule | Value |
|---|---|
| Text on gold | Navy `#14233B` only. Never white on gold |
| Dynamic Type | Support all sizes including accessibility sizes. Layouts wrap or scroll, never clip |
| VoiceOver | Every flow: lock, import, paywall, share. Label icon-only buttons |
| Touch targets | 44 x 44 pt minimum |
| Reduce Motion | Replace slides and springs with 120 to 180 ms fades |

## F. Sign-off
| Item | Owner | Status |
|---|---|---|
| Final screen list approved | Praba | Done 3 Nov |
| Icon chosen: B CR lock | Praba | Done 3 Nov |
| Trademark check | Praba | Not checked yet |
| Phase 0A security design (doc 11 section 1B) signed off before vault storage is built | Developer + reviewer | Open |
| Security gate (doc 11 section 1), with test evidence. Passing it unlocks "Encrypted" copy and store set E | Developer | Open |
| Encrypted export and restore for V1 | Praba | Approved 3 Nov, screens in batch 8 |
| Asset rights (fonts, icons, stock photos in demo) | Praba | Open |

## G. Security decisions added 3 Nov (reviewer approved)
| Decision | Screens changed |
|---|---|
| PIN minimum 6 digits (no 4-digit); optional 8+ or alphanumeric | Create PIN ("Choose at least 6 digits...") |
| Recovery key covers real vaults only | Recovery key ("Opens your vaults if you forget your PIN. It cannot recover deleted items or restore files if you lose this iPhone.") |
| Decoy: own PIN and keys, no recovery, warning shown | Decoy vault (3 points incl. "If you forget the decoy PIN, its items cannot be recovered.") |
| iCloud Photos note when deleting originals | Import done |
| Alternate app icons (5 choices, free) | Screen in batch 8, icons drawn by the developer in the same style |
| Backup export and restore (real vaults only, never the decoy) | Batch 8 screens 02 to 06 |
| iPad and iPhone Duo support in V1 (universal app, built with Xcode 27.1 SDK) | Decided 3 Nov. Reference screens in batches 9 and 10 |
