# CipherRoll — developer handoff (Flutter / Cursor)

Status: **design handoff v1.3 (3 Nov 2026, reviewer decisions added). Build only after the security gate (section 1) is signed off.** Name CipherRoll (trademark pending). Screens to build: `13_CipherRoll_Final_Screen_Manifest.md` (wins over any PNG). Decisions: `06_CipherRoll_Handoff.md` + manifest section C. Help copy: `09`. Events: `10`.

## 1. Security gate (must pass before release)
**Rule: no item is marked done without reproducible test evidence (test name + result). Security and recovery are finalised in Phase 0A, before any vault storage is built.**

| # | Requirement | How to prove |
|---|---|---|
| 1 | Vault items stored with real file protection. AES-256-GCM per item; item keys wrapped by a vault key; vault key wrapped by a key derived from the lock secret (PBKDF2 or Argon2id, high cost) | Code review + raw files unreadable |
| 2 | Keys in iOS Keychain with `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`. If the iPhone has no passcode, warn the user and do not create a vault. Secure Enclave: feasibility study in Phase 0A (see section 1A) | Test: remove passcode, restart, restore |
| 3 | No plaintext kept after viewing. Photos and files decrypt to memory. Video may use a protected temporary file (iOS file protection, excluded from backup), deleted after playback and at every launch. Do not claim forensic erasure | Check app container after viewing, kill app, crash, interrupted playback |
| 4 | Import integrity: copy, verify (hash/size), only then offer "delete originals". Failed import leaves originals untouched | Interrupt import test |
| 5 | Lock: attempt counter with growing delay that survives app kill and reinstall of the same session; app-switcher snapshot hidden; lock on every return | Manual + unit test |
| 6 | Decoy: own PIN, own keys, own store. Unlock must not reveal which vault opened. No clue about the decoy in logs, analytics, crash reports or timing. We do not promise protection against a forensic examiner | Review + payload check |
| 7 | Recovery key: real vaults only, never the decoy. One per install; shown once; "I saved my key" enabled only after key test. The key must not reveal that a decoy exists | Reset PIN via key; decoy unaffected |
| 8 | Data-loss warnings shown: no backup, app deletion, new iPhone, Export all | Screens in batch 3/4 |
| 9 | Marketing and in-app copy: no "encrypted", "military-grade" or "nobody can see" claim until 1 to 7 pass and a review signs it | Copy review |

### 1A. Signed security decisions (3 Nov 2026, reviewer approved)
| Topic | Decision |
|---|---|
| PIN length | Minimum 6 digits for the main and the decoy PIN. No 4-digit PIN. Optional 8+ digits or alphanumeric passcode for more strength. Persistent attempt limit with growing lockout. Face ID is a shortcut |
| Recovery key | Covers real vaults only. Never covers the decoy. Must not reveal the decoy |
| Decoy vault | Own PIN, own keys, no recovery. Forgotten decoy PIN means its items are lost for good. Face ID preferably off for decoy. Setup screen warns clearly |
| Secure Enclave | Investigate in Phase 0A. It does not do AES-GCM and does not stop offline PIN guessing by itself. Developer must show a device-bound unwrap design with rate limiting. It is device-bound, so test recovery in each scenario below before promising anything |
| Temp video files | Allowed for V1 only as a documented trade-off, with strict cleanup (see item 3) |
| Storage | V1 is local-only and excluded from iCloud backup. If the iPhone is lost or replaced the files are gone, even with the recovery key (the key unlocks data, it cannot recreate files). Recommended: add a user-controlled encrypted export and restore (open decision, see manifest) |
| Scenario tests (must be run and recorded) | Passcode removed · iPhone replaced · recovery key lost · app deleted and reinstalled · restore from backup/new device · wrong PIN counter after kill and reboot · decoy vs real analytics payload |

### 1B. Phase 0A — security design first (documents only, no code)
Deliver before Phase 1: threat model · encryption architecture · key management (key tree, wrapping, rotation on PIN change) · Secure Enclave feasibility result · recovery design · Swift module structure · implementation phases · test plan (all scenarios above). Praba and the reviewer sign it off. Vault storage is not built until then.
Allowed sentences now: "Locked on your iPhone." "Vault contents stay on this iPhone." "Unlocks with Face ID."

## 2. Stack
**Native Swift (SwiftUI) was chosen on 3 Nov. Use `00_Native_iOS_Stack.md` for the stack. The table below is the Flutter option, kept for reference. Everything outside this section is the same for both.**

