@echo off
echo ============================================
echo    FINAL FIX FOR DIGI_SANCHIKA (Kotlin DSL)
echo ============================================

echo Step 1: Fixing build.gradle.kts...
powershell -Command "(Get-Content 'android\app\build.gradle.kts') -replace 'namespace = \"com\.example\.untitled1\"', 'namespace = \"com.example.digi_sanchika\"' | Set-Content 'android\app\build.gradle.kts'"
powershell -Command "(Get-Content 'android\app\build.gradle.kts') -replace 'compileSdk = 34', 'compileSdk = 35' | Set-Content 'android\app\build.gradle.kts'"

echo Step 2: Fixing AndroidManifest.xml...
if exist "android\app\src\main\AndroidManifest.xml" (
    powershell -Command "$content = Get-Content 'android\app\src\main\AndroidManifest.xml' -Raw; if (-not ($content -match 'package=\".*\"')) { $content = $content -replace '^<manifest', '<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\"`n    package=\"com.example.digi_sanchika\">' } else { $content = $content -replace 'package=\".*\"', 'package=\"com.example.digi_sanchika\"' }; $content | Set-Content 'android\app\src\main\AndroidManifest.xml'"
)

echo Step 3: Cleaning everything...
flutter clean
rmdir /s /q android\.gradle 2>nul
rmdir /s /q build 2>nul
rmdir /s /q android\app\build 2>nul

echo Step 4: Rebuilding...
flutter pub get
cd android
call gradlew clean
cd ..

echo Step 5: Building APK...
flutter build apk --debug

echo Step 6: Setting paths...
set ADB=E:\projects\android-sdk\platform-tools\adb.exe
set APK=build\app\outputs\flutter-apk\app-debug.apk

echo Step 7: Uninstalling old apps...
%ADB% uninstall com.example.untitled1 2>nul
%ADB% uninstall com.example.digi_sanchika 2>nul

echo Step 8: Installing fixed app...
%ADB% install -r -t -g "%APK%"

if %errorlevel% equ 0 (
    echo.
    echo ✅ SUCCESS! App installed!
    echo Launching...
    %ADB% shell am start -n com.example.digi_sanchika/.MainActivity
) else (
    echo.
    echo ❌ Installation failed. Error code: %errorlevel%
    echo.
    echo Trying manual method...
    %ADB% push "%APK%" /sdcard/digi_fixed.apk
    echo.
    echo ============================================
    echo MANUAL INSTALLATION REQUIRED:
    echo ============================================
    echo 1. On your Redmi phone, open FILE MANAGER
    echo 2. Go to: Internal storage (not SD card)
    echo 3. Find file: digi_fixed.apk
    echo 4. Tap on it and click INSTALL
    echo 5. If asked, enable "Install unknown apps"
    echo ============================================
)

echo.
echo Press any key to exit...
pause >nul