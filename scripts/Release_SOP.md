# Release Process Standard Operating Procedure (SOP)

## Overview
This SOP outlines the process for building and releasing app bundles to Android and iOS app stores.

## Prerequisites

### Required Tools
- Flutter SDK (installed and configured)
- Git (properly configured)
- Android: JDK, Node.js, Google Play service account
- iOS: Xcode, CocoaPods, Apple Developer account, certificates, Transporter app

## Process Flow

### Pre-Release Preparation

1. **Ensure clean git status**
   - Commit or stash all changes
   - Run `git status` to verify clean state

2. **Test application**
   - Run full test suite
   - Verify key functionality works correctly

### Android Release Process

1. **Check prerequisites**
   - Verify JDK, Flutter, and Node.js are installed
   - Ensure service-account.json exists in scripts directory

2. **Make script executable**
   - Run `chmod +x scripts/release-android.sh`

3. **Execute release script**
   - Run `./scripts/release-android.sh [patch|minor|major]`
   - Choose version type based on release scope

4. **Verify upload to Play Store**
   - When prompted, confirm upload
   - Check Google Play Console for status

### iOS Release Process

1. **Check prerequisites**
   - Verify Xcode, CocoaPods, and certificates
   - Ensure Apple ID and app-specific password are configured

2. **Make script executable**
   - Run `chmod +x scripts/release-ios.sh`

3. **Execute release script**
   - Run `./scripts/release-ios.sh [patch|minor|major]`
   - Choose version type based on release scope

4. **Verify upload to TestFlight**
   - When prompted, confirm upload
   - Check App Store Connect for status

## Troubleshooting

### Common Android Issues
- **Upload failures**: Check service account permissions and version code conflicts
- **Build errors**: Verify Flutter environment and buildable app state
- **Version issues**: Ensure pubspec.yaml has correct version format

### Common iOS Issues
- **Signing errors**: Check Keychain Access certificates and ExportOptions.plist
- **Upload failures**: Verify Apple ID and app-specific password
- **Pod errors**: Run `pod repo update` before building
- **Transporter errors**: Check App Store Connect for detailed messages

## Post-Release Actions

1. **Verify git commit**
   - Confirm version change was committed
   - Push changes to remote repository

2. **Create release notes**
   - Document changes in this release
   - Share with team and stakeholders

3. **Monitor release status**
   - Check app store dashboards for processing status
   - Address any reported issues promptly 