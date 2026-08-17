@echo off
setlocal enabledelayedexpansion
REM Build a release APK whose Android versionName is based on local month/day/hour/minute.
REM Example: June 26 15:21 -> 6.26.15.21
REM Usage: scripts\build_release_versioned.bat [extra flutter build args]

cd /d "%~dp0.."

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format 'M.d.HH.mm'"') do set BUILD_NAME=%%i
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format 'MMddHHmm'"') do set BUILD_NUMBER=%%i

if exist "E:\DevelopmentSoftware\flutter\bin\flutter.bat" (
  set FLUTTER_BIN=E:\DevelopmentSoftware\flutter\bin\flutter.bat
) else (
  set FLUTTER_BIN=flutter
)

echo Building AstrBot Mobile Dashboard
echo   versionName: %BUILD_NAME%
echo   versionCode: %BUILD_NUMBER%
echo.

"%FLUTTER_BIN%" build apk --release --build-name "%BUILD_NAME%" --build-number "%BUILD_NUMBER%" %*

echo.
echo APK output:
dir build\app\outputs\flutter-apk\*.apk
