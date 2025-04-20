# Android Release Automation Scripts

These scripts automate the process of building an Android app bundle, incrementing version numbers, and uploading to Google Play Store.

## Prerequisites

1. Flutter SDK installed and configured
2. Java Development Kit (JDK) installed
3. Node.js installed (for the upload script)
4. Google Play Console service account credentials

## Setup

1. **Google Play Console Service Account**:
   - Go to Google Play Console → Setup → API access
   - Create a service account with "Release manager" permissions
   - Download the JSON key file
   - Save it as `service-account.json` in the scripts directory

2. **Install Dependencies**:
   ```bash
   cd scripts
   npm install
   ```

3. **Make Scripts Executable**:
   ```bash
   chmod +x release-android.sh
   chmod +x play-upload.js
   ```

## Usage

### Option 1: Full Automated Release

Run the release script with the version type to increment:

```bash
./release-android.sh [patch|minor|major]
```

This will:
1. Increment the version according to the specified type
2. Build the Android App Bundle
3. Prompt you to upload to Google Play Store
4. Prompt you to commit the version change

### Option 2: Manual Steps

If you want more control, you can run each step separately:

1. **Increment Version and Build**:
   ```bash
   ./release-android.sh patch
   ```

2. **Upload to Play Store** (separately):
   ```bash
   cd scripts
   npm run upload
   ```
   Or with custom parameters:
   ```bash
   node play-upload.js ../build/app/outputs/bundle/release/app-release.aab internal
   ```

## Environment Variables

- `PLAY_STORE_SERVICE_ACCOUNT_PATH`: Path to the service account JSON file (defaults to './service-account.json')

## Troubleshooting

- **Upload Errors**: Check the error message for details. Common issues include incorrect permissions, invalid service account, or version code conflicts.
- **Building Errors**: Make sure your Flutter environment is set up correctly and your app is buildable.
- **Version Errors**: Ensure your pubspec.yaml has the correct version format (e.g., "1.0.0+1").

## Customization

You can modify the scripts to fit your workflow:
- Edit package name in both scripts
- Change the default track in play-upload.js
- Add support for more languages in release notes 