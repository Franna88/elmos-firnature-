#!/bin/bash

# iOS Build Script for Elmo's Furniture App
# This script helps automate the process of preparing and building
# the iOS app for TestFlight submission

# Exit on error
set -e

echo "🚀 Starting iOS build process for Elmo's Furniture App..."

# Clean the project
echo "🧹 Cleaning Flutter project..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Navigate to iOS directory
echo "📱 Preparing iOS build environment..."
cd ios

# Remove Pods directory to ensure clean installation
rm -rf Pods
rm -rf Podfile.lock

# Install pods with verbose logging to help with debugging
echo "🔄 Installing CocoaPods dependencies..."
pod install --verbose

# Return to root directory
cd ..

# Build the iOS IPA
echo "🏗️ Building iOS IPA file..."
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist

echo "✅ Build completed! IPA file is available at: build/ios/ipa/"
echo "📲 You can now upload this file to TestFlight using the Transporter app."
echo "   The path to your IPA file is: $(pwd)/build/ios/ipa/elmos_furniture_app.ipa" 