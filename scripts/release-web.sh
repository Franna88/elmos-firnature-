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

echo "Starting Web release process with $VERSION_TYPE version increment..."

# Check if firebase CLI is installed
if ! command -v firebase &> /dev/null; then
  echo "Firebase CLI is required but not installed."
  echo "Please install Firebase CLI with 'npm install -g firebase-tools' and try again."
  echo "For more information: https://firebase.google.com/docs/cli"
  exit 1
fi

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

# Update web/index.html to include the version number
echo "Updating web/index.html with new version number..."
VERSION_STRING="$NEW_VERSION (build $NEW_BUILD_NUMBER)"

# Check if the version comment already exists in the file
if grep -q "<!-- App Version:" web/index.html; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/<!-- App Version:.*-->/<!-- App Version: $VERSION_STRING -->/" web/index.html
  else
    sed -i "s/<!-- App Version:.*-->/<!-- App Version: $VERSION_STRING -->/" web/index.html
  fi
else
  # Add the version comment right after the <head> tag if it doesn't exist
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/<head>/<head>\n  <!-- App Version: $VERSION_STRING -->/" web/index.html
  else
    sed -i "s/<head>/<head>\n  <!-- App Version: $VERSION_STRING -->/" web/index.html
  fi
fi

# Get Flutter dependencies
echo "Getting Flutter dependencies..."
flutter pub get

# Clean previous builds
echo "Cleaning previous builds..."
flutter clean
flutter pub get

# Build the Web application
echo "Building Web application..."
flutter build web --release

echo "Web application built successfully in build/web/"

# Ask if user wants to deploy to Firebase Hosting
read -p "Do you want to deploy to Firebase Hosting? (y/n): " DEPLOY_TO_FIREBASE

if [ "$DEPLOY_TO_FIREBASE" == "y" ] || [ "$DEPLOY_TO_FIREBASE" == "Y" ]; then
  # Check if user is logged in to Firebase
  FIREBASE_STATUS=$(firebase login:list 2>&1)
  if [[ $FIREBASE_STATUS == *"No users"* ]]; then
    echo "You are not logged in to Firebase CLI. Please login first."
    firebase login
  fi
  
  # Preview before deploy
  echo "Previewing deployment..."
  firebase hosting:channel:deploy preview_$NEW_VERSION
  
  read -p "Do you want to proceed with the actual deployment? (y/n): " CONFIRM_DEPLOY
  
  if [ "$CONFIRM_DEPLOY" == "y" ] || [ "$CONFIRM_DEPLOY" == "Y" ]; then
    echo "Deploying to Firebase Hosting..."
    firebase deploy --only hosting
    
    echo "Deployment completed!"
    
    # Get the hosting URL
    HOSTING_URL=$(firebase hosting:channel:list --json | grep -o '"url": "[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ -n "$HOSTING_URL" ]; then
      echo "Your app is live at: $HOSTING_URL"
    else
      echo "Your app has been deployed. Check Firebase console for details."
    fi
  else
    echo "Deployment cancelled."
  fi
else
  echo "Firebase deployment skipped."
fi

# Commit the version change
read -p "Do you want to commit the version change? (y/n): " COMMIT_VERSION

if [ "$COMMIT_VERSION" == "y" ] || [ "$COMMIT_VERSION" == "Y" ]; then
  git add pubspec.yaml web/index.html
  
  git commit -m "Bump version to $NEW_VERSION+$NEW_BUILD_NUMBER for web release"
  
  read -p "Do you want to push the commit? (y/n): " PUSH_COMMIT
  
  if [ "$PUSH_COMMIT" == "y" ] || [ "$PUSH_COMMIT" == "Y" ]; then
    git push
  fi
fi

echo "Web release process completed!" 