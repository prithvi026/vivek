@echo off
echo ========================================
echo   Grafana Access via SSH Tunnel
echo ========================================
echo.
echo Creating SSH tunnel to Grafana...
echo Grafana will be accessible at: http://localhost:3000
echo.
echo Login credentials:
echo   Username: admin
echo   Password: admin
echo.
echo Press Ctrl+C to stop the tunnel
echo ========================================
echo.

ssh -i %USERPROFILE%\.ssh\id_rsa -N -L 3000:10.104.167.203:80 ubuntu@65.1.2.253
