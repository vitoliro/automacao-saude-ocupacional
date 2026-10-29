# =========================================================================
# Organizar-ASOs.ps1
# Distribui os PDFs de ASO que chegam numa pasta de entrada para a pasta
# de cada colaborador (subpasta "ASO", criada se não existir).
#
#  - Casa o nome do arquivo com o nome da pasta do colaborador
#    (ignora acento, maiúscula, "_", "-" e sufixos como " - 2026 - PERIODICO").
#  - Nada é perdido: não encontrado -> _NAO_ENCONTRADO ; homônimo -> _AMBIGUO.
#  - Nunca sobrescreve: se já existe arquivo com o mesmo nome, adiciona data/hora.
#  - Modo simulação (-DryRun) mostra tudo o que faria sem mover nada.
#  - Log detalhado por execução + relatório-resumo acumulativo (histórico).
#
# USO:
#   .\Organizar-ASOs.ps1 -DryRun        # confere sem mover
#   .\Organizar-ASOs.ps1                # executa
#   Para testar: rode antes exemplos\Criar-AmbienteDemo.ps1
#
# Dados e caminhos deste repositório são FICTÍCIOS.
# =========================================================================
param(
    [string]$InboxPath         = 'C:\Demo\ASOs_Entrada',      # onde chegam os PDFs (nome do arquivo = nome do colaborador)
    [string]$RootPath          = 'C:\Demo\Colaboradores',     # raiz: Empresa\Colaborador
    [string]$AsoFolderName     = 'ASO',
    [int]   $FolderSearchDepth = 2,                           # 2 = Raiz -> Empresa -> Colaborador
    [switch]$DryRun
)

$NaoEncontradoFolderName = '_NAO_ENCONTRADO'
$AmbiguoFolderName       = '_AMBIGUO'
$LogPath     = Join-Path $InboxPath ('Log_ASOs_' + (Get-Date -Format 'yyyy-MM-dd_HHmmss') + '.csv')
$SummaryPath = Join-Path $InboxPath 'Relatorio_Resumo_ASOs.csv'

