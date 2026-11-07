# Administrator usernames and account assignment

Admin123 is the owner alias for the real Firebase administrator. Its underlying email is configured only through ADMIN_LOGIN_EMAIL at build time, without putting a password or a public email directory in the app. The local config/admin.local.json supplies that email and is ignored by Git.

Run locally with:

    flutter run --dart-define-from-file=config/admin.local.json

Other Gmail administrators use their Gmail handle as username; non-Gmail administrators can sign in with their full email. Everyone uses the shared login screen, labelled Email or username; there is no separate public administrator sign-in or registration option. Firebase checks the actual password and the users/{uid} role, and opens the matching account interface. Public registration offers customer and vendor account types only.

Real admins have Vendors, Administrators and Profile tabs. Administrators → Add administrator accepts a new person's name, a separate email, a generated or entered temporary password (at least 12 characters), and the acting admin's password for reauthentication. A confirmation explains that the recipient can approve vendors and create more administrators.

Provisioning uses a secondary Firebase Auth app, leaving the current administrator signed in. The primary Firestore client creates a strictly validated new admin profile. Existing customer/vendor/admin profiles are never overwritten or promoted through this flow. No password or password hash is written to Firestore or logs. A password-reset/setup email lets the recipient choose their own password; an email failure leaves the account intact and can be retried from the list. Failed provisioning attempts clean up only the newly created Auth account where failure can be confirmed.

The admin-only create rule uses the actor's existing role, creator UID, server timestamp, strict field allowlist and a different target UID. Only admins may list admin and vendor profiles; the customer directory remains restricted. First-owner setup still requires trusted project-owner provisioning; app registration cannot create a first admin.

Validation includes username tests, Firestore permission tests, and a real Flutter client against Auth/Firestore emulators checking authorization, primary session preservation, duplicate-email handling, no password fields, and a new admin's access to vendor applications. No billing upgrade or deployed Cloud Functions are required.
