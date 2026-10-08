# ==============================================================================
#  Restaurador do Codex Router Original de Fábrica
#  Pacote de Tradução por: Emerson Teles
# ==============================================================================
$consoleUtf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding = $consoleUtf8
[Console]::OutputEncoding = $consoleUtf8
$OutputEncoding = $consoleUtf8
$Host.UI.RawUI.WindowTitle = "Restaurar Codex Router Original v1.0.0 - Emerson Teles"
$launchChoiceHelper = Join-Path $PSScriptRoot "tools\launch-choice.ps1"
if (-not (Test-Path -LiteralPath $launchChoiceHelper -PathType Leaf)) {
    throw "O helper para abrir o Codex Router não foi encontrado: $launchChoiceHelper"
}
. $launchChoiceHelper

function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host " ==================================================================== " -ForegroundColor Yellow
Write-Host "          RESTAURAR CODEX ROUTER ORIGINAL DE FÁBRICA                  " -ForegroundColor White
Write-Host "              Pacote de Tradução por: Emerson Teles                   " -ForegroundColor Cyan
    Write-Host " ==================================================================== " -ForegroundColor Yellow
    Write-Host ""
}

function Copy-FileWithProgress {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$Label = "Restaurando"
    )

    $sourceFile = New-Object System.IO.FileInfo($Source)
    $totalBytes = $sourceFile.Length
    $totalMB = [math]::Round($totalBytes / 1MB, 1)

    $bufferSize = 2MB
    $buffer = New-Object byte[] $bufferSize

    $sourceStream = [System.IO.File]::OpenRead($Source)
    $destStream = [System.IO.File]::Create($Destination)

    $totalRead = 0
    $lastPercent = -1

    Write-Host "  $Label..." -ForegroundColor Cyan

    try {
        while (($bytesRead = $sourceStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $destStream.Write($buffer, 0, $bytesRead)
            $totalRead += $bytesRead
            $percent = [math]::Floor(($totalRead / $totalBytes) * 100)

            if ($percent -ne $lastPercent) {
                $lastPercent = $percent
                $copiedMB = [math]::Round($totalRead / 1MB, 1)
                $barLen = 22
                $filled = [math]::Floor(($percent / 100) * $barLen)
                $bar = ('=' * $filled) + (' ' * ($barLen - $filled))
                $msg = "`r    [$bar] $percent% ($copiedMB MB / $totalMB MB)   "
                Write-Host -NoNewline $msg
                Start-Sleep -Milliseconds 5
            }
        }
        Write-Host ""
    }
    finally {
        if ($sourceStream) { $sourceStream.Close() }
        if ($destStream) { $destStream.Close() }
    }
}

function Get-FileSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Test-AsarFile([string]$Path, [switch]$RequirePtBr) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $stream = $null
    $reader = $null
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        if ($stream.Length -lt 18) { return $false }
        $reader = New-Object System.IO.BinaryReader($stream)
        $picklePrefix = $reader.ReadUInt32()
        $pickleSize = $reader.ReadUInt32()
        $stream.Position = 12
        $jsonLength = $reader.ReadUInt32()
        if ($picklePrefix -ne 4 -or (8L + $pickleSize) -gt $stream.Length -or $jsonLength -gt ($stream.Length - 16)) { return $false }
        $stream.Position = 16
        $header = [System.Text.Encoding]::UTF8.GetString($reader.ReadBytes([int]$jsonLength)) | ConvertFrom-Json
        if (-not $header.files) { return $false }
        if ($RequirePtBr) {
            $reader.Dispose()
            $reader = $null
            $stream = $null
            $contents = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
            foreach ($marker in @('Idioma da interface', 'Todas as verificações foram aprovadas', 'Ambiente de controle com pouca luz')) {
                if (-not $contents.Contains($marker)) { return $false }
            }
        }
        return $true
    } catch {
        return $false
    } finally {
        if ($reader) { $reader.Dispose() }
        elseif ($stream) { $stream.Dispose() }
    }
}

