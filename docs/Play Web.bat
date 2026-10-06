@echo off
cd /d "%~dp0"
where py >nul 2>nul
if %errorlevel% equ 0 (
  py -3 "%~dp0serve.py" --open
) else (
  python "%~dp0serve.py" --open
)
if errorlevel 1 (
  echo Python 3 is required to preview this game locally.
  pause
)
