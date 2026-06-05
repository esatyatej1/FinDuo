@echo off
:menu
cls
echo ===========================================
echo   FinDuo: Starting Android App
echo ===========================================
cd /d "%~dp0..\frontend"
echo.
echo Flutter will now show available devices. 
echo Please type the number (1, 2, 3...) when prompted.
echo.
call flutter run
echo.
echo Press any key to return to the menu...
pause >nul
goto menu
