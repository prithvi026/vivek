@echo off
echo ========================================
echo   GRAFANA ACCESS - PhD Research Project
echo ========================================
echo.
echo Option 1: Direct Access (RECOMMENDED)
echo   URL: http://52.66.203.212:30300
echo.
echo Option 2: SSH Tunnel (if needed)
echo   Creating SSH tunnel to localhost:8888...
echo.
echo Login credentials:
echo   Username: admin
echo   Password: admin
echo.
echo Press Ctrl+C to stop the tunnel
echo ========================================
echo.

ssh -i %USERPROFILE%\.ssh\id_rsa -L 8888:10.97.198.1:80 -N ubuntu@52.66.203.212
