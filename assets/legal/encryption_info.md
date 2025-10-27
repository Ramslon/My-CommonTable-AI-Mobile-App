# Encryption & Security

- Transport security: All network traffic uses HTTPS/TLS.
- Data at rest: Firebase secures stored data; device keychain/keystore is used for sensitive preferences (Flutter Secure Storage).
- Authentication: Firebase Authentication (anonymous/email) supports per-user scoping of data.
- Biometrics: When enabled, access to the app is gated by device biometrics (Face ID/Touch ID/fingerprint).

Compliance-ready foundation includes consent logging, data export, and account deletion controls within the app.
