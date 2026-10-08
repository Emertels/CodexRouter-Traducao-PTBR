@echo off
title Restaurar Codex Router Original - Emerson Teles
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0restaurar-original.ps1"
if errorlevel 1 (
    echo.
    echo A restauração terminou com erro. Pressione uma tecla para fechar esta janela.
    pause >nul
    exit 1
)
exit 0
