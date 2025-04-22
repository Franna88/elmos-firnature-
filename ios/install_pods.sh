#!/bin/bash

# Script to help with installing pods for iOS deployment

echo "🧹 Cleaning existing Pods..."
rm -rf Pods
rm -rf Podfile.lock
rm -rf .symlinks/plugins/mobile_scanner

echo "🔍 Updating Pod repo..."
pod repo update

echo "🔄 Installing Pods..."
pod install --verbose

if [ $? -ne 0 ]; then
  echo "⚠️ Pod install failed. Trying with repo update..."
  pod install --repo-update --verbose
fi

if [ $? -ne 0 ]; then
  echo "⚠️ Pod install still failed. Trying with deintegrate and clean install..."
  pod deintegrate
  pod clean
  pod setup
  pod install --verbose
fi

echo "✅ Pod installation process completed." 