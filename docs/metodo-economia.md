# Como a economia foi calculada

Economia mensal = volume do mês × tempo manual por item antes da automação.

| Automação | Volume | Tempo manual antes | Economia | Tipo do número |
|---|---|---|---|---|
| Robô de liberação + relatório | rotina diária | > 2 h/dia de um colaborador | ≥ 42 h/mês (21 dias úteis) | estimativa da equipe |
| Lembretes por e-mail + Teams | 1 envio/semana, 400+ pessoas | ~1 dia de trabalho por envio | ~35 h/mês | estimativa da equipe |
| Desligamentos | ~5/dia | ~12 min cada | ~21 h/mês | estimativa da equipe |
| Organização de PDFs | **365 PDFs arquivados em out/2026** | ~2–3 min por arquivo | ~12–18 h/mês | **volume medido** pelo log; tempo estimado |
| Conferência de novos funcionários | por lote | > 2 h/semana | ≥ 9 h/mês | estimativa da equipe |
| **Total** | | | **~120 h/mês** | |

## O que o log mostra (organização de PDFs, jul–out/2026)

O script grava uma linha de resumo por execução. Os totais por mês:

| Mês | Execuções | PDFs processados | Arquivados automaticamente | Separados para tratamento manual |
|---|---|---|---|---|
| jul/2026 (início) | 17 | 95 | 68 | 27 |
| ago/2026 | 23 | 357 | 262 | 95 |
| set/2026 | 15 | 577 | 256 | 321 |
| out/2026 (até dia 28) | 26 | 765 | 365 | 400 |

**O que esses números ensinaram:**
- **O volume mais que dobrou** de agosto para outubro (357 → 765 PDFs) sem nenhum aumento de esforço manual para os casos que casam direto.
- **Os casos separados para tratamento subiram** de ~27% para ~53% em set–out. O próprio relatório-resumo revelou o salto, e a investigação apontou a causa **na origem**: mais da metade eram PDFs salvos com o nome fora do padrão. O script não arquivou nenhum deles no lugar errado: separou todos para conferência. Monitorar a automação serviu para enxergar a falha humana antes da etapa seguinte.
- **Lição de projeto:** casar pelo nome digitado depende de disciplina humana. O próximo passo é identificar o PDF por CPF, uma chave estável.
- "Processados" pode contar duas vezes um arquivo que foi corrigido e devolvido à entrada. Por isso, a economia usa só os **arquivados automaticamente**.

Um detalhe técnico: no Windows PowerShell 5.1, `.Count` de um único objeto retorna vazio. O log original tinha células vazias onde o valor era 1. A versão publicada aqui usa `@(...)` e grava sempre o número.
