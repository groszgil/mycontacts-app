#!/bin/bash
# =====================================================
# Auto Screenshot Tool — My Contacts
# הרץ: bash scripts/take_screenshots.sh
# =====================================================

SCREENSHOTS_DIR="$HOME/Desktop/AppStore_Screenshots"
mkdir -p "$SCREENSHOTS_DIR"

echo ""
echo "📸 מצלם Screenshots לחנות App Store..."
echo "📁 ישמרו ב: $SCREENSHOTS_DIR"
echo ""

# ── פונקציה לצילום simulator ─────────────────────────────────────────────

take_screenshot() {
  local DEVICE="$1"
  local NAME="$2"
  local FOLDER="$SCREENSHOTS_DIR/$NAME"
  mkdir -p "$FOLDER"

  echo "🔄 מאתחל $NAME ($DEVICE)..."

  # Boot the simulator
  xcrun simctl boot "$DEVICE" 2>/dev/null || true
  sleep 3

  # Open Simulator.app
  open -a Simulator --args -CurrentDeviceUDID "$DEVICE"
  sleep 4

  # Build & install the app
  flutter build ios --simulator --quiet 2>/dev/null

  local APP_PATH=$(find build/ios/iphonesimulator -name "*.app" | head -1)
  xcrun simctl install "$DEVICE" "$APP_PATH" 2>/dev/null

  # Launch the app
  xcrun simctl launch "$DEVICE" com.mycontacts.myContacts 2>/dev/null
  sleep 4

  # Take screenshot 1 — Home screen
  xcrun simctl io "$DEVICE" screenshot "$FOLDER/01_home.png"
  echo "  ✅ 01 — Home Screen"
  sleep 1

  # Shutdown
  xcrun simctl shutdown "$DEVICE" 2>/dev/null
}

# ── גדלים נדרשים לחנות ───────────────────────────────────────────────────

# iPhone 16 Pro Max — 6.9" (חובה)
IPHONE_16_PM=$(xcrun simctl list devices | grep "iPhone 16 Pro Max" | grep -v unavailable | head -1 | grep -o '[A-F0-9\-]\{36\}')
if [ -n "$IPHONE_16_PM" ]; then
  take_screenshot "$IPHONE_16_PM" "6.9-inch_iPhone16ProMax"
else
  echo "⚠️  iPhone 16 Pro Max לא נמצא — הוסף מ-Xcode → Window → Devices and Simulators"
fi

# iPhone 11 Pro Max — 6.5" (נדרש)
IPHONE_11_PM=$(xcrun simctl list devices | grep "iPhone 11 Pro Max" | grep -v unavailable | head -1 | grep -o '[A-F0-9\-]\{36\}')
if [ -n "$IPHONE_11_PM" ]; then
  take_screenshot "$IPHONE_11_PM" "6.5-inch_iPhone11ProMax"
else
  echo "⚠️  iPhone 11 Pro Max לא נמצא"
fi

echo ""
echo "✅ Screenshots נשמרו ב: $SCREENSHOTS_DIR"
echo ""
echo "📌 עכשיו:"
echo "   1. פתח $SCREENSHOTS_DIR"
echo "   2. צלם manually מסכים נוספים לפי הצורך"
echo "   3. העלה ל-App Store Connect"
