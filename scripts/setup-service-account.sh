#!/bin/bash

# Exit on any error
set -e

echo "Google Play Service Account Setup Helper"
echo "========================================"
echo "This script will help you set up the Google Play service account for automated uploads."
echo

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SERVICE_ACCOUNT_PATH="$SCRIPT_DIR/service-account.json"

# Check if service account file already exists
if [ -f "$SERVICE_ACCOUNT_PATH" ]; then
  read -p "A service account file already exists. Do you want to replace it? (y/n): " REPLACE_FILE
  
  if [ "$REPLACE_FILE" != "y" ] && [ "$REPLACE_FILE" != "Y" ]; then
    echo "Setup cancelled."
    exit 0
  fi
fi

echo "Please follow these steps in the Google Play Console:"
echo "1. Go to Setup > API access"
echo "2. Create a new service account (if you don't have one already)"
echo "3. Grant the service account access to your app with the 'Release manager' role"
echo "4. Create and download a JSON key file"
echo

read -p "Enter the path to the downloaded service account JSON file: " DOWNLOADED_JSON

if [ ! -f "$DOWNLOADED_JSON" ]; then
  echo "Error: File not found at $DOWNLOADED_JSON"
  exit 1
fi

# Copy the file to the scripts directory
cp "$DOWNLOADED_JSON" "$SERVICE_ACCOUNT_PATH"

echo "Service account file has been copied to: $SERVICE_ACCOUNT_PATH"
echo "Setup complete!"
echo
echo "You can now use the release-android.sh script to build and upload your app." 