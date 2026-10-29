# =========================================================================
# Atualizar-PlanilhasOrigem.ps1
# O sistema de RH exporta relatórios com a data no nome
# ("Ativos - 22.07.2026.xlsx", "SSO - 22.07.26.xlsx"). O Power Query precisa
# de um caminho estável. Este script:
#   - encontra o arquivo MAIS RECENTE de cada tipo pela data do NOME
#     (não pela data de modificação, que muda ao abrir/copiar);
#   - Ativos: copia para um nome fixo ("Ativos atual.xlsx");
#   - SSO:    mantém o nome com data e remove a versão anterior.
# Resultado: o Power Query nunca aponta para arquivo velho e ninguém
# precisa renomear/copiar arquivos à mão.
#
# USO:  .\Atualizar-PlanilhasOrigem.ps1 -DryRun   (confere)
#       .\Atualizar-PlanilhasOrigem.ps1           (executa)
# Dados e caminhos deste repositório são FICTÍCIOS.
# =========================================================================
param(
    [string]$SourcePath = 'C:\Demo\Exportacoes_RH',
    [string]$DestPath   = 'C:\Demo\Exportacoes_RH\Atual',
    [switch]$DryRun
)

# Regras por tipo de arquivo: NomeFixoDestino vazio = mantém o nome com data
$Regras = @(
    [pscustomobject]@{ Prefixo = 'Ativos'; NomeFixoDestino = 'Ativos atual.xlsx' }
    [pscustomobject]@{ Prefixo = 'SSO';    NomeFixoDestino = '' }
)

$LogPath = Join-Path $DestPath ('Log_AtualizarPlanilhas_' + (Get-Date -Format 'yyyy-MM-dd_HHmmss') + '.csv')

function Get-DateFromFileName([string]$FileName) {
    # Aceita "22.07.2026" e "22.07.26"
    $m = [regex]::Match($FileName, '(\d{1,2})\.(\d{1,2})\.(\d{4}|\d{2})')
    if (-not $m.Success) { return $null }
    $ano = if ($m.Groups[3].Value.Length -eq 2) { 2000 + [int]$m.Groups[3].Value } else { [int]$m.Groups[3].Value }
    try { return Get-Date -Year $ano -Month ([int]$m.Groups[2].Value) -Day ([int]$m.Groups[1].Value) -Hour 0 -Minute 0 -Second 0 }
    catch { return $null }   # data inválida no nome (ex.: 31.02) é ignorada
}

foreach ($p in $SourcePath, $DestPath) {
    if (-not (Test-Path $p)) { Write-Host "ERRO: pasta não encontrada: $p" -ForegroundColor Red; exit 1 }
}

$log = New-Object System.Collections.ArrayList
$sourceFiles = @(Get-ChildItem -Path $SourcePath -File -Filter '*.xlsx')

foreach ($regra in $Regras) {
    $prefixo = $regra.Prefixo
    Write-Host "`nVerificando '$prefixo'..." -ForegroundColor Cyan

    $comData = @(foreach ($f in ($sourceFiles | Where-Object { $_.Name -match "^$prefixo\s*-" })) {
        $d = Get-DateFromFileName $f.Name
        if ($d) { [pscustomobject]@{ Arquivo = $f; Data = $d } }
    })

    if ($comData.Count -eq 0) {
        Write-Host "Nenhum '$prefixo - ...' com data reconhecível." -ForegroundColor Yellow
        [void]$log.Add([pscustomobject]@{ Prefixo = $prefixo; Status = 'NENHUM ENCONTRADO'; ArquivoOrigem = ''; Data = ''; Destino = '' })
        continue
    }

    $maisRecente = $comData | Sort-Object Data -Descending | Select-Object -First 1
    $origem = $maisRecente.Arquivo
    Write-Host ("Mais recente: '{0}' ({1:dd/MM/yyyy})" -f $origem.Name, $maisRecente.Data) -ForegroundColor Green

    if ($regra.NomeFixoDestino) {
        $destino = Join-Path $DestPath $regra.NomeFixoDestino
        if ($DryRun) { Write-Host "[SIMULAÇÃO] Copiaria -> '$destino'" -ForegroundColor Yellow }
        else { Copy-Item -Path $origem.FullName -Destination $destino -Force; Write-Host "OK: copiado -> '$destino'" -ForegroundColor Green }
        $st = if ($DryRun) { 'SIMULADO' } else { 'ATUALIZADO' }
    }
    else {
        $destino = Join-Path $DestPath $origem.Name
        foreach ($antigo in (Get-ChildItem -Path $DestPath -File -Filter '*.xlsx' | Where-Object { $_.Name -match "^$prefixo\s*-" -and $_.Name -ne $origem.Name })) {
            if ($DryRun) { Write-Host "[SIMULAÇÃO] Removeria versão antiga: '$($antigo.Name)'" -ForegroundColor Yellow }
            else { Remove-Item -Path $antigo.FullName -Force; Write-Host "Removida versão antiga: '$($antigo.Name)'" -ForegroundColor Green }
        }
        if (Test-Path $destino) { $st = 'JA ATUALIZADO'; Write-Host 'Versão mais recente já está no destino.' -ForegroundColor Green }
        else {
            if ($DryRun) { Write-Host "[SIMULAÇÃO] Copiaria -> '$destino'" -ForegroundColor Yellow }
            else { Copy-Item -Path $origem.FullName -Destination $destino -Force; Write-Host "OK: copiado -> '$destino'" -ForegroundColor Green }
            $st = if ($DryRun) { 'SIMULADO' } else { 'ATUALIZADO' }
        }
    }
    [void]$log.Add([pscustomobject]@{ Prefixo = $prefixo; Status = $st; ArquivoOrigem = $origem.Name; Data = $maisRecente.Data.ToString('dd/MM/yyyy'); Destino = $destino })
}

$log | Export-Csv -Path $LogPath -Delimiter ';' -Encoding UTF8 -NoTypeInformation
Write-Host "`nLog: $LogPath"
if ($DryRun) { Write-Host 'MODO SIMULAÇÃO - nada foi copiado ou apagado.' -ForegroundColor Yellow }