function Stop-CodexRouterProcesses([string]$ExePath) {
    $exeFullPath = [System.IO.Path]::GetFullPath($ExePath)
    $processes = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ExecutablePath -and [System.StringComparer]::OrdinalIgnoreCase.Equals(
            [System.IO.Path]::GetFullPath($_.ExecutablePath), $exeFullPath
        )
    })
    if ($processes.Count -eq 0) { return $true }

    Write-Host "[!] Fechando o Codex Router e seus processos auxiliares para restaurar os arquivos..." -ForegroundColor Yellow
    foreach ($process in $processes) { Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue }
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        Start-Sleep -Milliseconds 250
        $remaining = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
            $_.ExecutablePath -and [System.StringComparer]::OrdinalIgnoreCase.Equals(
                [System.IO.Path]::GetFullPath($_.ExecutablePath), $exeFullPath
            )
        })
        if ($remaining.Count -eq 0) {
            Write-Host "    [OK] O aplicativo foi fechado." -ForegroundColor Green
            return $true
        }
        foreach ($process in $remaining) { Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue }
    }
    Write-Host "[x] Não foi possível fechar todos os processos. Nenhum arquivo foi restaurado." -ForegroundColor Red
    return $false
}

function Find-CodexRouterInstallation {
    $candidates = @()

    $proc = Get-Process | Where-Object { $_.ProcessName -match "codex.*router" -or $_.Path -like "*@codex-routercontrol-center*" } | Select-Object -First 1
    if ($proc -and $proc.Path) {
        $candidates += (Split-Path $proc.Path -Parent)
    }

    $candidates += (Join-Path $env:LOCALAPPDATA "Programs\@codex-routercontrol-center")
    $candidates += (Join-Path $env:LOCALAPPDATA "Programs\Codex Router")
    $candidates += (Join-Path $env:ProgramFiles "@codex-routercontrol-center")
    $candidates += (Join-Path $env:ProgramFiles "Codex Router")
    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path ${env:ProgramFiles(x86)} "@codex-routercontrol-center")
        $candidates += (Join-Path ${env:ProgramFiles(x86)} "Codex Router")
    }

    foreach ($rp in @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )) {
        try {
            Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like "*Codex Router*" -and $_.InstallLocation } |
                ForEach-Object { $candidates += $_.InstallLocation }
        } catch { }
    }

    foreach ($cand in ($candidates | Where-Object { $_ } | Select-Object -Unique)) {
        if (Test-Path (Join-Path $cand "resources\app.asar")) {
            return $cand
        }
    }

    return $null
}

Write-Header

# 1. Localizar a instalação
Write-Host "[1/3] Localizando a pasta de instalação do Codex Router..." -ForegroundColor White
$routerDir = Find-CodexRouterInstallation

while (-not $routerDir -or -not (Test-Path (Join-Path $routerDir "resources\app.asar"))) {
    $userInput = Read-Host "Cole o caminho da pasta de instalação do Codex Router ou pressione Enter para cancelar"
    if ([string]::IsNullOrWhiteSpace($userInput)) {
        Write-Host "[x] Operação cancelada; nenhum arquivo foi alterado." -ForegroundColor Yellow
        Exit 1
    }
    if (Test-Path (Join-Path $userInput "resources\app.asar")) { $routerDir = $userInput }
}

Write-Host "    -> Localizado em: $routerDir" -ForegroundColor Green

$resourcesDir = Join-Path $routerDir "resources"
$targetAsar = Join-Path $resourcesDir "app.asar"
$targetExe = Join-Path $routerDir "Codex Router.exe"
$backupDir = Join-Path $routerDir "_backup"
$backupAsar = Join-Path $backupDir "app.asar"
$backupExe = Join-Path $backupDir "Codex Router.exe"
$statePath = Join-Path $backupDir "translation-info.json"

# 3. Verificar se existe backup original
Write-Host ""
Write-Host "[2/3] Verificando arquivo de backup original..." -ForegroundColor White

