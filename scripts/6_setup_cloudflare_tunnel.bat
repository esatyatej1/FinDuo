@echo off
setlocal

set CLOUDFLARED="C:\Cloudflared\cloudflared.exe"

echo ===================================================
echo Cloudflare Tunnel Management: api.finduo.qzz.io
echo ===================================================
echo.

if not exist %CLOUDFLARED% (
    echo [ERROR] cloudflared.exe not found at C:\Cloudflared\
    echo Please make sure it was downloaded.
    pause
    exit /b
)

echo Select an option:
echo 1. Initial Setup (Authenticate, Create Tunnel, Route DNS)
echo 2. Start Existing Tunnel
echo.
set /p OPTION="Choice (1 or 2): "

if "%OPTION%"=="1" goto setup
if "%OPTION%"=="2" goto start
goto end

:setup
echo.
echo ===================================================
echo INITIAL SETUP
echo ===================================================
echo This will open a browser to authenticate if not done yet.
%CLOUDFLARED% tunnel login

echo.
echo Creating tunnel 'finduo-tunnel'...
%CLOUDFLARED% tunnel create finduo-tunnel

echo.
echo Routing traffic for api.finduo.qzz.io to the tunnel...
%CLOUDFLARED% tunnel route dns finduo-tunnel api.finduo.qzz.io
echo Setup complete. You can now start the tunnel.
goto start

:start
echo.
echo ===================================================
echo START TUNNEL
echo ===================================================
echo Please enter the local URL/Port you want to expose 
echo (e.g., http://localhost:9005 for FastAPI backend):
set /p LOCAL_URL="Local URL: "

if "%LOCAL_URL%"=="" set LOCAL_URL="http://localhost:9005"

echo.
echo Starting the named tunnel 'finduo-tunnel'!
echo It will point api.finduo.qzz.io to %LOCAL_URL%
echo To stop it, press Ctrl+C.
%CLOUDFLARED% tunnel --url %LOCAL_URL% run finduo-tunnel

:end
endlocal
pause
