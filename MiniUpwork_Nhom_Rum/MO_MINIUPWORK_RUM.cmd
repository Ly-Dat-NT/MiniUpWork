@echo off
setlocal
set "MINIUPWORK_RUM_FOLDER=%~dp0"
powershell.exe -NoLogo -NoProfile -Command "Set-Location -LiteralPath $env:MINIUPWORK_RUM_FOLDER -ErrorAction Stop; $lab = 'C:\Users\LENOVO\Documents\Codex\2026-10-26\dda\work\lab2site'; $runtime = 'C:\Program Files\WindowsApps\OpenAI.CodexPrimaryRuntime.v26-1112-737-0_26.1112.737.0_x64__3k8sg7r9htsxt\dependencies\python\python.exe'; if (Test-Path '.\.venv\Scripts\python.exe') { $runtime = '.\.venv\Scripts\python.exe' } elseif ((Test-Path $runtime) -and (Test-Path $lab)) { $env:PYTHONPATH = $lab } else { Write-Host 'Mo README.md de cai thu vien Python.'; exit 1 }; & $runtime -B '.\run_local.py'; exit $LASTEXITCODE"
if not errorlevel 1 exit /b 0
pause
exit /b 1
