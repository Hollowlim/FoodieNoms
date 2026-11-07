# Email password recovery

Customer, vendor and administrator accounts use the same Firebase Auth email/password recovery. Vendors can reset while approval is pending or revoked. No role lookup, Firestore permission or administrator approval is required to request recovery.

## How to use

1. On customer/vendor or administrator sign-in, tap **Forgot password?**. You do not need to enter a password or fill the login form first.
2. Enter the email registered to that account. Gmail and other email providers work. If an admin username was entered, its existing login email is prefilled when it can be resolved locally.
3. Tap **Send password reset link**, then open Gmail/email. Check Spam or Junk if needed.
4. Open the reset link and choose a new password on Firebase’s hosted reset page.
5. Return to FoodieNoms and sign in with the new password. Admin usernames still work with their existing linked account.

Signed-in users can also go to Profile → Account settings / Password & security. That page uses the current account’s registered email and the same recovery screen.

The email must belong to an inbox the user can access. Creating a Firebase account with a Gmail-looking address does not create a Gmail mailbox. Recovery changes the FoodieNoms password, not the Gmail password.

## Implementation

- `lib/firebase/password_reset.dart`: email validation/normalization, existing admin alias resolution, neutral missing-account handling and reset-specific errors.
- `lib/firebase/password_recovery.dart`: shared recovery form, check-email instructions, resend countdown, busy state, retry and registered-email account-settings mode.
- `lib/firebase/service.dart`: `requestPasswordReset` delegates to Firebase Auth `sendPasswordResetEmail`.
- `lib/firebase/app.dart`: public login and all three account-settings entry points.
- `test/password_recovery_test.dart`: validation, every account type, failures, double sends, resend cooldown, alternate email, settings and narrow-screen/keyboard tests.
- `tool/password_reset_emulator_check.dart`, `tool/run_password_reset_check.sh`: real Auth emulator round trip, without real emails or production account changes.

No packages, Firestore collections/rules, custom SMTP credentials, Cloud Functions or billing changes are needed. The registered account UID and profile/role remain the same. The public response does not confirm whether an email has an account. Missing-account errors are handled the same way whether or not email enumeration protection is enabled in the Firebase project.

This uses Firebase’s secure email **reset link**, rather than a custom six-digit code. That matches the existing Spark setup and uses Firebase’s built-in expiry and single-use checks. The 60-second resend countdown is a convenience in the screen; Firebase’s server-side email quotas and abuse limits remain authoritative.

Sources: [Firebase Flutter password reset](https://firebase.google.com/docs/auth/flutter/manage-users#send_a_password_reset_email), [Firebase email limits](https://firebase.google.com/docs/auth/limits#email_sending_limits).

## Checks

Completed checks: `flutter analyze` reports no issues; all 120 Flutter tests pass, including 11 recovery tests. Four real Auth-emulator journeys pass. The project’s built-in reset page returns HTTP 200. The iOS simulator build succeeded and was installed/launched in the existing iPhone 18 Pro Device Hub simulator.

The isolated Auth emulator check covers three email/password accounts representing customer, vendor and administrator recovery. It verifies sending while signed out, the correct recipient, reset completion, rejection of code reuse, rejection of the old password, successful new-password login with the same UID, and preserving a signed-in session when requesting another email. A fourth check verifies the neutral response for an unregistered email. It does not claim to test real Gmail inbox delivery.

Run the UI suite with `flutter test test/password_recovery_test.dart`. With Flutter, Firebase CLI and Chrome on PATH, run `sh tool/run_password_reset_check.sh` for Auth-only integration checks. Emulator account passwords and reset links are used only with the explicit `demo-foodienoms` project on localhost.