function Remove-Diacritics([string]$Text) {
    $normalized = $Text.Normalize([System.Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $normalized.ToCharArray()) {
        if ([System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($ch)
        }
    }
    return $sb.ToString().Normalize([System.Text.NormalizationForm]::FormC)
}

function ConvertTo-NormalizedName([string]$Text) {
    $t = (Remove-Diacritics $Text).ToUpperInvariant()
    $t = $t -replace '[_\-]', ' '
    $t = $t -replace '\s+', ' '
    return $t.Trim()
}

function Get-CandidateName([string]$FileBaseName) {
    # "MARIA EXEMPLO DA SILVA - 2026 - PERIODICO (1)" -> "MARIA EXEMPLO DA SILVA"
    $clean = $FileBaseName -split ' - ' | Select-Object -First 1
    $clean = $clean -split '\(' | Select-Object -First 1
    return $clean.Trim()
}

function Move-OrSimulate([string]$SourcePath, [string]$DestFolder, [string]$FileName, [bool]$Simular) {
    if (-not (Test-Path $DestFolder)) {
        if ($Simular) { Write-Host "[SIMULAÇÃO] Criaria pasta: $DestFolder" -ForegroundColor Yellow }
        else { New-Item -Path $DestFolder -ItemType Directory | Out-Null }
    }
    $destination = Join-Path $DestFolder $FileName
    if (Test-Path $destination) {
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $destination = Join-Path $DestFolder ('{0}_{1}{2}' -f [IO.Path]::GetFileNameWithoutExtension($FileName), $stamp, [IO.Path]::GetExtension($FileName))
    }
    if ($Simular) { Write-Host "[SIMULAÇÃO] Moveria '$FileName' -> '$destination'" -ForegroundColor Cyan }
    else { Move-Item -Path $SourcePath -Destination $destination }
    return $destination
}

# ------------------------- EXECUÇÃO --------------------------------------
foreach ($p in $InboxPath, $RootPath) {
    if (-not (Test-Path $p)) { Write-Host "ERRO: pasta não encontrada: $p" -ForegroundColor Red; exit 1 }
}

$NaoEncontradoFolder = Join-Path $InboxPath $NaoEncontradoFolderName
$AmbiguoFolder       = Join-Path $InboxPath $AmbiguoFolderName

Write-Host "Mapeando pastas de colaboradores em $RootPath ..."
# Profundidade limitada: não entra nas pastas ASO (cheias de PDFs antigos) -> bem mais rápido
$allEmployeeFolders = @(Get-ChildItem -Path $RootPath -Directory -Recurse -Depth ($FolderSearchDepth - 1) |
    Where-Object { $_.Name -ne $AsoFolderName })
Write-Host ('Encontradas {0} pastas candidatas.' -f $allEmployeeFolders.Count)

# Índice nome-normalizado -> pastas (evita comparar cada PDF com todas as pastas)
$indice = @{}
foreach ($f in $allEmployeeFolders) {
    $k = ConvertTo-NormalizedName $f.Name
    if (-not $indice.ContainsKey($k)) { $indice[$k] = New-Object System.Collections.ArrayList }
    [void]$indice[$k].Add($f)
}

$logEntries = New-Object System.Collections.ArrayList
# Só a raiz da entrada: as subpastas de pendência não são reprocessadas sozinhas
$files = @(Get-ChildItem -Path $InboxPath -File -Filter '*.pdf')
if ($files.Count -eq 0) { Write-Host "Nenhum PDF novo em $InboxPath." }

foreach ($file in $files) {
    $candidateName = Get-CandidateName ([IO.Path]::GetFileNameWithoutExtension($file.Name))
    $key = ConvertTo-NormalizedName $candidateName
    $matches_ = if ($indice.ContainsKey($key)) { @($indice[$key]) } else { @() }

    if ($matches_.Count -eq 1) {
        $dest = Move-OrSimulate $file.FullName (Join-Path $matches_[0].FullName $AsoFolderName) $file.Name $DryRun.IsPresent
        Write-Host "OK: '$($file.Name)' -> '$dest'" -ForegroundColor Green
        $st = if ($DryRun) { 'SIMULADO - OK' } else { 'MOVIDO' }; $motivo = ''
    }
    elseif ($matches_.Count -eq 0) {
        $dest = Move-OrSimulate $file.FullName $NaoEncontradoFolder $file.Name $DryRun.IsPresent
        Write-Host "NÃO ENCONTRADO: '$($file.Name)' (buscado: '$candidateName')" -ForegroundColor Red
        $st = 'NAO ENCONTRADO'; $motivo = 'Nenhuma pasta de colaborador com esse nome'
    }
    else {
        $dest = Move-OrSimulate $file.FullName $AmbiguoFolder $file.Name $DryRun.IsPresent
        Write-Host "AMBÍGUO: '$($file.Name)' bateu com $($matches_.Count) pastas" -ForegroundColor Magenta
        $st = 'AMBIGUO'; $motivo = 'Encontrado em múltiplas pastas: ' + (($matches_ | ForEach-Object FullName) -join ' | ')
    }
    [void]$logEntries.Add([pscustomobject]@{ Arquivo = $file.Name; NomeUsado = $candidateName; Status = $st; Destino = $dest; Motivo = $motivo })
}

if ($logEntries.Count -gt 0) {
    $logEntries | Export-Csv -Path $LogPath -Delimiter ';' -Encoding UTF8 -NoTypeInformation
}

# ------------------------- RELATÓRIO-RESUMO ACUMULATIVO -------------------
$total = $files.Count
$ok    = @($logEntries | Where-Object { $_.Status -match 'OK|MOVIDO' }).Count
$nao   = @($logEntries | Where-Object { $_.Status -eq 'NAO ENCONTRADO' }).Count
$amb   = @($logEntries | Where-Object { $_.Status -eq 'AMBIGUO' }).Count

[pscustomobject]@{
    DataHora           = Get-Date -Format 'yyyy-MM-dd HH:mm'
    ModoSimulacao      = $DryRun.IsPresent
    TotalProcessados   = $total
    Sucesso            = $ok
    NaoEncontrado      = $nao
    Ambiguo            = $amb
    PercentComProblema = if ($total -gt 0) { [math]::Round((($nao + $amb) / $total) * 100, 1) } else { 0 }
} | Export-Csv -Path $SummaryPath -Delimiter ';' -Encoding UTF8 -NoTypeInformation -Append

Write-Host ''
Write-Host '=========================================='
Write-Host ("Total: {0} | Sucesso: {1} | Não encontrado: {2} | Ambíguo: {3}" -f $total, $ok, $nao, $amb)
Write-Host "Resumo histórico: $SummaryPath"
if ($DryRun) { Write-Host 'MODO SIMULAÇÃO - nada foi movido.' -ForegroundColor Yellow }
