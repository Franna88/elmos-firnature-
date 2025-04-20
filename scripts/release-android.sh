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

echo "Starting Android release process with $VERSION_TYPE version increment..."

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

# Check if key.properties exists
if [ ! -f "android/key.properties" ]; then
  echo "Error: android/key.properties not found. Please create this file with your keystore information."
  exit 1
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

# Build the Android App Bundle
echo "Building App Bundle..."
flutter build appbundle --release

AAB_PATH="$PROJECT_DIR/build/app/outputs/bundle/release/app-release.aab"
echo "App Bundle built successfully at $AAB_PATH"

# Ask if user wants to upload to Play Store
read -p "Do you want to upload to Play Store? (y/n): " UPLOAD_TO_PLAY_STORE

if [ "$UPLOAD_TO_PLAY_STORE" == "y" ] || [ "$UPLOAD_TO_PLAY_STORE" == "Y" ]; then
  # Check if Node.js is installed
  if ! command -v node &> /dev/null; then
    echo "Node.js is required for uploading to Play Store but is not installed."
    echo "Please install Node.js and try again, or upload manually through the Play Console."
    echo "https://nodejs.org/en/download/"
  else
    # Check if service account file exists
    SERVICE_ACCOUNT_PATH="$SCRIPT_DIR/service-account.json"
    if [ ! -f "$SERVICE_ACCOUNT_PATH" ]; then
      echo "Service account file not found at $SERVICE_ACCOUNT_PATH"
      read -p "Enter the path to your service account JSON file: " CUSTOM_SA_PATH
      export PLAY_STORE_SERVICE_ACCOUNT_PATH="$CUSTOM_SA_PATH"
    else
      export PLAY_STORE_SERVICE_ACCOUNT_PATH="$SERVICE_ACCOUNT_PATH"
    fi
    
    # Check if the node modules are installed
    if [ ! -d "$SCRIPT_DIR/node_modules" ]; then
      echo "Installing dependencies for upload script..."
      (cd "$SCRIPT_DIR" && npm install)
    fi
    
    # Run the upload script
    echo "Uploading to Google Play Store..."
    (cd "$SCRIPT_DIR" && node play-upload.js "$AAB_PATH")
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

echo "Android release process completed!" 