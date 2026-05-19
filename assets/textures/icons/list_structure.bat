@echo off
setlocal
cd /d "%~dp0"
tree /f /a > "structure.txt"
echo Wrote "%CD%\structure.txt"
start "" "structure.txt"
pause