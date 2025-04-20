# CI/CD Setup Guide for Android Release Automation

This guide explains how to set up automated builds and releases to the Google Play Store.

## Prerequisites

- A GitHub repository for your Flutter project
- A Google Play Console account with your app already published
- Android keystore file for app signing

## Setup Steps

### 1. Encode your keystore file to base64

```bash
base64 -i your-keystore.jks -o keystore-base64.txt
```

### 2. Create a service account for Google Play Console

1. Go to Google Play Console
2. Navigate to Setup > API access
3. Create a new service account or use an existing one
4. Grant the service account access to your app with the "Release manager" role
5. Create and download a JSON key file

### 3. Add GitHub Secrets

Add these secrets to your GitHub repository:

- `KEYSTORE_BASE64`: The content of keystore-base64.txt
- `STORE_PASSWORD`: Your keystore password
- `KEY_PASSWORD`: Your key password
- `KEY_ALIAS`: Your key alias
- `PLAY_STORE_SERVICE_ACCOUNT_JSON`: The entire content of the service account JSON key file

### 4. Update Release Notes

Before each release, update the release notes in:
```
distribution/whatsnew/en-US.txt
```

## Using the Workflow

1. Go to the Actions tab in your GitHub repository
2. Select "Android Release" workflow
3. Click "Run workflow"
4. Select the version type:
   - `patch`: Increases the third number (1.0.0 → 1.0.1)
   - `minor`: Increases the second number and resets patch (1.0.1 → 1.1.0)
   - `major`: Increases the first number and resets others (1.1.0 → 2.0.0)
5. The build number will automatically increment by 1

The workflow will:
- Update version numbers in pubspec.yaml
- Build a signed Android App Bundle (AAB)
- Upload it to Google Play Store (production track)
- Commit the version change back to your repository 