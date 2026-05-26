"""Configurações centrais do FinFlow."""

import os
from dotenv import load_dotenv

load_dotenv()

# Banco de dados
DB_HOST     = os.getenv("POSTGRES_HOST", "localhost")
DB_PORT     = int(os.getenv("POSTGRES_PORT", 5432))
DB_USER     = os.getenv("POSTGRES_USER", "finflow")
DB_PASSWORD = os.getenv("POSTGRES_PASSWORD", "finflow123")
DB_NAME     = os.getenv("POSTGRES_DB", "finflow")

DATABASE_URL = (
    f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}"
    f"@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

# Ativos monitorados
TICKERS_RAW = os.getenv(
    "TICKERS",
    "PETR4.SA,VALE3.SA,ITUB4.SA,BBDC4.SA,WEGE3.SA,ABEV3.SA,^BVSP"
)
TICKERS = [t.strip() for t in TICKERS_RAW.split(",")]

# Período
DATA_INICIO = os.getenv("DATA_INICIO", "2019-01-01")

# APIs externas
BCB_BASE_URL  = "https://api.bcb.gov.br/dados/serie/bcdata.sgs.{codigo}/dados"
IBGE_IPCA_URL = "https://servicodados.ibge.gov.br/api/v3/agregados/1737/periodos/{periodo}/variaveis/2266"

# Indicadores BCB (código da série)
BCB_SERIES = {
    "selic_meta":    432,   # Taxa Selic meta (% a.a.)
    "selic_diaria":  11,    # Taxa Selic diária (% a.d.)
    "usd_brl":       1,     # Taxa de câmbio USD/BRL (venda)
    "eur_brl":       21619, # Taxa de câmbio EUR/BRL
    "igpm":          189,   # IGP-M (% no mês)
    "cdi":           12,    # Taxa CDI diária
    "pib_mensal":    4380,  # PIB mensal (índice)
}

# Metadata dos ativos
ATIVOS_META = {
    "PETR4.SA": {"nome": "Petrobras PN",       "setor": "Energia",           "tipo": "ACAO"},
    "VALE3.SA": {"nome": "Vale ON",             "setor": "Mineração",         "tipo": "ACAO"},
    "ITUB4.SA": {"nome": "Itaú Unibanco PN",   "setor": "Financeiro",        "tipo": "ACAO"},
    "BBDC4.SA": {"nome": "Bradesco PN",         "setor": "Financeiro",        "tipo": "ACAO"},
    "WEGE3.SA": {"nome": "WEG ON",              "setor": "Bens Industriais",  "tipo": "ACAO"},
    "ABEV3.SA": {"nome": "Ambev ON",            "setor": "Consumo",           "tipo": "ACAO"},
    "MGLU3.SA": {"nome": "Magazine Luiza ON",   "setor": "Consumo",           "tipo": "ACAO"},
    "^BVSP":    {"nome": "IBOVESPA",            "setor": "Índice",            "tipo": "INDICE"},
}
