# Security Overview

## Encrypted API Key Storage

Your OpenAI API key is now stored **securely and encrypted** using the system Keychain.

### How It Works

- **Before**: API keys were stored in UserDefaults (unencrypted)
- **After**: API keys are stored in Keychain (encrypted by the OS)

### Automatic Migration

When you first launch the app after this update:
1. Any existing API key in UserDefaults is automatically moved to Keychain
2. The old unencrypted copy is deleted
3. All future storage uses encrypted Keychain

### Implementation

```swift
// Old way (INSECURE):
@AppStorage("openai_api_key") private var apiKey: String = ""

// New way (SECURE):
@KeychainStorage("openai_api_key") private var apiKey: String = ""
```

### Security Benefits

✅ **Encrypted at rest** - API key encrypted by macOS/iOS
✅ **Protected by device lock** - Only accessible when device unlocked
✅ **Sandboxed** - Only your app can access your keychain items
✅ **No cloud sync** - Keys stay on device (not iCloud Keychain)
✅ **Automatic migration** - Existing keys moved securely

### Additional Security Features

- **HTTPS Only**: All network requests use secure HTTPS
- **No SQL Injection**: App uses JSON files, not databases
- **Validated Process Execution**: Only trusted system tools (`/usr/bin/lipo`, `/usr/bin/file`)
- **Read-Only File Access**: App only reads plugin directories, never modifies system files
- **Sandboxed**: macOS/iOS App Sandbox prevents unauthorized file access

## Security Rating: **A-**

The app follows security best practices with encrypted credential storage and minimal attack surface.

## For Developers

### Using KeychainHelper

```swift
// Save
KeychainHelper.save(key: "my_secret", value: "sensitive_data")

// Load
if let secret = KeychainHelper.load(key: "my_secret") {
    print("Secret: \(secret)")
}

// Delete
KeychainHelper.delete(key: "my_secret")

// Check existence
if KeychainHelper.exists(key: "my_secret") {
    print("Secret exists")
}
```

### Using @KeychainStorage Property Wrapper

```swift
@KeychainStorage("api_token") var token: String = ""

// Use like any normal property
token = "sk-abc123..."
print(token) // Automatically loads from Keychain
```

## Threat Model

### Protected Against
- ✅ API key exposure through UserDefaults dumps
- ✅ Command injection in plugin scanning
- ✅ Man-in-the-middle attacks (HTTPS only)
- ✅ Unauthorized file system access (sandboxed)

### Not Protected Against
- ⚠️ Device compromise with full disk access
- ⚠️ Debugger attached to running process
- ⚠️ User intentionally sharing API key

### Recommendations
- Don't share your device with untrusted users
- Keep macOS/iOS updated
- Use strong device password/biometrics
- Monitor OpenAI API usage for anomalies
