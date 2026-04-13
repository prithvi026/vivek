@echo off
echo ========================================
echo   Grafana Port Forward - Quick Access
echo ========================================
echo.
echo Starting port forward...
echo Grafana will be accessible at: http://localhost:3000
echo.
echo Login credentials:
echo   Username: admin
echo   Password: admin
echo.
echo Press Ctrl+C to stop port forwarding
echo ========================================
echo.

ssh -i %USERPROFILE%\.ssh\id_rsa -L 3000:localhost:3000 ubuntu@65.1.2.253 "kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80"
