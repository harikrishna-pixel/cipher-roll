# CipherRoll — analytics events

Follows `02_Marberx_Standard_Analytics_Events.md`. Use standard names first. Only the **CipherRoll-specific** table is new. **No ads events** (no ads in V1). Tool: Mixpanel, `<CipherRoll>-Dev` project for debug builds. `distinct_id` = RevenueCat appUserID. Updated 2 Nov 2026 (v2).

## Consent (new)
- Show a consent screen on first launch: "Allow anonymous usage stats?" with Allow / Not now. Link to the privacy policy. Default off in EU/UK; recommended default off everywhere until the policy is final.
- Before consent: send nothing except purchase events that RevenueCat sends by itself. Do not start the Mixpanel SDK.
- Setting: Settings, Privacy, "Share anonymous usage stats" (on/off). Turning off stops events at once and calls `reset()`.
- Event: `analytics_consent_answered` (`answer`: allowed, declined) is stored locally and sent only if allowed. `analytics_consent_changed` (`on`).
- App Store privacy label: Usage Data, not linked to identity, only when on. Privacy policy lists the events in this doc.

## Privacy rules (stricter than standard)
- Never send item names, file names, note text, album names, vault names, PINs, phrases, recovery key, photo metadata, location or **search words**.
- Counts as buckets only: `item_count_bucket` (0, 1–10, 11–50, 51–100, 100+).
- Never log the lock *value*, only the *type*.
- Decoy: log `decoy_created` once. Never log which PIN was used at unlock, and never log `decoy_opened`.
- Break-in selfie: log only that the setting was turned on/off. Never the photo or attempt details.
- Calculator-style lock: log only `lock_type = calc_pin`.

## Super properties (every event)
`app_version`, `ios_version`, `is_pro`, `plan` (free / trial / weekly / yearly / lifetime), `trial_eligible`, `goal` (onboarding pick), `theme`, `session_number`, `vault_count_bucket`, `lock_type`, `analytics_consent` (true only; events do not exist otherwise).

## Standard events used
| Area | Events used |
|---|---|
| App & onboarding | `app_opened`, `onboarding_step_viewed` (`step`: demo, create_pin, pick_items, import_done, face_id_offer, paywall), `onboarding_completed`, `permission_requested` / `permission_result` (`type`: camera, face_id, notifications, photos_delete_originals) |
| Monetization | `paywall_viewed` (`trigger`, `variant`: yearly, weekly, lifetime, trial_used, offline), `paywall_closed` (`dismiss`: x, maybe_later, continue_free), `plan_selected` (`plan`: weekly, yearly, lifetime), `purchase_started`, `trial_started`, `purchase_succeeded`, `purchase_failed`, `purchase_cancelled`, `purchase_pending`, `purchase_offline`, `restore_result`, `trial_reminder_scheduled`, `limit_reached` (`type`), `pro_feature_tapped`, `free_alternative_used`, `exit_offer_shown` (A/B cell), `manage_subscription_tapped` |
| Cross-promotion | `more_apps_opened`, `more_apps_tapped` (Settings only) |
| Referral | `invite_entry_opened`, `signup_*`, `login_*`, `invite_link_shared`, `invite_code_redeemed`, `referral_qualified`, `referral_rewarded` |
| Prompts & support | `rating_requested` (native prompt requested, `moment`: import_done, weekly_recap; Apple decides if it shows), `feedback_opened` (Settings), `notification_prompt_shown`, `help_article_opened` (slug from doc 09), `support_contacted` |
| Errors | `error_shown` (`type`, `code`), `error_recovery_action` |
Removed: `rating_prompt_answered` (no pre-prompt screen exists).

