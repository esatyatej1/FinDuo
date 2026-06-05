@echo off
echo ===========================================
echo   FinDuo: Seeding Database (Fresh Reset)
echo ===========================================
cd /d "%~dp0..\backend"
call venv\Scripts\activate
python seed_data.py
echo.
echo Done! Database seeded successfully.
pause
