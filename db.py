"""Helpers de banco de dados: conexão e carga."""

from contextlib import contextmanager
from typing import List

import pandas as pd
from loguru import logger
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

from ingestion.config import DATABASE_URL
from ingestion.models import PrecoAcao, IndicadorMacro, Ativo


_engine = None


def get_engine():
    global _engine
    if _engine is None:
        _engine = create_engine(DATABASE_URL, pool_pre_ping=True)
    return _engine


@contextmanager
def get_connection():
    conn = get_engine().connect()
    try:
        yield conn
        conn.commit()
    except SQLAlchemyError as exc:
        conn.rollback()
        raise exc
    finally:
        conn.close()


# ─── Carga de preços ──────────────────────────────────────────────────────────

def upsert_precos(registros: List[PrecoAcao]) -> int:
    """Insere/atualiza preços na tabela raw.precos_acoes."""
    if not registros:
        return 0

    rows = [r.model_dump() for r in registros]
    df = pd.DataFrame(rows)

    sql = text("""
        INSERT INTO raw.precos_acoes
            (ticker, data, abertura, maxima, minima, fechamento, fechamento_aj, volume, fonte)
        VALUES
            (:ticker, :data, :abertura, :maxima, :minima, :fechamento, :fechamento_aj, :volume, :fonte)
        ON CONFLICT (ticker, data) DO UPDATE SET
            abertura      = EXCLUDED.abertura,
            maxima        = EXCLUDED.maxima,
            minima        = EXCLUDED.minima,
            fechamento    = EXCLUDED.fechamento,
            fechamento_aj = EXCLUDED.fechamento_aj,
            volume        = EXCLUDED.volume,
            carregado_em  = NOW()
    """)

    with get_connection() as conn:
        conn.execute(sql, rows)

    logger.info(f"Upsert de {len(rows)} registros de preços concluído.")
    return len(rows)


# ─── Carga de indicadores ─────────────────────────────────────────────────────

def upsert_indicadores(registros: List[IndicadorMacro]) -> int:
    """Insere/atualiza indicadores na tabela raw.indicadores_macro."""
    if not registros:
        return 0

    rows = [r.model_dump() for r in registros]

    sql = text("""
        INSERT INTO raw.indicadores_macro (data, indicador, valor, unidade, fonte)
        VALUES (:data, :indicador, :valor, :unidade, :fonte)
        ON CONFLICT (data, indicador) DO UPDATE SET
            valor        = EXCLUDED.valor,
            carregado_em = NOW()
    """)

    with get_connection() as conn:
        conn.execute(sql, rows)

    logger.info(f"Upsert de {len(rows)} indicadores macro concluído.")
    return len(rows)


# ─── Carga de ativos ──────────────────────────────────────────────────────────

def upsert_ativos(registros: List[Ativo]) -> int:
    """Insere/atualiza metadados de ativos."""
    if not registros:
        return 0

    rows = [r.model_dump() for r in registros]

    sql = text("""
        INSERT INTO raw.ativos (ticker, nome, setor, subsetor, tipo, pais, moeda, ativo)
        VALUES (:ticker, :nome, :setor, :subsetor, :tipo, :pais, :moeda, :ativo)
        ON CONFLICT (ticker) DO UPDATE SET
            nome         = EXCLUDED.nome,
            setor        = EXCLUDED.setor,
            subsetor     = EXCLUDED.subsetor,
            tipo         = EXCLUDED.tipo,
            ativo        = EXCLUDED.ativo,
            carregado_em = NOW()
    """)

    with get_connection() as conn:
        conn.execute(sql, rows)

    logger.info(f"Upsert de {len(rows)} ativos concluído.")
    return len(rows)


def ultima_data_ticker(ticker: str) -> str:
    """Retorna a última data disponível para um ticker (para carga incremental)."""
    sql = text(
        "SELECT MAX(data)::text FROM raw.precos_acoes WHERE ticker = :ticker"
    )
    with get_connection() as conn:
        result = conn.execute(sql, {"ticker": ticker}).scalar()
    return result or "2019-01-01"
