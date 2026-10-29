# =====================================================================
#  Atualizar-BaseLembretes.ps1
#  Atualiza o Power Query da planilha-base dos lembretes de ASO
#  ANTES do fluxo de nuvem "Lembretes de ASO - semanal".
#
#  Por que existe: o conector Excel Online do Power Automate NÃO executa
#  Power Query. Sem este passo, o fluxo leria a base desatualizada.
#
#  Garantias:
#   - Só salva se a tabela não vier vazia E se o carimbo ATUALIZADO_EM mudou
#     (prova de que o refresh realmente rodou).
#   - Se falhar, NÃO salva: o carimbo fica antigo e o fluxo de nuvem
#     cancela o envio sozinho (nenhum e-mail com base velha).
#   - Grava uma linha de log (CSV) por execução, com sucesso ou erro.
#
#  Agendamento: Agendador de Tarefas do Windows, 1 h antes do fluxo.
#  Dados e caminhos deste repositório são FICTÍCIOS.
#  Salvar em UTF-8 com BOM (acentos).
# =====================================================================
param(
    [string]$Arquivo       = 'C:\Demo\Controle-ASOs\Base_Envio_Lembretes.xlsx',
    [string]$PastaLog      = 'C:\Demo\Logs',
    [string]$TabelaBase    = 'tblBase',        # tabela lida pelo fluxo
    [int]   $MinLinhas     = 1,                # abaixo disso = falha
    [string]$ColunaCarimbo = 'ATUALIZADO_EM'   # coluna gerada pelo Power Query (DateTime.LocalNow)
)

$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Path $PastaLog -Force | Out-Null
$LogCsv = Join-Path $PastaLog 'log_atualizacao_base_lembretes.csv'

$inicio = Get-Date
$status = 'ERRO'
$msg    = ''
$linhas = $null
$excel  = $null
$wb     = $null
$lo     = $null

function Liberar($obj) {
    if ($null -ne $obj) {
        try { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) } catch {}
    }
}

function Ler-Carimbo($tabela) {
    try {
        $col = $tabela.ListColumns.Item($ColunaCarimbo)
        if ($null -eq $col.DataBodyRange) { return $null }
        return $col.DataBodyRange.Cells.Item(1, 1).Value2
    } catch { throw "Coluna '$ColunaCarimbo' não encontrada na '$TabelaBase'." }
}

try {
    if (-not (Test-Path -LiteralPath $Arquivo)) { throw "Arquivo não encontrado: $Arquivo" }

    # Instância NOVA e invisível do Excel (não interfere no Excel aberto pelo usuário)
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible          = $false
    $excel.DisplayAlerts    = $false
    $excel.AskToUpdateLinks = $false

    $wb = $excel.Workbooks.Open($Arquivo, 0, $false)
    if ($wb.ReadOnly) { throw 'Arquivo abriu como SOMENTE LEITURA (aberto em outra instância). Nada foi atualizado.' }

    foreach ($ws in $wb.Worksheets) {
        foreach ($t in $ws.ListObjects) { if ($t.Name -eq $TabelaBase) { $lo = $t } }
    }
    if ($null -eq $lo) { throw "Tabela '$TabelaBase' não encontrada." }

    $carimboAntes = Ler-Carimbo $lo

    # Atualiza CADA conexão de forma síncrona
    $qtdConexoes = 0
    foreach ($c in $wb.Connections) {
        try { if ($c.Type -eq 1) { $c.OLEDBConnection.BackgroundQuery = $false } } catch {}
        $c.Refresh()
        $qtdConexoes++
    }
    $excel.CalculateUntilAsyncQueriesDone()
    if ($qtdConexoes -eq 0) { throw 'Nenhuma conexão/consulta encontrada no arquivo.' }

    # Validação 1: a tabela não veio vazia
    $linhas = $lo.ListRows.Count
    if ($linhas -lt $MinLinhas) { throw "Tabela '$TabelaBase' ficou com $linhas linha(s). Arquivo NÃO foi salvo." }

    # Validação 2: o carimbo mudou (o refresh aconteceu de fato)
    $carimboDepois = Ler-Carimbo $lo
    if ($null -eq $carimboDepois -or $carimboDepois -eq $carimboAntes) {
        throw "Refresh não alterou '$ColunaCarimbo' (antes=$carimboAntes, depois=$carimboDepois). Arquivo NÃO foi salvo."
    }

    $wb.Save()
    try { $carimboTexto = [DateTime]::FromOADate([double]$carimboDepois).ToString('dd/MM/yyyy HH:mm') } catch { $carimboTexto = "$carimboDepois" }
    $status = 'OK'
    $msg    = "Atualizado e salvo. $ColunaCarimbo=$carimboTexto | $qtdConexoes conexão(ões)"
}
catch {
    $msg = $_.Exception.Message
}
finally {
    if ($null -ne $wb)    { try { $wb.Close($false) } catch {} }
    if ($null -ne $excel) { try { $excel.Quit() }     catch {} }
    Liberar $lo; Liberar $wb; Liberar $excel
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()

    [pscustomobject]@{
        Inicio     = $inicio.ToString('yyyy-MM-dd HH:mm:ss')
        Fim        = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Status     = $status
        LinhasBase = $linhas
        Mensagem   = $msg
    } | Export-Csv -LiteralPath $LogCsv -Append -NoTypeInformation -Encoding UTF8 -Delimiter ';'
}

# Código de saída: o Agendador de Tarefas registra 0 = sucesso, 1 = falha
if ($status -ne 'OK') { exit 1 } else { exit 0 }
