@echo off
REM ============================================================================
REM OpenCode Power Kit - opk.cmd
REM Shim de Windows goi duoc `opk` tu CMD/PowerShell.
REM Dung OPK_KIT_DIR neu co, neu khong tu detect.
REM ============================================================================
if "%OPK_KIT_DIR%"=="" goto :no_kit
if not exist "%OPK_KIT_DIR%\bin\opk.ps1" goto :no_kit
powershell -ExecutionPolicy Bypass -File "%OPK_KIT_DIR%\bin\opk.ps1" %*
exit /b %ERRORLEVEL%

:no_kit
echo [ERROR] OPK_KIT_DIR chua set hoac khong hop le. >&2
echo   Hay set OPK_KIT_DIR=C:\path\to\opencode-power-kit roi goi lai. >&2
echo   Vi du: setx OPK_KIT_DIR C:\path\to\opencode-power-kit >&2
exit /b 1
