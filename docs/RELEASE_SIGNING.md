# Release signing

ReceiptWise uses application ID `com.anhvy.receiptwise` and a dedicated release
signing configuration. Debug builds still use Flutter's normal debug key.
Release builds require ignored `android/key.properties`; there is no silent debug
signing fallback.

For this workspace a private PKCS12 keystore is generated at
`android/receiptwise-release.jks`. Its random password is stored only in the
ignored `android/key.properties`. Neither file belongs in GitHub or screenshots.
Back up both securely outside the checkout. Losing the key can prevent future
updates to installed releases. Do not print passwords in CI/build logs.

After cloning, supply your own private keystore and create `android/key.properties`:

```properties
storeFile=receiptwise-release.jks
storePassword=YOUR_PRIVATE_PASSWORD
keyAlias=receiptwise
keyPassword=YOUR_PRIVATE_PASSWORD
```

`storeFile` is resolved relative to the Android project directory. An absolute
keystore path is also accepted. Use Java `keytool` to create a key, or use the
secure backup of this project's existing key when building an update.

```powershell
flutter build apk --release
```

The new application ID differs from earlier `com.example.receiptwise` debug
builds. Android installs it as a separate app; existing transactions in the old
app are not migrated. The older app's files are not changed by this build.

Signing verification proves the APK has a valid dedicated certificate. It does
not replace camera/OCR/persistence testing on a physical Android device.