| Item | Choice |
|---|---|
| App | Flutter, iOS 16+, iPhone and iPad (universal) V1, see section 10 |
| Purchases | RevenueCat + StoreKit 2. Trial UI only if `isEligibleForIntroOffer` |
| Analytics | Mixpanel behind an `Analytics` interface. Consent first (section 11) |
| Ads | None. No ads SDK, no ATT prompt |
| Icons | Phosphor bold. lock→`lock-simple`, image→`image-square`, video→`video-camera`, file→`file-text`, note→`note-pencil`, key→`key`, eye→`eye-slash`, face→`scan-smiley`, shield→`shield-check`, search→`magnifying-glass`, share→`export` |
| Font | Manrope 500/600/700/800, bundled |
| Storage | App container, `NSFileProtectionComplete`, excluded from iCloud backup |
| Face ID | `local_auth`; shortcut only, never the sole lock |
| Camera | Front camera for break-in selfie, only after consent screen |
| Photos | PHPicker only. No photo-library permission needed to import. Optional read-write access is asked only when the user taps "Review and delete originals" |
| Rating | `SKStoreReviewController` only. No pre-prompt screen, no star gate |
| Share Extension | In V1, works on Free (section 9) |

## 3. Design tokens (navy and gold)
| Token | Light | Dark |
|---|---|---|
| bg | #F4F5F7 | #0B1220 |
| card | #FFFFFF | #141E31 |
| ink | #101828 | #F2F5FA |
| sub (muted text) | #4F5A6D | #B3BDD0 |
| line | #DDE1E8 | #2A3754 |
| hero (navy card) | #14233B | #1B2B4A |
| gold (primary CTA) | #E0B050 | #E6BE6A |
| on-gold text | #14233B | #14233B |
| tint / tint-ink | #E8EEF7 / #1F3A5F | #22324F / #B5CCF2 |
| link | #1F3A5F | #B5CCF2 |
| amber / amber-bg | #B7791F / #FFF4DC | #E8B04A / #3A2D12 |
| danger | #C2412D | #F0836F |
Radius: card 20, button pill (28), chip 999, sheet 28 top. Spacing 4/8/12/16/20/24. Type (Manrope): title 28 to 30/800, H2 20/800, body 16/500, caption 13/600. Never put white text on gold.

## 4. Screens
Includes batch 7 (pattern lock, photo grid, analytics consent, Privacy and lock settings). See `13_CipherRoll_Final_Screen_Manifest.md` section A (build list) and B (DO NOT BUILD). PNGs: `UI/Core screens`, `Screens batch 2` to `6`, `Store screenshots`. File names `NN_Name_light|dark.png`; overviews `00_Overview_*`.

## 5. Rules per feature
**Free limits:** 1 vault, 100 photos, 10 videos, 10 files, 10 notes. At a limit: block add, show limit paywall (`trigger=limit_<type>`). Home chip shows the type nearest its limit (for example "Free plan · 8 of 10 videos"), not always photos. Ring only in the usage sheet.
**Paywall:** weekly $1.99, yearly $19.99 pre-selected, lifetime $39.99. Yearly CTA shows the 7-day trial only if eligible: "Then $19.99/year, renews automatically. Cancel anytime in Settings. We'll remind you before your trial ends." Not eligible: "$19.99/year. Renews automatically until cancelled. Cancel anytime in Settings." Weekly CTA "Continue with Weekly" with "$1.99/week, renews automatically. Cancel anytime in Settings." Lifetime CTA "Get lifetime access" with "One payment of $39.99. No subscription. Restore any time." Day-6 local reminder if notifications are allowed. Gray X top-right. Dismiss text: "Maybe later" (onboarding, value, Weekly, Lifetime), "Continue with Free" (exit, trial used, limit). Exit paywall once per install, no countdown, A/B cell (control = none).
**Subscription value (App Review 3.1.2):** Pro keeps giving: ongoing updates, restore on any device with the same Apple ID, unlimited vaults and items, decoy vault. No sync is promised. Do not list features that are not built.
**After plan ends:** nothing deleted or hidden ("Nothing was deleted."). 1 vault stays editable (user picks); others read-only; items above free limits stay viewable and exportable.
**Lock:** opens in the vault's chosen method first. Face ID starts at once, PIN backup. Delay setting (Immediately / 1 min / 5 min). 5 wrong attempts: 30 s delay, growing. Break-in selfie after N wrong attempts if enabled.
**Import:** PHPicker, copy, verify, success, ask to delete originals. Never auto-delete.
**Export all:** zip of originals to Files/share sheet.
**Referral:** optional login, 7 days Pro each, max 10 rewards/year, server-checked.
**More from Marberx:** Settings only.
**Permissions:** primer screen first (Camera, Notifications; Photos only for delete originals). Denied state has "Open Settings". Photos-denied copy: "Photo access is optional. You can still choose photos to add."
**Rating:** native prompt after a success moment (import done, not on first launch). Max per Apple rules.
**Motion:** push 250 ms ease-out, sheets spring. With Reduce Motion on: 120 to 180 ms fade.

