function Invoke-LaunchChoice {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExePath,

        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory
    )

    if (-not (Test-Path -LiteralPath $ExePath -PathType Leaf)) {
        Write-Host "[!] O executável do Codex Router não foi encontrado; nenhuma janela será aberta." -ForegroundColor Yellow
        return 0
    }

    Write-Host -NoNewline "Deseja abrir o Codex Router? [S = abrir e fechar o CMD | N, Esc ou Enter = fechar sem abrir]: " -ForegroundColor White
    while ($true) {
        $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        if ($key.VirtualKeyCode -eq 83 -or $key.Character -eq 's' -or $key.Character -eq 'S') {
            Write-Host "S"
            try {
                # Entregue o executável ao Explorer, fora da árvore de processos
                # do CMD/PowerShell que será encerrada ao concluir o pacote.
                $explorerPath = Join-Path $env:WINDIR 'explorer.exe'
                $quotedExePath = '"' + $ExePath + '"'
                Start-Process -FilePath $explorerPath -ArgumentList $quotedExePath -WorkingDirectory $WorkingDirectory -ErrorAction Stop | Out-Null
                Start-Sleep -Milliseconds 400
                Write-Host "Abrindo o Codex Router e fechando o CMD..." -ForegroundColor Cyan
                return 0
            } catch {
                Write-Host "[x] Não foi possível iniciar o Codex Router: $($_.Exception.Message)" -ForegroundColor Red
                return 1
            }
        }

        if ($key.VirtualKeyCode -eq 78 -or $key.VirtualKeyCode -eq 27 -or $key.VirtualKeyCode -eq 13 -or
            $key.Character -eq 'n' -or $key.Character -eq 'N') {
            if ($key.VirtualKeyCode -eq 27) { Write-Host "Esc" }
            elseif ($key.VirtualKeyCode -eq 13) { Write-Host "Enter" }
            else { Write-Host "N" }
            Write-Host "Concluído. Fechando sem abrir o Codex Router..." -ForegroundColor Cyan
            return 0
        }
    }
}
