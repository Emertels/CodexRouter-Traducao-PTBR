# ==============================================================================
#  Instalador Universal de Tradução PT-BR para Codex Router Control Center
#  Tradução e Personalização por: Emerson Teles
# ==============================================================================
$consoleUtf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding = $consoleUtf8
[Console]::OutputEncoding = $consoleUtf8
$OutputEncoding = $consoleUtf8
$Host.UI.RawUI.WindowTitle = "Instalador Codex Router PT-BR v1.3.0 - Emerson Teles"
$launchChoiceHelper = Join-Path $PSScriptRoot "tools\launch-choice.ps1"
if (-not (Test-Path -LiteralPath $launchChoiceHelper -PathType Leaf)) {
    throw "O helper para abrir o Codex Router não foi encontrado: $launchChoiceHelper"
}
. $launchChoiceHelper

function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host " ==================================================================== " -ForegroundColor Cyan
Write-Host "       TRADUÇÃO CODEX ROUTER PARA PORTUGUÊS DO BRASIL                 " -ForegroundColor Green
    Write-Host "            Desenvolvido e Personalizado por: Emerson Teles           " -ForegroundColor Yellow
    Write-Host " ==================================================================== " -ForegroundColor Cyan
    Write-Host ""
}

function Copy-FileWithProgress {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$Label = "Copiando"
    )

    $sourceFile = New-Object System.IO.FileInfo($Source)
    $totalBytes = $sourceFile.Length
    $totalMB = [math]::Round($totalBytes / 1MB, 1)

    $bufferSize = 2MB
    $buffer = New-Object byte[] $bufferSize

    $retryCount = 0
    $maxRetries = 5
    $success = $false

    while (-not $success -and $retryCount -lt $maxRetries) {
        try {
            $destParent = Split-Path $Destination -Parent
            if (-not (Test-Path $destParent)) {
                New-Item -ItemType Directory -Path $destParent -Force | Out-Null
            }

            $sourceStream = [System.IO.File]::OpenRead($Source)
            $destStream = [System.IO.File]::Create($Destination)

            $totalRead = 0
            $lastPercent = -1

            Write-Host "  $Label..." -ForegroundColor Cyan

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
            $success = $true
        }
        catch {
            $retryCount++
            Write-Host "`n    [!] Arquivo temporariamente em uso. Tentativa $retryCount de $maxRetries em 2 segundos..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
        finally {
            if ($sourceStream) { $sourceStream.Close() }
            if ($destStream) { $destStream.Close() }
        }
    }

    if (-not $success) {
    Write-Host "[x] Erro: não foi possível copiar para $Destination. Verifique se há processos abertos." -ForegroundColor Red
    throw "Falha na cópia do arquivo"
    }
}

