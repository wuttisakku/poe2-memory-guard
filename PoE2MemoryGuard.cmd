@echo off
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-Memory-Guard.ps1" -ConfigPath "%~dp0config.json"
if errorlevel 1 (
  echo.
  echo Update check failed. Continuing with the installed version.
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-RAMMap.ps1" -ConfigPath "%~dp0config.json"
if errorlevel 1 (
  echo.
  echo RAMMap setup failed. Check your internet connection and try again.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0PoE2-Memory-Guard.ps1" -ConfigPath "%~dp0config.json" -StandbyToolPath "%~dp0Tools\RAMMap\RAMMap64.exe"
echo.
echo Memory Guard stopped. Press any key to close.
pause >nul
