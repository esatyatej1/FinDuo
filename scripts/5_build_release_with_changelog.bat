@echo off
setlocal enabledelayedexpansion
cls
echo ========================================================
echo   FinDuo: Automatic Release APK Build with Changelog
echo ========================================================

cd /d "%~dp0..\frontend"

:: Extract version from pubspec.yaml
for /f "delims=" %%I in ('powershell -NoProfile -Command "(Get-Content pubspec.yaml | Select-String -Pattern '^version:\s*(.+)$').Matches.Groups[1].Value"') do set "APP_VERSION=%%I"
:: Replace + with _ for file naming compatibility
set "APP_VERSION=%APP_VERSION:+=_%"

if "%APP_VERSION%"=="" (
    set /p "APP_VERSION=Could not detect version. Enter proper version (e.g., 1.0.1_1): "
) else (
    echo Detected Version: %APP_VERSION%
    set /p "CONFIRM_VERSION=Is this version correct? [Y/N]: "
    if /i "!CONFIRM_VERSION!"=="N" (
        set /p "APP_VERSION=Enter proper version (e.g., 1.0.1_1): "
    )
)

set "CHANGELOG_FILE=%~dp0..\APK\changelog-v%APP_VERSION%.txt"
set "RAW_FILE=%~dp0..\APK\raw_changelog.txt"
set "APK_DEST=%~dp0..\APK\FinDuo-v%APP_VERSION%.apk"

if not exist "%~dp0..\APK" mkdir "%~dp0..\APK"

echo.
echo ========================================================
echo Opening Notepad for you to paste your raw development changes...
echo Please paste the raw changes, save (Ctrl+S), and close Notepad.
echo ========================================================
echo Paste your raw development notes here: > "%RAW_FILE%"
echo. >> "%RAW_FILE%"
notepad "%RAW_FILE%"

echo.
echo Processing raw notes using Cerebras AI...
"%~dp0..\backend\venv\Scripts\python.exe" "%~dp0rewrite_changelog.py" "%RAW_FILE%" "%CHANGELOG_FILE%" "%APP_VERSION%"

if exist "%RAW_FILE%" del "%RAW_FILE%"

echo.
echo Running flutter build apk --release...
call flutter build apk --release

echo.
echo Copying APK to the APK folder...
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "%APK_DEST%"

echo.
echo ========================================================
echo Build and copy completed successfully!
echo Release APK: %APK_DEST%
echo Changelog:   %CHANGELOG_FILE%
echo ========================================================
echo.
pause
