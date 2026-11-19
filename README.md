# My Vault

A Flutter app for a personal account vault targeting Android and Windows.

## Implemented

- Responsive Flutter interface with Arabic/English and RTL/LTR.
- First-run master-password setup and vault unlock screen.
- Local SQLite database for account records.
- Account add, edit, view, delete, and search.
- Account payloads encrypted with AES-256-GCM before database persistence.
- A key derived from the master password using PBKDF2-HMAC-SHA256.
- The master password itself is not stored. Locking clears the in-memory key.

## Important security notes

This is an early implementation and has not yet had an independent security audit. Do not use it as the only copy of important credentials or enter real account passwords until the implementation has been reviewed and tested on your devices. If the master password is lost, this local vault cannot currently be recovered.

The sync service, encrypted backups, TOTP authenticator, QR scanning, biometric unlock, and recovery flow are not implemented yet. Never commit real passwords, recovery codes, 2FA seeds, or encryption keys to this repository.

## Build locally

Install the Flutter stable SDK, then run:

```bash
flutter pub get
flutter test
flutter run
```

## GitHub Actions

Push to `main` or run **Build My Vault** from the Actions tab. Download the generated APK or Windows build from the workflow's Artifacts section.
