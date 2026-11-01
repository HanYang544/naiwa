@echo off
start "Naiwa Desktop Pet" powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0naiwa-pet.ps1"
