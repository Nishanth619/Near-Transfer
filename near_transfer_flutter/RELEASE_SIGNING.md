# Release Signing Configuration

## Step 1: Generate Release Keystore

Run this command in your terminal to create a keystore:

```bash
keytool -genkey -v -keystore e:/shreit/project/near_transfer_flutter/android/app/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

You'll be prompted for:
- **Keystore password**: Choose a strong password (remember it!)
- **Key password**: Can be same as keystore password
- **Your name**: Your full name
- **Organization**: Your company name
- **City, State, Country**: Your location

## Step 2: Create key.properties file

Create this file at `android/key.properties`:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../app/upload-keystore.jks
```

## Step 3: Update build.gradle.kts

The signing config has been added to your build.gradle.kts.

## Important Notes

- **NEVER** commit keystore or key.properties to git
- **BACKUP** your keystore file - you need it for every update
- Add to `.gitignore`:
  ```
  android/key.properties
  android/app/*.jks
  android/app/*.keystore
  ```
