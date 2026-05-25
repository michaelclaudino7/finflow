# 📊 FinFlow — Pipeline de Dados do Mercado Financeiro

![Python](https://img.shields.io/badge/Python-3.14-blue?logo=python)
![dbt](https://img.shields.io/badge/dbt-1.7-orange?logo=dbt)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-336791?logo=postgresql)
![Docker](https://img.shields.io/badge/Docker-compose-2496ED?logo=docker)

> Pipeline de dados end-to-end para análise do mercado financeiro brasileiro.
> Ingere cotações de ações, indicadores macroeconômicos (Selic, IPCA, CDI, câmbio) e calcula
> métricas de risco como Sharpe, Sortino, beta, VaR e drawdown máximo.

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────────┐
│  INGESTÃO (Python + Pydantic)                                   │
│  Yahoo Finance │ BCB API                                        │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  ARMAZENAMENTO (PostgreSQL — schema raw)                        │
│  precos_acoes │ indicadores_macro │ ativos                      │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  TRANSFORMAÇÃO (dbt)                                            │
│  staging → intermediate → marts                                 │
│                                                                 │
│  staging:      limpeza, tipagem, padronização                   │
│  intermediate: retornos diários, indicadores pivotados          │
│  marts:        fact_precos, dim_ativos, mart_risco,             │
│                mart_correlacao                                  │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  QUALIDADE (dbt tests)                                          │
│  57 testes automatizados de unicidade, not null e domínio       │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  ANÁLISE (SQL views + Jupyter)                                  │
│  retorno, volatilidade, beta, correlação, VaR                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

```bash
# 1. Clone e entre no projeto
git clone https://github.com/michaelclaudino7/Finflow.git
cd Finflow

# 2. Crie o ambiente virtual e instale as dependências
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 3. Configure as variáveis de ambiente
cp .env.example .env

# 4. Suba o banco de dados
docker compose up -d

# 5. Rode a ingestão completa
mkdir -p logs
python3 run_ingestion.py --full

# 6. Rode as transformações dbt
docker run --rm --network host \
  -v $(pwd)/dbt:/dbt \
  -e POSTGRES_HOST=localhost \
  -e POSTGRES_PORT=5432 \
  -e POSTGRES_USER=finflow \
  -e POSTGRES_PASSWORD=finflow123 \
  -e POSTGRES_DB=finflow \
  ghcr.io/dbt-labs/dbt-postgres:1.7.latest \
  run --profiles-dir /dbt --project-dir /dbt
```

Ou use o Makefile:

```bash
make up           # sobe PostgreSQL + Adminer
make ingest       # ingestão incremental
make ingest-full  # ingestão completa (desde 2019)
make dbt-run      # transforma com dbt
make dbt-test     # testa os 57 modelos dbt
make pipeline     # tudo: ingest + dbt-run + dbt-test
```

---

## 📦 Stack

| Camada | Tecnologia | Finalidade |
|---|---|---|
| Ingestão | Python + yfinance + requests | Coleta de dados das APIs |
| Validação | Pydantic v2 | Validação de schemas na entrada |
| Banco de dados | PostgreSQL 15 | Warehouse local |
| Containerização | Docker Compose | Ambiente reproduzível |
| Transformação | dbt-core 1.7 | Modelagem em camadas (staging/marts) |
| Qualidade | dbt tests | 57 testes automatizados |
| Análise | Jupyter + pandas + scipy | Exploração e visualização |

---

## 📐 Modelos dbt

### Staging
| Modelo | Descrição |
|---|---|
| `stg_precos_acoes` | Preços ajustados limpos e padronizados |
| `stg_indicadores_macro` | Selic, IPCA, CDI, câmbio categorizados |
| `stg_ativos` | Metadados de ativos com fallbacks |

### Intermediate
| Modelo | Descrição |
|---|---|
| `int_retornos_diarios` | Retorno simples e logarítmico por ativo |
| `int_indicadores_pivot` | Indicadores macro pivotados por data |

### Marts
| Modelo | Descrição |
|---|---|
| `fact_precos` | Fato principal: preços + retornos + beta + macro |
| `dim_ativos` | Dimensão de ativos com estatísticas históricas |
| `mart_risco` | Sharpe, Sortino, VaR 95/99%, drawdown por ano |
| `mart_correlacao` | Matriz de correlação entre pares de ativos |

---

## 📊 Métricas calculadas

- **Retorno simples e logarítmico** diário, acumulado e YTD
- **Volatilidade anualizada** (rolling 21 dias úteis)
- **Beta** em relação ao IBOVESPA (rolling 252 dias úteis)
- **Sharpe Ratio** anualizado (excesso sobre CDI)
- **Sortino Ratio** (penaliza apenas volatilidade negativa)
- **VaR histórico** 95% e 99%
- **Maximum Drawdown** por ano
- **Win Rate** (% de dias com retorno positivo)
- **Correlação de Pearson** entre todos os pares de ativos
- **Retorno real** (descontado pelo IPCA)

---

## 🧪 Qualidade de dados

O projeto utiliza dbt tests executados a cada `make dbt-test`:

- Unicidade de chaves primárias
- Valores não nulos em campos obrigatórios
- Validação de domínios (tipos de ativo, grupos macro)
- Checagem de consistência (preços positivos, correlações entre -1 e 1, drawdown negativo)

**57 testes — PASS=57 WARN=0 ERROR=0**

---

## 📁 Estrutura de pastas

```
finflow/
├── ingestion/              # Scripts Python de ingestão
│   ├── yahoo.py            # Yahoo Finance (yfinance)
│   ├── bcb.py              # BCB API
│   ├── models.py           # Schemas Pydantic
│   └── config.py           # Configurações centrais
├── dbt/
│   ├── models/
│   │   ├── staging/        # Limpeza e padronização
│   │   ├── intermediate/   # Cálculos intermediários
│   │   └── marts/          # Tabelas analíticas finais
│   ├── macros/             # Macros reutilizáveis
│   └── dbt_project.yml
├── expectations/           # Great Expectations (suites de validação)
├── notebooks/              # Análise exploratória
├── scripts/
│   └── init.sql            # Inicialização do banco
├── docker-compose.yml
├── Makefile
├── requirements.txt
└── .env.example
```

---

## ⚙️ Configuração

Copie `.env.example` para `.env` e preencha com suas credenciais:

```bash
cp .env.example .env
```

```env
POSTGRES_HOST=
POSTGRES_PORT=
POSTGRES_USER=
POSTGRES_PASSWORD=
POSTGRES_DB=

# Ativos monitorados (separados por vírgula)
TICKERS=

# Data inicial da carga histórica
DATA_INICIO=
```

O Adminer (interface web do banco) fica disponível em **http://localhost:8080** após o `docker compose up`.