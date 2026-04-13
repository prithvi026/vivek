@echo off
echo ========================================
echo   GRAFANA ACCESS - WORKING TUNNEL
echo ========================================
echo.
echo SSH tunnel is ready!
echo.
echo OPEN YOUR BROWSER TO:
echo   http://localhost:8888
echo.
echo LOGIN CREDENTIALS:
echo   Username: admin
echo   Password: admin
echo.
echo Keep this window OPEN while using Grafana
echo Press Ctrl+C to close the tunnel
echo ========================================
echo.

ssh -i %USERPROFILE%\.ssh\id_rsa -L 8888:10.104.167.203:80 -N ubuntu@65.1.2.253