## 6. Copy rules
Positive words only. No fear, loss or pressure words ("lose", "last chance", "only", "expires", "locked out", countdowns, red). No absolute security claims (section 1 #8). Required legal facts stay in small calm text: price, period, auto-renew, cancel in Settings. Do not repeat price outside the plan cards.

## 7. States to build
Loading · empty · offline (purchase) · error with fixed `code` · permission denied · trial-eligible vs trial-used · free vs trial vs paid · light vs dark · all Dynamic Type sizes.

## 8. Store assets
Icon: **B · CR lock**, `Logo/CipherRoll_Icon_B_1024.png` (1024 square, no rounded corners; iOS rounds it). Alternate app icons (batch 8): CR lock (default), Calculator, Notes, Weather, Utility, picked in Settings, Privacy and lock, App icon. Free for all. Use `UIApplication.setAlternateIconName`; iOS shows its own "icon changed" alert, which cannot be hidden. The name under the icon stays "CipherRoll". Draw the 4 alternate icons in the same simple style as the picker (original art, do not copy Apple app icons). Disclose in the App Review notes, same as the calculator-style lock. Screenshots: `UI/Store screenshots/` 7 images, navy and gold, no price, no Pro or credit labels, no absolute claims. Keyword safety: Astro packs A, B, C are research only. Do not put competitor names or unsupported terms (for example "encrypted", "military") in title, subtitle, keywords or screenshots in V1. Privacy label: declare Usage Data (not linked) if Mixpanel is on; "Data not collected" only if analytics is off.

## 9. Share Extension (V1, Free plan)
- Target "Save to CipherRoll": images, videos, PDFs, files, text (as note).
- Needs unlock first (vault's own lock). App Group for the store; keys in Keychain access group.
- Sheet: preview, vault picker (last used), "Save N items". Success: "3 photos are now saved in CipherRoll." with the line "The original stays in the source app. Saving here does not remove it."
- Never deletes the original. At a free limit: gentle message, limit paywall in the main app.
- Extension memory is small: stream large videos.
- Decoy vault is not offered as a share target unless it is unlocked.
- Events: doc 10 (`share_ext_*`).

## 10. Unlock first
Every open or return shows the vault's chosen method first. Face ID: starts at once, "Welcome back" screen with "Use PIN instead" and "Switch vault". Wrong Face ID twice moves to the vault's own lock. No method picker at launch.

## 11. App Review and compliance notes
| Topic | What to do |
|---|---|
| Calculator-style lock (1.1 / 2.3) | Disclose in the App Review notes: "Optional calculator-style PIN screen for privacy; the app is a vault, not a calculator." Give a test PIN. Add a Settings entry and describe it honestly in Help |
| Subscription (3.1.2) | Show ongoing value (section 5), auto-renew text, Restore purchases, Manage subscription, links to Terms and Privacy |
| Paid features in screenshots (2.3.2) | Screenshots have no Pro labels. If a screenshot shows a Pro feature, say so in the caption or leave it out |
| Analytics | Consent screen before Mixpanel starts (first launch, "Allow anonymous usage stats?"; default off for EU/UK). Setting to change it. Privacy policy lists events. No names, content or PINs sent |
| Break-in selfie | Off by default. Consent screen explains: front camera, photo saved only in your vault, not uploaded. Needs camera permission string |
| Permission strings | Camera: for break-in selfie. Face ID: to unlock. Photos add-only/read-write: only for "delete originals" |
| Account | No sign-in needed; sign-in only for referral |
| Terms | Do not claim "private" in a legal sense or "secure" beyond what is proven |

## 12. Accessibility
Navy text on gold (never white). Dynamic Type to accessibility sizes, no clipping. VoiceOver labels on every icon button and for lock, import, paywall and share flows. Touch targets at least 44 x 44. Reduce Motion plan in section 5. Contrast: body text at least 4.5:1.

## 13. QA checklist
Kill app during import · wrong PIN x6 · decoy vs real analytics payload · airplane-mode purchase · trial-used Apple ID · restore on second device · delete app and reinstall (items gone, warning was shown) · largest accessibility Dynamic Type · Reduce Motion · VoiceOver on lock, import, paywall, share · analytics consent off sends nothing · share extension at free limit.

## 9. Backup export and restore (batch 8, new 3 Nov, reviewer recommended)
| Topic | Rule |
|---|---|
| Why | V1 is local-only and excluded from iCloud backup. A recovery key cannot recreate files, so a lost or replaced iPhone loses everything unless the user made a backup file |
| Export | Settings, Export a backup. Choose a vault (the real vaults only, never the decoy), set a backup password (at least 10 characters, entered twice, not the PIN). Create a `.crbackup` file. Then Save to Files or Share. Warning shown: a forgotten backup password cannot be reset |
| Protection | Backup file is protected by a key derived from the backup password (Argon2id or PBKDF2, high cost, AES-256-GCM). The design is signed off in Phase 0A. Until the security gate passes, use the words "protected by your password", not "encrypted" |
| Restore | Settings, Restore from backup. Pick file, enter password, items are added as a new vault ("Personal (restored)"). Nothing on the iPhone is overwritten. Wrong password shows an error and no detail. Restored vault uses the PIN set on this iPhone. Offer a new recovery key |
| Decoy | Never included in a backup and never restored. Do not mention the decoy anywhere in the export or restore flow |
| Plan limits | Export is free for all (data is the user's). Restore of items above free limits follows the "after trial" rule in doc 06 |
| Tests (Phase 0A list) | Export then delete app then reinstall then restore · wrong password · corrupted file · interrupted export · interrupted restore · large file memory use · backup with decoy present |
Screens: `01_Common/Screens/09_Backup_and_icons`.

## 10. Devices: iPhone, iPad and iPhone Duo (V1, decided 3 Nov)
| Topic | Rule |
|---|---|
| Targets | iPhone, iPad (all sizes) and iPhone Duo (Apple's foldable, 7.6 inch open, 5.4 inch closed). One universal app, not separate apps |
| Layout | Adaptive SwiftUI only. Branch on size classes (compact/regular), never on device model or `UIScreen.main`. No fixed 390 point widths. Respect each safe-area edge separately (a system bar can sit on the left or right) |
| iPad | Regular width: sidebar (vaults, library, settings) plus content (`NavigationSplitView`). Photo grid uses adaptive columns (5 or more). Viewer shows the photo with a details panel. Import, Export, Restore and Paywall are centered sheets. All orientations, Split View and Stage Manager. Compact width (Split View narrow) falls back to the iPhone layout |
| iPhone Duo | Outer (closed) display: compact width, so it behaves like an iPhone, but the tab bar and toolbars move to the trailing edge as a vertical bar. Inner (open) display: regular width and height, about 1.42:1, so it behaves like iPad, also in Split View. Detect the vertical bar with `toolbarVerticalEdge` (SwiftUI) or `verticalBarEdge` (UIKit), not with orientation. Use the standard `TabView`, toolbars and `NavigationSplitView` so bars and sidebars move on their own. Every tab needs a title and an icon. Safe areas are asymmetric: handle each edge separately and check `reservedRegions` for the camera area. Posture changes are trait changes, not a relaunch: keep state and scroll position. Do not require folding. Half-folded: system sheets adapt around the fold, keep content away from the crease. Sheets: use `presentationPlacement` to choose centered, leading or trailing. `ArrangementView` is iOS 27.1+ only, gate it. No UIScreen.main, no device-model checks |
| Duo build | Use Xcode 27.1 and the iOS 27.1 SDK or later for edge-to-edge layout. Test closed, half-folded and open in the Duo simulator. These points come from Apple's App Store Connect notice and developer summaries. The developer must confirm them in Apple's "Designing for iPhone Duo" HIG page and "Preparing your app for iPhone Duo" |
| Duo App Store | Screenshot sizes: outer 1398 x 2034 (portrait) or 2034 x 1398, inner 2007 x 2853 or 2853 x 2007, 1 to 10 images, JPEG or PNG, no transparency. Building with the iOS 27.1 SDK and submitting Duo screenshots shows a "Made for iPhone Duo" badge. Reported: Duo screenshots become required for apps built with the 27.1 SDK from April 2027, verify in App Store Connect |
| Biometrics | Do not hardcode "Face ID" in strings. Read `LAContext.biometryType` and show Face ID or Touch ID (iPhone Duo uses Touch ID) |
| Copy | Say "this device" in warnings when a screen can run on iPad. The phone screens say "iPhone" and stay as designed |
| Reference images | `01_Common/Screens/10_iPad_and_Duo`: 8 iPad screens (834 x 1194 points, 11 inch portrait). `01_Common/Screens/11_iPhone_Duo`: Lock, Home, Photo grid, Viewer and Paywall for the outer (closed, vertical bar) and inner (open) displays. Duo point sizes are not published by Apple: the files are 1398 x 2034 and 2007 x 2853 pixels (3x assumed) and are illustrative. Other screens: use the iPhone design inside the same adaptive rules (centered, max content width about 560 points for forms) |
| Store | Add iPad screenshots (13 inch) at submission, and iPhone Duo screenshots (set in `UI/Store screenshots iPhone Duo`, not for the developer) |
| Tests | iPhone SE, iPhone Pro Max, iPad mini, iPad Pro 13, iPad Split View narrow and half, Stage Manager resize, rotation, iPhone Duo simulator (closed, open, half-folded, Split View) |