function Get-FileSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Stop-CodexRouterProcesses([string]$ExePath) {
    $exeFullPath = [System.IO.Path]::GetFullPath($ExePath)
    $processes = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ExecutablePath -and [System.StringComparer]::OrdinalIgnoreCase.Equals(
            [System.IO.Path]::GetFullPath($_.ExecutablePath), $exeFullPath
        )
    })
    if ($processes.Count -eq 0) { return $true }

    Write-Host "[!] Fechando o Codex Router e seus processos auxiliares para aplicar a tradução..." -ForegroundColor Yellow
    Write-Host "    O fechamento forçado pode descartar alterações ainda não salvas." -ForegroundColor Gray
    foreach ($process in $processes) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }

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
        foreach ($process in $remaining) {
            Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "[x] Não foi possível fechar todos os processos do Codex Router. Nenhum ASAR foi substituído." -ForegroundColor Red
    return $false
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
        $dataStart = 8L + $pickleSize
        if ($picklePrefix -ne 4 -or $dataStart -gt $stream.Length -or $jsonLength -gt ($stream.Length - 16)) { return $false }
        $stream.Position = 16
        $headerBytes = $reader.ReadBytes([int]$jsonLength)
        $header = [System.Text.Encoding]::UTF8.GetString($headerBytes) | ConvertFrom-Json
        if (-not $header.files) { return $false }
        if ($RequirePtBr) {
            $stream.Dispose()
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

function Disable-AsarIntegrityFuse {
    param([string]$ExePath)

    if (-not (Test-Path -LiteralPath $ExePath -PathType Leaf)) { return $false }

    try {
        if (-not ([System.Management.Automation.PSTypeName]'FastFuse').Type) {
            Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;

public class FastFuse {
    public static int FindAndPatch(string path) {
        if (!File.Exists(path)) return -1;
        byte[] bytes = File.ReadAllBytes(path);
        byte[] magic = Encoding.ASCII.GetBytes("WNKmHXBZaB9tsX");
        for (int i = 0; i <= bytes.Length - magic.Length - 16; i++) {
            if (bytes[i] == magic[0]) {
                bool match = true;
                for (int j = 1; j < magic.Length; j++) {
                    if (bytes[i + j] != magic[j]) { match = false; break; }
                }
                if (match) {
                    int fuseIndex = i + magic.Length + 6;
                    if (fuseIndex < bytes.Length) {
                        if (bytes[fuseIndex] == (byte)'1') {
                            bytes[fuseIndex] = (byte)'0';
                            File.WriteAllBytes(path, bytes);
                            return 1;
                        } else {
                            return 0;
                        }
                    }
                }
            }
        }
        return -2;
    }
}
'@
        }

        $res = [FastFuse]::FindAndPatch($ExePath)
        if ($res -eq 1) {
    Write-Host "    [OK] Verificação de integridade ASAR desativada com sucesso no executável." -ForegroundColor Green
        } elseif ($res -eq 0) {
    Write-Host "    [OK] Executável já está configurado para aceitar pacotes personalizados." -ForegroundColor Green
        } else {
            Write-Host "    [x] Não foi possível localizar/verificar o Electron Fuse esperado." -ForegroundColor Red
            return $false
        }
        return $true
    } catch {
    Write-Host "    [!] Aviso ao verificar a integridade do executável: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

function Find-CodexRouterInstallation {
    $candidates = @()

    $proc = Get-Process | Where-Object { $_.ProcessName -match "codex.*router" -or $_.Path -like "*@codex-routercontrol-center*" } | Select-Object -First 1
    if ($proc -and $proc.Path) {
        $candidates += (Split-Path $proc.Path -Parent)
    }

    $candidates += "$env:LOCALAPPDATA\Programs\@codex-routercontrol-center"
    $candidates += "$env:LOCALAPPDATA\Programs\Codex Router"
    $candidates += (Join-Path $env:LOCALAPPDATA "Programs\@codex-routercontrol-center")
    $candidates += (Join-Path $env:LOCALAPPDATA "Programs\Codex Router")
    $candidates += (Join-Path $env:ProgramFiles "@codex-routercontrol-center")
    $candidates += (Join-Path $env:ProgramFiles "Codex Router")
    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path ${env:ProgramFiles(x86)} "@codex-routercontrol-center")
        $candidates += (Join-Path ${env:ProgramFiles(x86)} "Codex Router")
    }

    $regPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($rp in $regPaths) {
        try {
            $keys = Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*Codex Router*" -or $_.DisplayName -like "*control-center*" }
            foreach ($k in $keys) {
                if ($k.InstallLocation -and (Test-Path $k.InstallLocation)) {
                    $candidates += $k.InstallLocation
                }
            }
        } catch { }
    }

    foreach ($cand in ($candidates | Where-Object { $_ } | Select-Object -Unique)) {
        if ((Test-Path (Join-Path $cand "resources\app.asar")) -or (Test-Path (Join-Path $cand "Codex Router.exe"))) {
            return $cand
        }
    }

    return $null
}

# Inicio da Execucao
Write-Header

# 1. Localizar a instalação do Codex Router
Write-Host "[1/4] Procurando a instalação do Codex Router no computador..." -ForegroundColor White
$routerDir = Find-CodexRouterInstallation

while (-not $routerDir -or -not (Test-Path $routerDir)) {
    Write-Host ""
Write-Host "[!] Não foi possível detectar a pasta do Codex Router automaticamente." -ForegroundColor Yellow
$userInput = Read-Host "Digite ou cole o caminho da pasta onde o Codex Router está instalado"
    if ([string]::IsNullOrWhiteSpace($userInput)) {
    Write-Host "[x] Operação cancelada pelo usuário." -ForegroundColor Red
        Exit 1
    }
    if (Test-Path (Join-Path $userInput "resources\app.asar")) {
        $routerDir = $userInput
    } else {
Write-Host "[x] Caminho inválido ou 'resources\app.asar' não encontrado nessa pasta!" -ForegroundColor Red
    }
}

Write-Host "    -> Codex Router localizado em: $routerDir" -ForegroundColor Green
$resourcesDir = Join-Path $routerDir "resources"
$targetAsar = Join-Path $resourcesDir "app.asar"
$targetExe = Join-Path $routerDir "Codex Router.exe"

# Pasta padronizada de backup dentro do diretorio do programa
$backupDir = Join-Path $routerDir "_backup"
$backupAsar = Join-Path $backupDir "app.asar"
$backupExe = Join-Path $backupDir "Codex Router.exe"
$statePath = Join-Path $backupDir "translation-info.json"

# 3. Localizar arquivos desta pasta
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

$sourceAsar = Join-Path $scriptDir "app-pt.asar"
$manifestPath = "$sourceAsar.manifest.json"

if (-not (Test-AsarFile -Path $targetAsar)) {
    Write-Host "[x] O app.asar instalado está ausente ou inválido; nada foi alterado." -ForegroundColor Red
    Exit 1
}

$targetHash = Get-FileSha256 $targetAsar
if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
    try { $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json } catch { $manifest = $null }
} else { $manifest = $null }

# Se o ASAR da aplicação mudou, reconstrua a tradução a partir desta instalação.
$targetHasPtBr = Test-AsarFile -Path $targetAsar -RequirePtBr
$savedState = $null
if ($targetHasPtBr -and (Test-Path -LiteralPath $statePath -PathType Leaf)) {
    try {
        $savedState = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        $candidate = Join-Path $routerDir $savedState.backupAsar
        if ($manifest -and $manifest.schemaVersion -eq 1 -and
            $manifest.translatedSha256 -eq $targetHash -and $manifest.sourceSha256 -eq $savedState.sourceSha256 -and
            $savedState.schemaVersion -eq 1 -and $savedState.installedSha256 -eq $targetHash -and
            (Test-AsarFile -Path $candidate) -and (Get-FileSha256 $candidate) -eq $savedState.sourceSha256) {
            Write-Host "[OK] Esta tradução já está instalada e o backup correspondente está validado; nenhuma cópia foi feita." -ForegroundColor Green
            $launchChoiceExitCode = Invoke-LaunchChoice -ExePath $targetExe -WorkingDirectory $routerDir
            [System.Environment]::Exit([int]$launchChoiceExitCode)
        }
    } catch { $savedState = $null }
}
if ($manifest -and $manifest.schemaVersion -eq 1 -and $manifest.translatedSha256 -eq $targetHash -and $targetHasPtBr) {
    $matchingBackup = $null
    if (Test-Path -LiteralPath $statePath -PathType Leaf) {
        try {
            $savedState = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
            $candidate = Join-Path $routerDir $savedState.backupAsar
            if ($savedState.installedSha256 -eq $targetHash -and (Test-AsarFile -Path $candidate) -and (Get-FileSha256 $candidate) -eq $savedState.sourceSha256) {
                $matchingBackup = $candidate
            }
        } catch { }
    }
    if (-not $matchingBackup -and (Test-AsarFile -Path $backupAsar) -and (Get-FileSha256 $backupAsar) -eq $manifest.sourceSha256) { $matchingBackup = $backupAsar }
    if (-not $matchingBackup) {
        $versionedBackup = Join-Path (Join-Path $routerDir "_backup\versions") ("app-" + $manifest.sourceSha256 + ".asar")
        if ((Test-AsarFile -Path $versionedBackup) -and (Get-FileSha256 $versionedBackup) -eq $manifest.sourceSha256) { $matchingBackup = $versionedBackup }
    }
    if ($matchingBackup) {
        Write-Host "[OK] Esta tradução já está instalada; nenhuma cópia foi feita." -ForegroundColor Green
        $launchChoiceExitCode = Invoke-LaunchChoice -ExePath $targetExe -WorkingDirectory $routerDir
        [System.Environment]::Exit([int]$launchChoiceExitCode)
    }
    Write-Host "[x] A tradução está instalada, mas não foi possível validar o backup correspondente." -ForegroundColor Red
    Write-Host "    O script preservou os arquivos sem sobrescrevê-los." -ForegroundColor Yellow
    Exit 1
}

$buildInputAsar = $targetAsar
if ($targetHasPtBr) {
    $buildInputAsar = $null
    if (Test-Path -LiteralPath $statePath -PathType Leaf) {
        try {
            $savedState = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
            $candidate = Join-Path $routerDir $savedState.backupAsar
            if ($savedState.installedSha256 -eq $targetHash -and (Test-AsarFile -Path $candidate) -and (Get-FileSha256 $candidate) -eq $savedState.sourceSha256) {
                $buildInputAsar = $candidate
            }
        } catch { }
    }
    if (-not $buildInputAsar) {
        Write-Host "[x] O ASAR instalado tem traduções, mas não corresponde a um pacote ou backup reconhecido." -ForegroundColor Red
        Write-Host "    Restaure o original correspondente antes de atualizar a tradução." -ForegroundColor Yellow
        Exit 1
    }
}

$needsBuild = (-not $manifest) -or ($manifest.schemaVersion -ne 1) -or ($manifest.sourceSha256 -ne (Get-FileSha256 $buildInputAsar)) -or (-not (Test-AsarFile -Path $sourceAsar -RequirePtBr))
if ($needsBuild) {
    $nodeCommand = Get-Command node -ErrorAction SilentlyContinue
    $builderPath = Join-Path $scriptDir "tools\build-translated-asar.cjs"
    if (-not $nodeCommand -or -not (Test-Path -LiteralPath $builderPath -PathType Leaf)) {
        Write-Host "[x] A versão instalada é diferente e não foi possível gerar a tradução automaticamente." -ForegroundColor Red
        Write-Host "    Instale o Node.js 18+ e mantenha a pasta tools junto dos scripts." -ForegroundColor Yellow
        Exit 1
    }
    Write-Host "[i] A instalação usa uma versão diferente. Gerando um pacote compatível com o app.asar atual..." -ForegroundColor Cyan
    & $nodeCommand.Source $builderPath $buildInputAsar $sourceAsar
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[x] Esta versão tem alterações incompatíveis com o catálogo atual. Nenhum arquivo instalado foi substituído." -ForegroundColor Red
        Exit 1
    }
    try { $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json } catch { $manifest = $null }
}

