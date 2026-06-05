@echo off
echo ===========================================
echo   FinDuo: Starting PostgreSQL in WSL
echo ===========================================
wsl -d Ubuntu-24.04 -u root /etc/init.d/postgresql start
echo.
echo Database service is now active.
echo Please leave this window open to keep the database running.
wsl -d Ubuntu-24.04 -u root tail -f /dev/null
