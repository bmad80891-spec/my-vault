
# Supabase Authentication and Recovery Plan

## 1. Goals
- Add My Vault account registration and login.
- Support email and phone verification.
- Keep the local vault usable offline.
- Keep account verification separate from vault decryption.

## 2. Current Architecture
- Flutter for Android and Windows.
- Local SQLite database.
- AES-256-GCM encryption.
- PBKDF2-HMAC-SHA256 for master-password key derivation.
- Authenticator TOTP entries stored in the encrypted vault.

## 3. Supabase Authentication
Supabase Auth will manage account identity only.

- Email verification confirms control of the email address.
- Phone verification confirms control of the phone number.
- Signing in must never automatically unlock the local vault.
- The master password must never be sent to Supabase.

## 4. Vault Recovery Design
The planned design uses a random Data Encryption Key (DEK).

- Vault data is encrypted using the DEK.
- The DEK is wrapped using a key derived from the master password.
- A separate recovery secret is generated locally.
- The DEK is also wrapped using a key derived from the recovery secret.
- The recovery secret must never be sent to Supabase.
- Email or SMS password reset must never bypass vault encryption.
- Losing both the master password and recovery secret means encrypted data cannot be recovered.

This design requires cryptographic review and tests before implementation.

## 5. Security Rules
- Never commit Supabase service-role keys.
- Never put privileged secrets in the Flutter application.
- Use Row Level Security (RLS) for user-owned cloud data.
- Never upload vault entries or TOTP secrets during the authentication phase.
- SMS verification may require a paid provider.

## 6. Implementation Phases
1. Approve the architecture.
2. Configure the Supabase project.
3. Add the Flutter Supabase dependency.
4. Implement email and phone authentication.
5. Implement verification and sign-out.
6. Test offline vault access.
7. Review the recovery design separately.
8. Design encrypted synchronization and RLS in a separate change.

## 7. Acceptance Criteria
- Users can register and verify accounts.
- Users can sign in and sign out.
- Failed and expired verification is handled.
- Supabase login does not unlock the vault.
- Existing local vaults remain usable offline.
- No privileged credentials are committed.
- Automated tests cover authentication and vault separation.

## 8. Not Included Yet
- Cloud synchronization.
- Cloud storage of vault passwords or TOTP secrets.
- Automatic vault recovery through email or SMS.
- Production-ready security certification.