if (-not (Test-AsarFile -Path $targetAsar)) {
    Write-Host "[x] O app.asar instalado está ausente ou inválido; nada foi alterado." -ForegroundColor Red
    Exit 1
}
if (-not (Test-AsarFile -Path $targetAsar -RequirePtBr)) {
    $currentHash = Get-FileSha256 $targetAsar
    $englishExeRestored = $false
    $englishExeRecoveryError = $null
    $stagedEnglishExe = $null
    $replaceEnglishExe = $null
    if (Test-Path -LiteralPath $statePath -PathType Leaf) {
        try {
            $englishState = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
            if ($englishState.schemaVersion -eq 1 -and $englishState.sourceSha256 -eq $currentHash -and
                $englishState.exeOriginalSha256 -match '^[A-Fa-f0-9]{64}$') {
                $englishExeBackup = Join-Path $routerDir $englishState.backupExe
                if ((Test-Path -LiteralPath $englishExeBackup -PathType Leaf) -and
                    (Get-FileSha256 $englishExeBackup) -eq $englishState.exeOriginalSha256 -and
                    (Test-Path -LiteralPath $targetExe -PathType Leaf) -and
                    (Get-FileSha256 $targetExe) -ne $englishState.exeOriginalSha256) {
                    if (-not (Stop-CodexRouterProcesses -ExePath $targetExe)) { Exit 1 }
                    $stagedEnglishExe = Join-Path $routerDir "Codex Router.exe.restore.tmp"
                    $replaceEnglishExe = Join-Path $routerDir ("Codex Router.exe.pre-restore-" + [guid]::NewGuid().ToString('N') + ".bak")
                    Copy-Item -LiteralPath $englishExeBackup -Destination $stagedEnglishExe -Force
                    if ((Get-FileSha256 $stagedEnglishExe) -ne $englishState.exeOriginalSha256) {
                        throw "A cópia do executável original não passou na verificação."
                    }
                    [System.IO.File]::Replace($stagedEnglishExe, $targetExe, $replaceEnglishExe)
                    if ((Get-FileSha256 $targetExe) -ne $englishState.exeOriginalSha256) {
                        throw "A verificação do executável original falhou."
                    }
                    Remove-Item -LiteralPath $replaceEnglishExe -Force -ErrorAction SilentlyContinue
                    $englishExeRestored = $true
                }
            }
        } catch {
            if ($stagedEnglishExe) { Remove-Item -LiteralPath $stagedEnglishExe -Force -ErrorAction SilentlyContinue }
            if ($replaceEnglishExe) { Remove-Item -LiteralPath $replaceEnglishExe -Force -ErrorAction SilentlyContinue }
            $englishExeRecoveryError = $_.Exception.Message
        }
    }
    Write-Host "[OK] O Codex Router já está em inglês. Não é necessário restaurar." -ForegroundColor Green
    if ($englishExeRestored) {
        Write-Host "[OK] O executável original desta versão também foi restaurado." -ForegroundColor Green
    } elseif ($englishExeRecoveryError) {
        Write-Host "[!] Não foi possível conferir/restaurar o executável: $englishExeRecoveryError" -ForegroundColor Yellow
    }
    Write-Host ""
    $launchChoiceExitCode = Invoke-LaunchChoice -ExePath $targetExe -WorkingDirectory $routerDir
    [System.Environment]::Exit([int]$launchChoiceExitCode)
}

$currentHash = Get-FileSha256 $targetAsar
$restoreAsar = $null
$restoreExe = $null
$state = $null
if (Test-Path -LiteralPath $statePath -PathType Leaf) {
    try { $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json } catch { $state = $null }
}
if ($state) {
    if ($state.schemaVersion -ne 1 -or $state.installedSha256 -ne $currentHash -or $state.sourceSha256 -notmatch '^[A-Fa-f0-9]{64}$') {
        Write-Host "[x] A instalação atual não corresponde ao manifesto de restauração salvo. Nenhum arquivo foi alterado." -ForegroundColor Red
        Exit 1
    }
    $candidateAsar = Join-Path $routerDir $state.backupAsar
    $candidateExe = Join-Path $routerDir $state.backupExe
    if ((Test-AsarFile -Path $candidateAsar) -and (Get-FileSha256 $candidateAsar) -eq $state.sourceSha256) { $restoreAsar = $candidateAsar }
    if ($state.exeOriginalSha256 -match '^[A-Fa-f0-9]{64}$' -and (Test-Path -LiteralPath $candidateExe -PathType Leaf) -and (Get-FileSha256 $candidateExe) -eq $state.exeOriginalSha256) { $restoreExe = $candidateExe }
}
if (-not $state -and (Test-AsarFile -Path $backupAsar)) { $restoreAsar = $backupAsar }
if (-not $state -and (Test-Path -LiteralPath $backupExe -PathType Leaf)) { $restoreExe = $backupExe }
if (-not $restoreAsar -or (Get-FileSha256 $restoreAsar) -eq $currentHash) {
    Write-Host "[x] Não foi encontrado um backup original validado para esta tradução." -ForegroundColor Red
    Exit 1
}

