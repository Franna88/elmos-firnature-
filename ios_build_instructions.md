# iOS Deployment Instructions

## Pre-requisites
1. A valid Apple Developer account
2. Xcode installed on your Mac
3. Flutter SDK installed

## Steps to Deploy to TestFlight

### 1. Resolve Dependency Issues
Currently, there's a dependency conflict between different versions of GoogleUtilities required by `mobile_scanner` and `google_sign_in_ios`. To resolve this, you have two options:

#### Option A: Temporary disable mobile_scanner for iOS build
1. Create a platform-specific implementation that uses a placeholder on iOS:
   - Create a directory `lib/services/platform_specific/`
   - Create files for handling scanner functionality on different platforms

#### Option B: Use Xcode's dependency resolution tools
1. Open the Xcode workspace:
   ```
   cd ios
   open Runner.xcworkspace
   ```
2. In Xcode, manually resolve the dependency conflicts by:
   - Selecting specific versions of dependencies
   - Using Xcode's "Resolve Package Versions" feature

### 2. Set up App Store Connect
1. Log in to [App Store Connect](https://appstoreconnect.apple.com/)
2. Create a new app entry with the bundle ID matching your app
3. Set up app information, screenshots, and metadata

### 3. Configure signing in Xcode
1. Open Xcode and your iOS project
2. Go to the "Signing & Capabilities" tab
3. Select your team and provisioning profile
4. Ensure "Automatically manage signing" is checked

### 4. Build the app for distribution
Run the following command to create an archive:
```
flutter build ipa --release
```

### 5. Upload to TestFlight using Transporter
1. Open Transporter app on your Mac
2. Sign in with your Apple ID
3. Drag and drop the .ipa file from the build/ios/ipa directory
4. Click "Upload" to send the build to App Store Connect

### 6. TestFlight Setup
1. In App Store Connect, go to the TestFlight tab
2. Wait for the build to finish processing
3. Add test information and compliance details
4. Add testers and create testing groups

## Required Permissions
Ensure the following permissions are in your Info.plist:
- NSCameraUsageDescription
- NSPhotoLibraryUsageDescription

## Common Issues
- If you encounter code signing issues, verify your certificates in Keychain Access
- For "Missing Compliance" warnings, complete the export compliance information in App Store Connect
- If build fails, check the build logs for specific error messages 