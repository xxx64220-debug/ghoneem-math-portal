# Portal phone notifications

Students: sign in, choose **Notifications**, then **Enable notifications**. On iPhone, first install the portal on the Home Screen. New practice and results alerts default on. Daily practice reminders are optional, at 18:00 Africa/Cairo. Each device has separate preferences. Turn off or sign out to unsubscribe that device. Existing open portal tabs may need to be closed and reopened once to activate the updated service worker; active exams are never forcibly reloaded.

Administrator: the **Notifications** tab sends an announcement to opted-in enrolled students, either all tracks or one track. Review the message before sending. The history reports push-service acceptance, not proof of delivery or reading. Expired device subscriptions are removed. **Send me a test** targets only the current device.

The isolated `portal_push_*` tables and the `portal-notifications` function belong only to the existing math Supabase project. No ledger/finance data is used. Service-only storage has RLS and no browser grants. The function verifies users with the existing portal session rules, admin role for announcements, and a separate secret for scheduled dispatch. Only supported vendor push endpoints are accepted. Private signing keys and the scheduler credential are provisioned outside source control.

`portal-push-delivery` runs every minute. Queue claims are atomic, ten devices per run; failures retry after five minutes, up to three attempts and at most 24 hours. Pending alerts recheck account status and relevant preferences before sending. Notifications contain no scores or answer data. Push delivery depends on browser permission, connectivity, and OS notification settings.

Apply `supabase/sql/portal_notifications.sql`, privately provision one VAPID keypair and worker secret in `portal_push_config`, deploy the function, then apply `supabase/sql/portal_notification_schedule.sql`. Preserve the same signing key for existing subscriptions. Never package configuration rows into web assets.

Validation: client and inline-script syntax; service-worker tests for safe taps, offline fallback, and untouched API calls; live encryption generation in the deployed runtime without sending; transactional database tests for access, no historical backlog, queue deduplication and claims; HTTP checks for unauthenticated and invalid-worker rejection; scheduled dispatcher check. Actual notification display must be confirmed on an opted-in phone using **Send me a test**.
