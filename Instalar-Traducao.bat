@echo off
chcp 65001 >nul
title Codex Router PT-BR - Tradução por Emerson Teles
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0aplicar-traducao.ps1"
if errorlevel 1 (
    echo.
    echo O instalador terminou com erro. Pressione uma tecla para fechar esta janela.
    pause >nul
    exit 1
)
exit 0