Write-Host "    -> Backup desta instalação confirmado: $restoreAsar" -ForegroundColor Green
if (-not (Stop-CodexRouterProcesses -ExePath $targetExe)) { Exit 1 }

# 3. Restaurar app.asar e executável somente quando necessário.
Write-Host ""
Write-Host "[3/3] Restaurando os arquivos originais desta versão..." -ForegroundColor White
$stagedAsar = Join-Path $resourcesDir "app.asar.restore.tmp"
$replaceBackupAsar = Join-Path $resourcesDir ("app.asar.pre-restore-" + [guid]::NewGuid().ToString('N') + ".bak")
try {
    Copy-FileWithProgress -Source $restoreAsar -Destination $stagedAsar -Label "Preparando app.asar original"
    if ((Get-FileSha256 $stagedAsar) -ne (Get-FileSha256 $restoreAsar) -or -not (Test-AsarFile -Path $stagedAsar)) {
        throw "A cópia preparada não passou pela verificação."
    }
    [System.IO.File]::Replace($stagedAsar, $targetAsar, $replaceBackupAsar)
    if ((Get-FileSha256 $targetAsar) -ne (Get-FileSha256 $restoreAsar)) { throw "A verificação após a restauração falhou." }
    Remove-Item -LiteralPath $replaceBackupAsar -Force -ErrorAction SilentlyContinue
} catch {
    Remove-Item -LiteralPath $stagedAsar -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $replaceBackupAsar -Force -ErrorAction SilentlyContinue
    Write-Host "[x] Falha ao restaurar o ASAR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    O backup permanece preservado em: $restoreAsar" -ForegroundColor Yellow
    Exit 1
}

if ($restoreExe -and (Test-Path -LiteralPath $targetExe -PathType Leaf)) {
    if ((Get-FileSha256 $targetExe) -eq (Get-FileSha256 $restoreExe)) {
        Write-Host "    [OK] O executável desta versão já está restaurado." -ForegroundColor Green
    } else {
        $stagedExe = Join-Path $routerDir "Codex Router.exe.restore.tmp"
        $replaceBackupExe = Join-Path $routerDir ("Codex Router.exe.pre-restore-" + [guid]::NewGuid().ToString('N') + ".bak")
        try {
            Copy-Item -LiteralPath $restoreExe -Destination $stagedExe -Force
            if ((Get-FileSha256 $stagedExe) -ne (Get-FileSha256 $restoreExe)) { throw "A cópia do executável falhou na verificação." }
            [System.IO.File]::Replace($stagedExe, $targetExe, $replaceBackupExe)
            if ((Get-FileSha256 $targetExe) -ne (Get-FileSha256 $restoreExe)) { throw "A verificação do executável restaurado falhou." }
            Remove-Item -LiteralPath $replaceBackupExe -Force -ErrorAction SilentlyContinue
            Write-Host "    [OK] Executável desta versão restaurado." -ForegroundColor Green
        } catch {
            Remove-Item -LiteralPath $stagedExe -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $replaceBackupExe -Force -ErrorAction SilentlyContinue
            Write-Host "[!] O ASAR foi restaurado, mas o executável não pôde ser restaurado: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "    Backup do executável: $restoreExe" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host " ==================================================================== " -ForegroundColor Green
Write-Host "          CODEX ROUTER RESTAURADO COM SUCESSO!                        " -ForegroundColor Green
Write-Host " ==================================================================== " -ForegroundColor Green
Write-Host ""
Write-Host "  O Codex Router foi restaurado para o idioma e a versão original (inglês)." -ForegroundColor White
Write-Host ""

$launchChoiceExitCode = Invoke-LaunchChoice -ExePath $targetExe -WorkingDirectory $routerDir
[System.Environment]::Exit([int]$launchChoiceExitCode)
