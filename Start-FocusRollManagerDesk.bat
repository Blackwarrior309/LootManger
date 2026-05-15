@echo off
setlocal

set "ROOT=%~dp0"
set "APP_DIR=%ROOT%FocusRollManagerDesk"
set "VENV_DIR=%APP_DIR%\.venv"
set "PYTHON_EXE="

cd /d "%APP_DIR%" || (
  echo Konnte App-Ordner nicht finden: "%APP_DIR%"
  pause
  exit /b 1
)

if exist "%VENV_DIR%\Scripts\pythonw.exe" (
  set "PYTHON_EXE=%VENV_DIR%\Scripts\pythonw.exe"
  goto start_app
)

echo Richte FocusRollManagerDesk ein...

where py >nul 2>nul
if not errorlevel 1 (
  py -3 -m venv "%VENV_DIR%"
) else (
  where python >nul 2>nul
  if errorlevel 1 (
    echo Python wurde nicht gefunden.
    echo Bitte Python 3 installieren und danach diese Datei erneut starten.
    pause
    exit /b 1
  )
  python -m venv "%VENV_DIR%"
)

if errorlevel 1 (
  echo Virtuelle Umgebung konnte nicht erstellt werden.
  pause
  exit /b 1
)

"%VENV_DIR%\Scripts\python.exe" -m pip install --upgrade pip
if errorlevel 1 (
  echo pip konnte nicht aktualisiert werden.
  pause
  exit /b 1
)

"%VENV_DIR%\Scripts\python.exe" -m pip install -r requirements.txt
if errorlevel 1 (
  echo Abhaengigkeiten konnten nicht installiert werden.
  pause
  exit /b 1
)

set "PYTHON_EXE=%VENV_DIR%\Scripts\pythonw.exe"

:start_app
if not exist "%PYTHON_EXE%" (
  echo Python-Starter wurde nicht gefunden: "%PYTHON_EXE%"
  pause
  exit /b 1
)

start "" "%PYTHON_EXE%" "%APP_DIR%\main.py"
exit /b 0
