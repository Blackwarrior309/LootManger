@echo off
setlocal

cd /d "%~dp0FocusRollManagerDesk"

where py >nul 2>nul
if %errorlevel%==0 (
    py -3 main.py
) else (
    python main.py
)

if errorlevel 1 (
    echo.
    echo Desktop-App konnte nicht gestartet werden.
    echo Falls PyQt6 fehlt, fuehre aus:
    echo pip install -r "%~dp0FocusRollManagerDesk\requirements.txt"
    echo.
    pause
)
