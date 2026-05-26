#!/usr/bin/env python
"""Pipeline principal de ingestão do FinFlow.

Uso:
    python run_ingestion.py              # ingestão completa (incremental)
    python run_ingestion.py --full       # recarga desde DATA_INICIO
    python run_ingestion.py --only precos
    python run_ingestion.py --only macro
    python run_ingestion.py --only ativos
"""

import argparse
import sys
from datetime import date

from loguru import logger

from ingestion.yahoo import fetch_precos, fetch_ativos_meta
from ingestion.bcb import fetch_indicadores
from db import upsert_precos, upsert_indicadores, upsert_ativos, ultima_data_ticker
from ingestion.config import TICKERS, DATA_INICIO


def setup_logging():
    logger.remove()
    logger.add(
        sys.stderr,
        format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | {message}",
        level="INFO",
    )
    logger.add(
        "logs/ingestion_{time:YYYY-MM-DD}.log",
        rotation="1 day",
        retention="30 days",
        level="DEBUG",
    )


def run_ativos():
    logger.info("=== Carregando metadados dos ativos ===")
    ativos = fetch_ativos_meta()
    total  = upsert_ativos(ativos)
    logger.success(f"Ativos: {total} registros carregados.")


def run_precos(inicio: str = None):
    logger.info("=== Carregando preços de ações ===")
    todos = []
    for ticker in TICKERS:
        inicio_ticker = inicio or ultima_data_ticker(ticker)
        precos = fetch_precos(tickers=[ticker], inicio=inicio_ticker)
        todos.extend(precos)

    total = upsert_precos(todos)
    logger.success(f"Preços: {total} registros carregados.")


def run_macro(inicio: str = None):
    logger.info("=== Carregando indicadores macro ===")
    indicadores = fetch_indicadores(inicio=inicio)
    total       = upsert_indicadores(indicadores)
    logger.success(f"Macro: {total} registros carregados.")


def main():
    setup_logging()

    parser = argparse.ArgumentParser(description="Pipeline de ingestão FinFlow")
    parser.add_argument(
        "--full", action="store_true",
        help="Recarga completa a partir de DATA_INICIO"
    )
    parser.add_argument(
        "--only", choices=["precos", "macro", "ativos"],
        help="Executa apenas uma etapa"
    )
    args = parser.parse_args()

    inicio = DATA_INICIO if args.full else None

    logger.info(f"FinFlow — ingestão iniciada em {date.today()}")
    logger.info(f"Modo: {'completo' if args.full else 'incremental'}")

    try:
        if args.only == "precos":
            run_precos(inicio)
        elif args.only == "macro":
            run_macro(inicio)
        elif args.only == "ativos":
            run_ativos()
        else:
            run_ativos()
            run_precos(inicio)
            run_macro(inicio)

        logger.success("Pipeline de ingestão concluído com sucesso!")

    except Exception as exc:
        logger.exception(f"Erro na pipeline: {exc}")
        sys.exit(1)


if __name__ == "__main__":
    main()
