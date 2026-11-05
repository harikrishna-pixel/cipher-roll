# Marberx standard analytics events

Use these names in **every** Marberx app so all apps can be compared in one Mixpanel dashboard. App-specific details go in properties, not new event names. For CipherRoll, doc 10 is the list to build; it uses these names first. CipherRoll has no ads, so skip the Ads row.

## Rules
- `object_action`, snake_case, past tense. Fire once, after the action succeeded.
- Never send file names, paths, emails, names or free text. Mixpanel "ignore IP" on.
- Super properties on every event: `app_version`, `ios_version`, `is_pro`, `plan`, `goal`, `theme`, `session_number`.
- Sizes/lengths may be buckets (`size_bucket`, `duration_bucket`).
- Debug builds go to a separate `<App>-Dev` Mixpanel project. `distinct_id` = RevenueCat `appUserID`.

## Core set
| Area | Events |
|---|---|
| App & onboarding | `app_opened`, `onboarding_step_viewed`, `onboarding_question_answered`, `onboarding_completed`, `permission_requested`, `permission_result`, `preferences_changed` |
| Monetization | `paywall_viewed` (`trigger`, `trial_eligible`), `paywall_closed`, `plan_selected`, `purchase_started`, `trial_started`, `purchase_succeeded`, `purchase_failed`, `purchase_cancelled`, `purchase_pending`, `purchase_offline`, `restore_result`, `limit_reached`, `pro_feature_tapped`, `free_alternative_used`, `exit_offer_shown` / `_accepted` / `_expired`, `manage_subscription_tapped` |
| Cross-promotion | `more_apps_opened`, `more_apps_tapped` (`app`, `position`) |
| Account & referral | `invite_entry_opened`, `signup_started` / `_completed` / `_failed`, `login_completed` / `_failed`, `invite_link_shared`, `invite_code_redeemed`, `referral_qualified`, `referral_rewarded` |
| Prompts & support | `notification_prompt_shown`, `help_article_opened`, `support_contacted` |
| Errors | `error_shown` (`type`, fixed `code`), `error_recovery_action` |
