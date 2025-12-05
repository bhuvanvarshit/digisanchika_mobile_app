@echo off
echo ============================================
echo    UPDATE TO ANDROID SDK 36
echo ============================================

echo 1. Updating build.gradle.kts...
cd /d E:\projects\mobile_app\digi_sanchika

powershell -Command "(Get-Content 'android\app\build.gradle.kts') -replace 'compileSdk = 35', 'compileSdk = 36' | Set-Content 'android\app\build.gradle.kts'"
powershell -Command "(Get-Content 'android\app\build.gradle.kts') -replace 'targetSdk = 35', 'targetSdk = 36' | Set-Content 'android\app\build.gradle.kts'"

echo 2. Simple gradle.properties...
(
echo org.gradle.jvmargs=-Xmx1536M
echo android.useAndroidX=true
echo android.enableJetifier=true
) > android\gradle.properties

echo 3. Cleaning...
flutter clean
rmdir /s /q android\.gradle 2>nul
rmdir /s /q build 2>nul

echo 4. Building...
flutter build apk --debug

if exist "build\app\outputs\flutter-apk\app-debug.apk" (
    echo ✅ BUILD SUCCESS!
    echo.
    echo File: build\app\outputs\flutter-apk\app-debug.apk
    echo.
    echo Installing...
    E:\projects\android-sdk\platform-tools\adb.exe install -r build\app\outputs\flutter-apk\app-debug.apk
    
    if %errorlevel% equ 0 (
        echo ✅ INSTALLATION SUCCESS!
    ) else (
        echo ❌ ADB install failed.
        echo.
        echo Copying for manual install...
        E:\projects\android-sdk\platform-tools\adb.exe push build\app\outputs\flutter-apk\app-debug.apk /sdcard/digi_app.apk
        echo 📱 Install from File Manager!
    )
) else (
    echo ❌ BUILD FAILED!
    echo.
    echo Try: flutter build apk --debug --verbose
)

pause