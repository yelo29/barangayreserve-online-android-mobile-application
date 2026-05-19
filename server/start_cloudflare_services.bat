@echo off
echo ========================================
echo   BARANGAY RESERVE - CLOUDFLARE TUNNEL
echo ========================================
echo.

echo Configuration Status:
echo    Android App: https://barangayreserve.dpdns.org
echo    Server: Python on port 8000
echo    Tunnel: Cloudflare Named Tunnel (permanent!)
echo.

echo Starting Services...
echo.

REM Start Python Server
echo Starting Python server on port 8000...
cd /d "%~dp0"
start "Python Server" cmd /k python server.py

REM Wait a moment for server to start
timeout /t 3 /nobreak >nul

REM Start Cloudflare Tunnel
echo Starting Cloudflare tunnel...
cd /d "C:\tools\cloudflare"
start "Cloudflare Tunnel" cmd /k .\cloudflared.exe tunnel run barangayreserve-dpdns

echo.
echo Both services started!
echo Android app ready: https://barangayreserve.dpdns.org
echo Tunnel URL: https://barangayreserve.dpdns.org
echo.
pause