if (-not (Test-AsarFile -Path $sourceAsar -RequirePtBr) -or -not $manifest -or $manifest.schemaVersion -ne 1 -or $manifest.translatedSha256 -ne (Get-FileSha256 $sourceAsar) -or $manifest.sourceSha256 -ne (Get-FileSha256 $buildInputAsar)) {
    Write-Host "[x] O pacote gerado não passou pela conferência de versão e integridade." -ForegroundColor Red
    Exit 1
}
$sourceHash = Get-FileSha256 $sourceAsar
$targetHash = Get-FileSha256 $targetAsar

# 2. Validar a versão de origem e preparar um backup que possa ser restaurado depois.
Write-Host ""
Write-Host "[2/4] Preparando backup desta versão do aplicativo..." -ForegroundColor White
if (-not (Test-Path -LiteralPath $backupDir -PathType Container)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}
$versionsDir = Join-Path $backupDir "versions"
$activeBackupAsar = $null
$sourceFullPath = [System.IO.Path]::GetFullPath($buildInputAsar)
$targetFullPath = [System.IO.Path]::GetFullPath($targetAsar)
$installFullPath = [System.IO.Path]::GetFullPath($routerDir).TrimEnd('\') + '\'
if ($sourceFullPath.StartsWith($installFullPath, [System.StringComparison]::OrdinalIgnoreCase) -and
    -not [System.StringComparer]::OrdinalIgnoreCase.Equals($sourceFullPath, $targetFullPath)) {
    $activeBackupAsar = $sourceFullPath
}
if ($activeBackupAsar -and ((Get-FileSha256 $activeBackupAsar) -ne $manifest.sourceSha256 -or -not (Test-AsarFile -Path $activeBackupAsar))) {
    Write-Host "[x] A origem indicada para restauração não passou na validação." -ForegroundColor Red
    Exit 1
}
if (-not $activeBackupAsar) {
    if ((Test-AsarFile -Path $backupAsar) -and (Get-FileSha256 $backupAsar) -eq $manifest.sourceSha256) {
        $activeBackupAsar = $backupAsar
    } else {
        if (-not (Test-Path -LiteralPath $versionsDir -PathType Container)) { New-Item -ItemType Directory -Path $versionsDir -Force | Out-Null }
        $activeBackupAsar = Join-Path $versionsDir ("app-" + $manifest.sourceSha256 + ".asar")
        if (Test-Path -LiteralPath $activeBackupAsar -PathType Leaf) {
            if ((Get-FileSha256 $activeBackupAsar) -ne $manifest.sourceSha256 -or -not (Test-AsarFile -Path $activeBackupAsar)) {
                Write-Host "[x] O backup versionado existente não confere; ele foi preservado." -ForegroundColor Red
                Exit 1
            }
        } else {
            $backupTemp = "$activeBackupAsar.tmp"
            Copy-FileWithProgress -Source $buildInputAsar -Destination $backupTemp -Label "Salvando o ASAR original desta versão"
            if ((Get-FileSha256 $backupTemp) -ne $manifest.sourceSha256 -or -not (Test-AsarFile -Path $backupTemp)) {
                Remove-Item -LiteralPath $backupTemp -Force -ErrorAction SilentlyContinue
                Write-Host "[x] O backup desta versão não passou na validação; nada foi instalado." -ForegroundColor Red
                Exit 1
            }
            Move-Item -LiteralPath $backupTemp -Destination $activeBackupAsar
        }
    }
}
$backupAsarRelative = $activeBackupAsar.Substring($routerDir.Length).TrimStart('\')

if (-not (Test-Path -LiteralPath $targetExe -PathType Leaf)) {
    Write-Host "[x] O executável do Codex Router não foi encontrado; a instalação foi cancelada." -ForegroundColor Red
    Exit 1
}
$activeBackupExe = $null
if ($targetHasPtBr -and $savedState -and $savedState.installedSha256 -eq $targetHash -and
    $savedState.exeOriginalSha256 -match '^[A-Fa-f0-9]{64}$') {
    $savedExeCandidate = Join-Path $routerDir $savedState.backupExe
    if ((Test-Path -LiteralPath $savedExeCandidate -PathType Leaf) -and
        (Get-FileSha256 $savedExeCandidate) -eq $savedState.exeOriginalSha256) {
        $activeBackupExe = $savedExeCandidate
        $exeOriginalHash = $savedState.exeOriginalSha256
    } else {
        Write-Host "[x] O backup original do executável registrado para esta tradução não confere; ele foi preservado." -ForegroundColor Red
        Exit 1
    }
} else {
    $exeOriginalHash = Get-FileSha256 $targetExe
    if ((Test-Path -LiteralPath $backupExe -PathType Leaf) -and (Get-FileSha256 $backupExe) -eq $exeOriginalHash) {
        $activeBackupExe = $backupExe
    } else {
        if (-not (Test-Path -LiteralPath $versionsDir -PathType Container)) { New-Item -ItemType Directory -Path $versionsDir -Force | Out-Null }
        $activeBackupExe = Join-Path $versionsDir ("Codex-Router-" + $exeOriginalHash + ".exe")
        if (-not (Test-Path -LiteralPath $activeBackupExe -PathType Leaf)) {
            Copy-Item -LiteralPath $targetExe -Destination $activeBackupExe
        }
        if ((Get-FileSha256 $activeBackupExe) -ne $exeOriginalHash) {
            Write-Host "[x] O backup do executável não passou na validação; nada foi instalado." -ForegroundColor Red
            Exit 1
        }
    }
}
$backupExeRelative = $activeBackupExe.Substring($routerDir.Length).TrimStart('\')

if (-not (Stop-CodexRouterProcesses -ExePath $targetExe)) { Exit 1 }
if ((Get-FileSha256 $targetAsar) -ne $targetHash) {
    Write-Host "[x] O app.asar mudou enquanto o instalador fechava o aplicativo. Execute o instalador novamente para gerar o pacote correto." -ForegroundColor Red
    Exit 1
}

# 5. Ajustar a integridade do executável somente depois do backup do ASAR e do executável.
Write-Host ""
Write-Host "[3/4] Configurando a integridade do executável..." -ForegroundColor White
if (-not (Disable-AsarIntegrityFuse -ExePath $targetExe)) {
    Copy-Item -LiteralPath $activeBackupExe -Destination $targetExe -Force
    Write-Host "[x] Não foi possível preparar o executável. O app.asar não foi substituído." -ForegroundColor Red
    Exit 1
}

# 6. Aplicar app-pt.asar
Write-Host ""
Write-Host "[4/4] Instalando pacote principal traduzido..." -ForegroundColor White
$stagedAsar = Join-Path $resourcesDir "app.asar.ptbr.tmp"
$replaceBackupAsar = Join-Path $resourcesDir ("app.asar.pre-ptbr-" + [guid]::NewGuid().ToString('N') + ".bak")
try {
    Copy-FileWithProgress -Source $sourceAsar -Destination $stagedAsar -Label "Preparando app-pt.asar traduzido"
    if ((Get-FileSha256 $stagedAsar) -ne $sourceHash -or -not (Test-AsarFile -Path $stagedAsar -RequirePtBr)) {
        throw "A cópia preparada não passou pela verificação de hash e estrutura."
    }
    [System.IO.File]::Replace($stagedAsar, $targetAsar, $replaceBackupAsar)
    if ((Get-FileSha256 $targetAsar) -ne $sourceHash -or -not (Test-AsarFile -Path $targetAsar -RequirePtBr)) {
        throw "A verificação após a instalação falhou."
    }
    Remove-Item -LiteralPath $replaceBackupAsar -Force -ErrorAction SilentlyContinue
} catch {
    Remove-Item -LiteralPath $stagedAsar -Force -ErrorAction SilentlyContinue
    if (Test-AsarFile -Path $activeBackupAsar) {
        Copy-Item -LiteralPath $activeBackupAsar -Destination $targetAsar -Force
    }
    Copy-Item -LiteralPath $activeBackupExe -Destination $targetExe -Force
    Remove-Item -LiteralPath $replaceBackupAsar -Force -ErrorAction SilentlyContinue
    Write-Host "[x] Falha ao instalar/verificar a tradução: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    O backup original continua em: $activeBackupAsar" -ForegroundColor Yellow
    Exit 1
}

$state = [ordered]@{
    schemaVersion = 1
    installedSha256 = $sourceHash
    sourceSha256 = $manifest.sourceSha256
    backupAsar = $backupAsarRelative
    exeOriginalSha256 = $exeOriginalHash
    backupExe = $backupExeRelative
    installedAt = (Get-Date).ToString('o')
}
$stateTemp = "$statePath.tmp"
[System.IO.File]::WriteAllText($stateTemp, ($state | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding($false)))
Move-Item -LiteralPath $stateTemp -Destination $statePath -Force

# Conclusão
Write-Host ""
Write-Host " ==================================================================== " -ForegroundColor Green
Write-Host "       TRADUÇÃO CODEX ROUTER INSTALADA COM SUCESSO!                   " -ForegroundColor Green
Write-Host " ==================================================================== " -ForegroundColor Green
Write-Host ""
Write-Host "  Os textos incluídos neste pacote agora estão em Português do Brasil (pt-BR)." -ForegroundColor White
Write-Host "  Seu backup original de fábrica está seguro em:" -ForegroundColor Gray
Write-Host "  $backupDir" -ForegroundColor Yellow
Write-Host ""

$launchChoiceExitCode = Invoke-LaunchChoice -ExePath $targetExe -WorkingDirectory $routerDir
[System.Environment]::Exit([int]$launchChoiceExitCode)
