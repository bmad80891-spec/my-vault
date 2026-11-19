# My Vault

A Flutter starter for a personal vault interface targeting Android and Windows.

## Current status

This repository currently contains the **starter UI only**:
- Responsive dashboard with desktop navigation rail and mobile bottom navigation.
- Arabic/English language toggle and RTL/LTR layout.
- Vault, Authenticator, Security, and Settings sections.
- Initial GitHub Actions workflows for Android APK and Windows builds.

## Not implemented yet

Authentication, encrypted local storage, end-to-end encrypted sync, password entry management, TOTP generation, QR scanning, and encrypted backups are future development tasks. Do not store real passwords, recovery codes, or 2FA secrets in this starter.

## Build locally

Install the Flutter stable SDK, then run:

```bash
flutter pub get
flutter run
```

## GitHub Actions

Push to `main` or run **Build My Vault** from the Actions tab. Download the generated APK or Windows build from the workflow's Artifacts section.

## Security direction

The planned design is offline-first. Sensitive data must be encrypted on the device before it is persisted or synchronized. The sync service must never receive plaintext vault contents. Use established cryptographic libraries and platform-backed key storage; never commit keys or secrets to this repository.
