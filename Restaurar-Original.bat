@echo off
title Restaurador PT-BR - Codex Router - Emerson Teles
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0restaurar-original.ps1"
set "PS_EXIT=%ERRORLEVEL%"
if not "%PS_EXIT%"=="0" (
    echo.
    echo A restauração terminou com erro. Pressione uma tecla para fechar esta janela.
    pause >nul
    exit /b %PS_EXIT%
)
exit /b %PS_EXIT%
