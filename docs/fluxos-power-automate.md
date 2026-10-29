# Fluxos de nuvem (Power Automate)

Os três fluxos usam apenas conectores padrão: Excel Online, SharePoint, Outlook e Teams. Nenhum exige licença premium. A lógica pesada fica em Office Scripts, chamados pelo conector Excel Online.

---

## 1. Lembretes de ASO – semanal

```mermaid
flowchart TD
    A[Recorrência semanal] --> B[Variáveis: modo teste, remetente,<br/>coordenação, Teams, log]
    B --> C[Listar modelos de mensagem<br/>tabela no Excel]
    C --> D[Listar base de colaboradores]
    D --> E{Base desatualizada?<br/>ATUALIZADO_EM não é de hoje}
    E -- sim --> F[E-mail de aviso ao responsável] --> G[Terminar sem enviar nada]
    E -- não --> H[Filtrar quem recebe e-mail]
    H --> I[Para cada colaborador:<br/>montar e enviar e-mail pelo modelo da faixa]
    I --> J[Filtrar urgentes]
    J --> K[Para cada urgente:<br/>criar chat no Teams, postar, registrar]
    K --> L[Montar log: faixas, urgentes, ocorrências]
    L --> M[Relatório HTML da execução<br/>enviado ao responsável]
```

| Decisão de projeto | Por quê |
|---|---|
| Modelos de mensagem numa tabela do Excel | O texto de cada faixa (vencido, vence em 30 dias…) muda sem editar o fluxo |
| Trava de base desatualizada | Se o refresh das 11 h falhar, ninguém recebe cobrança errada |
| Modo teste por variável | Valida mudanças mandando tudo só para o autor |
| Teams só para urgentes | Canal mais intrusivo reservado para os casos críticos, evitando fadiga de alerta |
| Relatório HTML ao final | Prova de execução: quantos e-mails saíram por faixa, quantos urgentes e quais ocorrências |

Histórico: execuções semanais com êxito, de 15 a 40 minutos cada, sem ninguém acompanhando.

---

## 2. Fluxo de desligamento

```mermaid
flowchart TD
    A[Novo e-mail de comunicado de desligamento] --> B[Extrair do assunto:<br/>nome do colaborador e data]
    B --> C[Office Script MoverDesligado<br/>localiza na base e move para Desligados]
    C --> D{Script retornou ALERTA?<br/>não achou / homônimo}
    D -- sim --> E[E-mail de alerta para tratamento manual] --> F[Terminar]
    D -- não --> G[Fim: movido sem intervenção]
```

O fluxo trata por e-mail cada desligamento comunicado, cerca de 5 por dia. Os casos ambíguos não são resolvidos no chute: viram alerta para tratamento manual.

---

## 3. Relatório de liberação

```mermaid
flowchart TD
    A[Arquivo criado na pasta de retorno<br/>SharePoint] --> B{Extensão .tsv?}
    B -- não --> Z[Ignora]
    B -- sim --> T
    subgraph T[Try]
        C[Ler conteúdo do arquivo] --> D[Data/hora da execução]
        D --> E[Office Script: interpreta o retorno do robô<br/>e monta o relatório]
        E --> F[E-mail do relatório para a equipe]
    end
    T -- falhou --> X
    subgraph X[Catch]
        G[E-mail de falha ao responsável]
    end
```

O robô local grava o resultado numa pasta sincronizada, e a nuvem assume dali. O padrão Try/Catch garante que uma falha nunca passe em silêncio.
