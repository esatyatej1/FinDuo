@echo off
cls
echo ===========================================
echo   FinDuo: Building Android APK
echo ===========================================
cd /d "%~dp0..\frontend"
echo.
echo Running flutter build apk...
call flutter build apk --release
echo.
echo Copying APK to the APK folder...
if not exist "%~dp0..\APK" mkdir "%~dp0..\APK"
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "%~dp0..\APK\FinDuo-release.apk"
echo.
echo Build and copy completed successfully!
echo The APK is located in c:\EST\FinDuo\APK
echo.
pause
