@echo off
echo ============================================
echo    FINAL BUILD WITH 4GB MEMORY
echo ============================================

cd /d E:\projects\mobile_app\digi_sanchika

echo 1. Killing Java processes...
taskkill /f /im java.exe 2>nul
taskkill /f /im javaw.exe 2>nul
taskkill /f /im adb.exe 2>nul
timeout /t 2 >nul

echo 2. Cleaning everything...
flutter clean
rmdir /s /q android\.gradle 2>nul
rmdir /s /q build 2>nul
rmdir /s /q android\app\build 2>nul

echo 3. Rebuilding dependencies...
flutter pub get

echo 4. Building APK...
flutter build apk --debug --target-platform android-arm64

if exist "build\app\outputs\flutter-apk\app-debug.apk" (
    echo ✅ BUILD SUCCESSFUL!
    echo.
    echo APK created: build\app\outputs\flutter-apk\app-debug.apk
    
    echo 5. Checking file size...
    for %%I in ("build\app\outputs\flutter-apk\app-debug.apk") do set size=%%~zI
    set /a sizeMB=%size%/1048576
    echo    Size: %sizeMB% MB
    echo.
    
    echo 6. Installing...
    set ADB=E:\projects\android-sdk\platform-tools\adb.exe
    "%ADB%" install -r -t -g "build\app\outputs\flutter-apk\app-debug.apk"
    
    if %errorlevel% equ 0 (
        echo ✅ INSTALLATION SUCCESSFUL!
        echo.
        echo Launching app...
        "%ADB%" shell am start -n com.example.digi_sanchika/.MainActivity
    ) else (
        echo ❌ ADB installation failed.
        echo.
        echo 7. Copying for manual install...
        "%ADB%" push "build\app\outputs\flutter-apk\app-debug.apk" /sdcard/digi_ready.apk
        echo.
        echo ============================================
        echo 📱 MANUAL INSTALLATION:
        echo ============================================
        echo On your Redmi I2407:
        echo 1. Open FILE MANAGER
        echo 2. Go to Internal Storage
        echo 3. Find: digi_ready.apk
        echo 4. Tap to install
        echo ============================================
    )
) else (
    echo ❌ BUILD FAILED!
    echo.
    echo Try building with verbose output:
    echo flutter build apk --debug --verbose
)

echo.
pause