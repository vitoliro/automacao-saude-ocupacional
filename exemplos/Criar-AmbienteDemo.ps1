# =========================================================================
# Criar-AmbienteDemo.ps1
# Cria em C:\Demo um ambiente 100% fictício para testar os scripts:
#   - pastas de colaboradores (Empresa Alfa / Empresa Beta)
#   - PDFs "vazios" na pasta de entrada, incluindo casos de erro de propósito
#   - exportações do RH com data no nome
# Nenhum dado real. Pode apagar C:\Demo depois.
# =========================================================================
param([string]$Raiz = 'C:\Demo')

$colab   = Join-Path $Raiz 'Colaboradores'
$entrada = Join-Path $Raiz 'ASOs_Entrada'
$export  = Join-Path $Raiz 'Exportacoes_RH'
New-Item -ItemType Directory -Force -Path $colab, $entrada, $export, (Join-Path $export 'Atual') | Out-Null

$pessoas = @(
    @{ Empresa = 'EMPRESA ALFA'; Nome = 'ANA EXEMPLO SOUZA' }
    @{ Empresa = 'EMPRESA ALFA'; Nome = 'BRUNO FICTICIO LIMA' }
    @{ Empresa = 'EMPRESA ALFA'; Nome = 'JOÃO TESTE PEREIRA' }
    @{ Empresa = 'EMPRESA BETA'; Nome = 'CARLA DEMO ROCHA' }
    @{ Empresa = 'EMPRESA BETA'; Nome = 'DIEGO AMOSTRA COSTA' }
    @{ Empresa = 'EMPRESA BETA'; Nome = 'JOÃO TESTE PEREIRA' }   # homônimo proposital -> _AMBIGUO
)
foreach ($p in $pessoas) { New-Item -ItemType Directory -Force -Path (Join-Path (Join-Path $colab $p.Empresa) $p.Nome) | Out-Null }

$pdfs = @(
    'ANA EXEMPLO SOUZA - 2026 - PERIODICO.pdf'   # OK
    'Bruno_Ficticio_Lima.pdf'                    # OK (normaliza "_" e maiúsculas)
    'carla demo rocha (1).pdf'                   # OK (ignora "(1)")
    'DIEGO AMOSTRA COSTA - ADMISSIONAL.pdf'      # OK
    'JOAO TESTE PEREIRA - 2026.pdf'              # AMBÍGUO (sem acento, 2 pastas)
    'FULANO INEXISTENTE.pdf'                     # NÃO ENCONTRADO
)
foreach ($n in $pdfs) { Set-Content -Path (Join-Path $entrada $n) -Value '%PDF-1.4 demo' }

foreach ($n in 'Ativos - 01.10.2026.xlsx', 'Ativos - 15.10.26.xlsx', 'SSO - 01.10.2026.xlsx', 'SSO - 20.10.2026.xlsx') {
    Set-Content -Path (Join-Path $export $n) -Value 'demo'
}
Write-Host "Ambiente fictício criado em $Raiz" -ForegroundColor Green
Write-Host 'Teste: .\scripts\Organizar-ASOs.ps1 -DryRun  e depois  .\scripts\Atualizar-PlanilhasOrigem.ps1 -DryRun'
