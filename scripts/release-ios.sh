#!/bin/bash

# Exit on any error
set -e

# Function to display usage
usage() {
  echo "Usage: $0 [patch|minor|major]"
  echo "  patch: Increases the third number (1.0.0 → 1.0.1)"
  echo "  minor: Increases the second number and resets patch (1.0.1 → 1.1.0)"
  echo "  major: Increases the first number and resets others (1.1.0 → 2.0.0)"
  exit 1
}

# Check for version type argument
if [ $# -ne 1 ]; then
  usage
fi

VERSION_TYPE=$1

if [ "$VERSION_TYPE" != "patch" ] && [ "$VERSION_TYPE" != "minor" ] && [ "$VERSION_TYPE" != "major" ]; then
  usage
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Make sure we're in the project root directory
cd "$PROJECT_DIR"

echo "Starting iOS release process with $VERSION_TYPE version increment..."

# Get current version from pubspec.yaml
CURRENT_VERSION=$(grep 'version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)
CURRENT_BUILD_NUMBER=$(grep 'version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f2)

echo "Current version: $CURRENT_VERSION+$CURRENT_BUILD_NUMBER"

# Increment according to type
if [ "$VERSION_TYPE" == "patch" ]; then
  MAJOR=$(echo $CURRENT_VERSION | cut -d. -f1)
  MINOR=$(echo $CURRENT_VERSION | cut -d. -f2)
  PATCH=$(echo $CURRENT_VERSION | cut -d. -f3)
  NEW_PATCH=$((PATCH + 1))
  NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH"
elif [ "$VERSION_TYPE" == "minor" ]; then
  MAJOR=$(echo $CURRENT_VERSION | cut -d. -f1)
  MINOR=$(echo $CURRENT_VERSION | cut -d. -f2)
  NEW_MINOR=$((MINOR + 1))
  NEW_VERSION="$MAJOR.$NEW_MINOR.0"
elif [ "$VERSION_TYPE" == "major" ]; then
  MAJOR=$(echo $CURRENT_VERSION | cut -d. -f1)
  NEW_MAJOR=$((MAJOR + 1))
  NEW_VERSION="$NEW_MAJOR.0.0"
fi

# Increment build number
NEW_BUILD_NUMBER=$((CURRENT_BUILD_NUMBER + 1))

echo "New version: $NEW_VERSION+$NEW_BUILD_NUMBER"

# Update pubspec.yaml
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS requires a different sed syntax
  sed -i '' "s/version: $CURRENT_VERSION+$CURRENT_BUILD_NUMBER/version: $NEW_VERSION+$NEW_BUILD_NUMBER/" pubspec.yaml
else
  sed -i "s/version: $CURRENT_VERSION+$CURRENT_BUILD_NUMBER/version: $NEW_VERSION+$NEW_BUILD_NUMBER/" pubspec.yaml
fi

# Check if ExportOptions.plist has placeholder team ID
if grep -q "ENTER_YOUR_TEAM_ID" ios/ExportOptions.plist; then
  echo "Team ID needs to be configured in ExportOptions.plist"
  read -p "Enter your Apple Developer Team ID: " TEAM_ID
  
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS requires a different sed syntax
    sed -i '' "s/ENTER_YOUR_TEAM_ID/$TEAM_ID/" ios/ExportOptions.plist
  else
    sed -i "s/ENTER_YOUR_TEAM_ID/$TEAM_ID/" ios/ExportOptions.plist
  fi
  
  echo "Updated Team ID in ExportOptions.plist"
fi

# Ask about updating release notes
read -p "Do you want to update the release notes? (y/n): " UPDATE_NOTES

if [ "$UPDATE_NOTES" == "y" ] || [ "$UPDATE_NOTES" == "Y" ]; then
  if [ ! -d "distribution/whatsnew" ]; then
    mkdir -p distribution/whatsnew
  fi
  
  # Open release notes in default editor
  if [[ "$OSTYPE" == "darwin"* ]]; then
    open -t distribution/whatsnew/en-US.txt
  else
    if [ -n "$EDITOR" ]; then
      $EDITOR distribution/whatsnew/en-US.txt
    else
      echo "No default editor found. Please edit distribution/whatsnew/en-US.txt manually."
    fi
  fi
  
  echo "Press Enter when you've finished updating the release notes."
  read
fi

# Get Flutter dependencies
echo "Getting Flutter dependencies..."
flutter pub get

# Clean the build
echo "Cleaning project..."
flutter clean

# Get dependencies again after clean
echo "Getting Flutter dependencies again after clean..."
flutter pub get

# Generate Flutter files for iOS
echo "Generating Flutter files for iOS..."
flutter build ios --debug --no-codesign

# Navigate to iOS directory and update pods
echo "Updating CocoaPods dependencies..."
cd ios
rm -rf Pods
rm -rf Podfile.lock
pod install --verbose
cd ..

# Build the iOS IPA
echo "Building iOS IPA..."
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist

IPA_PATH="$PROJECT_DIR/build/ios/ipa"
APP_NAME=$(ls "$IPA_PATH" | grep .ipa)
FULL_IPA_PATH="$IPA_PATH/$APP_NAME"

echo "IPA built successfully at $FULL_IPA_PATH"

# Ask if user wants to upload to TestFlight
read -p "Do you want to upload to TestFlight using Transporter? (y/n): " UPLOAD_TO_TESTFLIGHT

if [ "$UPLOAD_TO_TESTFLIGHT" == "y" ] || [ "$UPLOAD_TO_TESTFLIGHT" == "Y" ]; then
  if command -v xcrun &> /dev/null; then
    echo "Uploading to TestFlight using xcrun..."
    read -p "Enter your Apple ID: " APPLE_ID
    read -s -p "Enter your app-specific password: " APP_PASSWORD
    echo ""
    
    xcrun altool --upload-app -f "$FULL_IPA_PATH" -t ios --apple-id "$APPLE_ID" --password "$APP_PASSWORD"
  else
    echo "xcrun not found. Please upload manually using the Transporter app."
    echo "The path to your IPA file is: $FULL_IPA_PATH"
    
    # Try to open Transporter if available
    if [[ "$OSTYPE" == "darwin"* ]]; then
      if [ -d "/Applications/Transporter.app" ]; then
        echo "Opening Transporter app..."
        open -a Transporter "$FULL_IPA_PATH"
      else
        echo "Transporter app not found. Please download it from the Mac App Store."
      fi
    fi
  fi
fi

# Commit the version change
read -p "Do you want to commit the version change? (y/n): " COMMIT_VERSION

if [ "$COMMIT_VERSION" == "y" ] || [ "$COMMIT_VERSION" == "Y" ]; then
  git add pubspec.yaml
  if [ "$UPDATE_NOTES" == "y" ] || [ "$UPDATE_NOTES" == "Y" ]; then
    git add distribution/whatsnew/en-US.txt
  fi
  
  git commit -m "Bump version to $NEW_VERSION+$NEW_BUILD_NUMBER"
  
  read -p "Do you want to push the commit? (y/n): " PUSH_COMMIT
  
  if [ "$PUSH_COMMIT" == "y" ] || [ "$PUSH_COMMIT" == "Y" ]; then
    git push
  fi
fi

echo "iOS release process completed!" 