@echo off
echo ============================================
echo    FIX DEVICE PROPERTIES ERROR
echo ============================================

set ADB=E:\projects\android-sdk\platform-tools\adb.exe

echo 1. Getting device properties...
%ADB% shell getprop ro.product.model
%ADB% shell getprop ro.build.version.release
%ADB% shell getprop ro.build.version.sdk

echo 2. Reconnecting device...
%ADB% reconnect
timeout /t 2 >nul
%ADB% reconnect device

echo 3. Restarting ADB...
%ADB% kill-server
timeout /t 3 >nul
%ADB% start-server

echo 4. Checking Flutter devices with timeout...
cd /d E:\projects\mobile_app\digi_sanchika
flutter devices --device-timeout=60

echo 5. If still shows "unsupported", try:
echo    flutter run -d 10BF4L10670012F --verbose

pause