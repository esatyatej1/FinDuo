@echo off
echo ===========================================
echo   FinDuo: Starting FastAPI Backend
echo ===========================================
cd /d "%~dp0..\backend"
call venv\Scripts\activate
uvicorn main:app --reload --host 0.0.0.0 --port 9005
pause
