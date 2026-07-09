@echo off

net session >nul 2>&1
if %errorlevel% neq 0 (
  echo Requesting Administrator permission...
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -WorkingDirectory '%~dp0' -Verb RunAs"
  exit /b
)

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
