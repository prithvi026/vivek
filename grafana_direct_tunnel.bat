@echo off
echo ========================================
echo   Grafana Direct Tunnel - WORKING METHOD
echo ========================================
echo.
echo Creating direct SSH tunnel to Grafana service...
echo.
echo Once connected, open your browser to:
echo   http://localhost:3000
echo.
echo Login: admin / admin
echo.
echo Keep this window OPEN while using Grafana
echo Press Ctrl+C to disconnect
echo ========================================
echo.

ssh -i %USERPROFILE%\.ssh\id_rsa -L 3000:10.104.167.203:80 -N ubuntu@65.1.2.253
