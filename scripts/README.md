# Android and iOS Release Automation Scripts

These scripts automate the process of building app bundles, incrementing version numbers, and uploading to app stores.

## Prerequisites

### For Both Platforms
1. Flutter SDK installed and configured
2. Git properly configured

### For Android
1. Java Development Kit (JDK) installed
2. Node.js installed (for the upload script)
3. Google Play Console service account credentials

### For iOS
1. Xcode installed on your Mac
2. CocoaPods installed
3. Apple Developer account with app setup in App Store Connect
4. Properly configured signing certificates and provisioning profiles
5. Transporter app installed (available from Mac App Store)

## Setup

### Android Setup
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

### iOS Setup
1. **Configure ExportOptions.plist**:
   - Edit `ios/ExportOptions.plist`
   - Replace `YOUR_TEAM_ID` with your Apple Developer Team ID
   - Update bundle ID and provisioning profile name if needed

2. **Update Upload Credentials in Script**:
   - Edit `scripts/release-ios.sh` 
   - Replace `YOUR_APPLE_ID` with your Apple ID
   - Replace `YOUR_APP_SPECIFIC_PASSWORD` with an app-specific password
     (Generate at appleid.apple.com → Security → App-Specific Passwords)

## Usage

### Make Scripts Executable
```bash
chmod +x scripts/release-android.sh
chmod +x scripts/release-ios.sh
```

### Android Release

Run the release script with the version type to increment:

```bash
./scripts/release-android.sh [patch|minor|major]
```

This will:
1. Increment the version according to the specified type
2. Build the Android App Bundle
3. Prompt you to upload to Google Play Store
4. Prompt you to commit the version change

### iOS Release

Run the release script with the version type to increment:

```bash
./scripts/release-ios.sh [patch|minor|major]
```

This will:
1. Increment the version according to the specified type
2. Clean the project and update dependencies
3. Build the iOS IPA file
4. Prompt you to upload to TestFlight
5. Prompt you to commit the version change

## Troubleshooting

### Android Issues
- **Upload Errors**: Check the error message for details. Common issues include incorrect permissions, invalid service account, or version code conflicts.
- **Building Errors**: Make sure your Flutter environment is set up correctly and your app is buildable.
- **Version Errors**: Ensure your pubspec.yaml has the correct version format (e.g., "1.0.0+1").

### iOS Issues
- **Signing Errors**: Check your certificates in Keychain Access and ensure your ExportOptions.plist is correctly configured.
- **Upload Errors**: Verify your Apple ID and app-specific password are correct.
- **Dependency Issues**: If you encounter CocoaPods errors, try running `pod repo update` before building.
- **Transporter Errors**: Check App Store Connect for more detailed error messages.

## Customization

You can modify the scripts to fit your workflow:
- Edit package name in both scripts
- Change the default track in play-upload.js
- Add support for more languages in release notes 