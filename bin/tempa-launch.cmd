@echo off
rem Tempa launcher for Windows (TEMPA-115): runs tempa-launch.ps1 next to this file with Windows PowerShell,
rem with its own execution policy so the default Restricted policy does not stop it. See tempa-launch.ps1.
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0tempa-launch.ps1" %*
exit /b %ERRORLEVEL%