## CipherRoll-specific events
| Event | When | Properties |
|---|---|---|
| `vault_created` | New vault saved | `lock_type`, `is_first` |
| `lock_type_set` | Lock created or changed | `lock_type` (pin, pattern, password, phrase, calc_pin), `face_id_on` |
| `vault_unlocked` | Successful unlock | `method` (face_id, secret), `seconds_since_last` bucket |
| `unlock_failed` | Wrong attempt | `attempt_bucket` (1, 2–4, 5+). No vault info |
| `recovery_key_created` / `recovery_key_tested` (`result`) / `recovery_key_saved` (`how`: copy, files, print) / `recovery_used` (`result`) | Recovery flow | as listed |
| `import_started` / `import_completed` / `import_failed` | Import flow | `source` (photos, files, camera, share_ext), `type`, `item_count_bucket`, `error_code` |
| `originals_prompt_answered` | Delete originals question | `answer` (review_delete, keep) |
| `originals_deleted` | After iOS confirms | `item_count_bucket` |
| `item_opened` | Viewer opened | `type` |
| `item_exported` | Item exported | `type`, `count_bucket` |
| `export_all_started` / `export_all_completed` | Export all | `item_count_bucket`, `size_bucket` |
| `search_used` | Search submitted | `filter`, `result_count_bucket`. Never the query |
| `decoy_created` | Decoy set up | none |
| `breakin_selfie_toggled` | Setting changed | `on` |
| `usage_sheet_opened` | Usage sheet | `percent_bucket`, `nearest_limit_type` |
| `home_chip_tapped` | Free plan chip | `nearest_limit_type` |
| `trial_ended_state_viewed` | After-trial screen | `plan_before` |
| `share_ext_opened` (`source_app_type`) | Extension opened | |
| `share_ext_unlocked` | Unlocked in extension | |
| `share_ext_saved` | Saved | `type`, `item_count_bucket` |
| `share_ext_cancelled` | Closed | |
| `share_ext_limit_hit` | Over a free limit | `type` |
| `lock_screen_shown` | Lock shown | `first_method` |
| `lock_method_switched` | User switched method | `from`, `to` |
| `welcome_back_shown` / `welcome_back_action` | Daily return card | `variant`, `action` |
| `recap_shown` / `recap_dismissed` | Weekly recap | none |
| `storage_warning_shown` | Low iPhone storage | none |
| `backup_status_viewed` | Security & storage opened | `status` |
| `switcher_hidden_toggled` / `lock_delay_changed` | Settings | `value` |
| `analytics_consent_answered` / `analytics_consent_changed` | Consent | see above |
| `app_icon_changed` | App icon picker, after iOS confirms | `icon` (cr_lock, calculator, notes, weather, utility) |
| `backup_export_started` / `backup_export_completed` | Export a backup | `item_count_bucket`. Never the file name, password or vault name |
| `backup_saved` | Save to Files or Share tapped | `method` (files, share) |
| `backup_restore_started` / `backup_restore_completed` | Restore from backup | `item_count_bucket` |
| `backup_restore_failed` | Restore | `reason` (wrong_password, bad_file) |

## Paywall `trigger` values
`onboarding`, `exit`, `limit_photos`, `limit_videos`, `limit_files`, `limit_notes`, `second_vault`, `decoy_vault`, `usage_sheet`, `home_chip`, `settings`, `trial_day2_banner`, `trial_ended`, `welcome_back`, `referral_reward_end`, `value_framing`.

## Dashboards
Activation (onboarding_completed → import_completed → originals_prompt_answered → second session) · Recovery key health (created → tested → saved) · Unlock reliability · Paywall by trigger × trial_eligible × variant · Plan mix (weekly vs yearly vs lifetime) · Exit paywall A/B · Free-limit funnel · Import failure rate by source · Share extension funnel · Consent rate · D1/D7/D30 retention by `goal`.

## Dev check
1. Run with a network proxy: confirm no payload contains item names, query text or PINs.
2. Confirm `vault_unlocked` never states real vs decoy.
3. With consent declined, confirm no Mixpanel request leaves the device.
