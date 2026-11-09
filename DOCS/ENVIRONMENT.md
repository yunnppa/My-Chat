# Environment and Secrets

## Local configuration
Use environment/configuration management appropriate to the project.

Never commit:
- API secrets
- private keys
- service-account JSON
- production credentials
- GIF provider secret keys

Firebase client configuration files should follow Firebase's platform setup requirements, while privileged service-account credentials must remain server-side.

## GIF provider
The client should call a backend endpoint/function for protected GIF API operations when a secret API key is required.

## Environments
Prefer:
- development
- staging
- production

Do not accidentally point development builds at production databases/storage.

## Firebase
Configure:
- Authentication
- Firestore
- Storage
- Cloud Messaging
- App Check
- Cloud Functions
- security rules
- indexes
