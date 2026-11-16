#!/usr/bin/env bash
# Installs Flutter and the Android SDK inside a GitHub Codespace.
# Runs once, when the Codespace is created. Takes about ten minutes.
set -euo pipefail

FLUTTER_VERSION=3.50.0
SDK_DIR="$HOME/sdk"
mkdir -p "$SDK_DIR"
cd "$SDK_DIR"

if [ ! -d flutter ]; then
  echo "Installing Flutter $FLUTTER_VERSION..."
  curl -sSfL -o flutter.tar.xz \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  tar xf flutter.tar.xz
  rm flutter.tar.xz
fi

if [ ! -d android/cmdline-tools/latest ]; then
  echo "Installing the Android SDK..."
  TOOLS=$(curl -sS https://dl.google.com/android/repository/repository2-3.xml \
    | grep -o 'commandlinetools-linux-[0-9]*_latest.zip' | sort -t- -k3 -n -u | tail -1)
  curl -sSfL -o tools.zip "https://dl.google.com/android/repository/$TOOLS"
  mkdir -p android/cmdline-tools
  unzip -q tools.zip -d android/cmdline-tools
  mv android/cmdline-tools/cmdline-tools android/cmdline-tools/latest
  rm tools.zip
fi

export ANDROID_HOME="$SDK_DIR/android"
export PATH="$SDK_DIR/flutter/bin:$ANDROID_HOME/platform-tools:$PATH"

yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null 2>&1 || true
yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" \
  "platform-tools" "platforms;android-36" "platforms;android-37.0" "build-tools;36.1.0" >/dev/null

# Make the tools available in every new terminal.
if ! grep -q 'sdk/flutter/bin' "$HOME/.bashrc"; then
  {
    echo "export ANDROID_HOME=\"$SDK_DIR/android\""
    echo "export PATH=\"$SDK_DIR/flutter/bin:\$ANDROID_HOME/platform-tools:\$PATH\""
  } >> "$HOME/.bashrc"
fi

flutter config --no-analytics --android-sdk "$ANDROID_HOME" >/dev/null
flutter --version
flutter pub get

echo
echo "Ready. Open a new terminal, then try:  flutter test"
