"""Ingestão de preços históricos via Yahoo Finance (yfinance)."""

from datetime import date, timedelta
from typing import List

import yfinance as yf
from loguru import logger
from pydantic import ValidationError
from tenacity import retry, stop_after_attempt, wait_exponential

from ingestion.config import TICKERS, DATA_INICIO, ATIVOS_META
from ingestion.models import PrecoAcao, Ativo


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
def _fetch_ticker(ticker: str, inicio: str, fim: str) -> list:
    """Baixa dados de um ticker com retry automático."""
    logger.info(f"Buscando {ticker} de {inicio} até {fim}...")
    t = yf.Ticker(ticker)
    df = t.history(start=inicio, end=fim, auto_adjust=False)

    if df.empty:
        logger.warning(f"Nenhum dado retornado para {ticker}.")
        return []

    df = df.reset_index()
    df.columns = [c.lower().replace(" ", "_") for c in df.columns]

    registros = []
    for _, row in df.iterrows():
        try:
            rec = PrecoAcao(
                ticker        = ticker,
                data          = row["date"].date() if hasattr(row["date"], "date") else row["date"],
                abertura      = float(row.get("open",  0)) or None,
                maxima        = float(row.get("high",  0)) or None,
                minima        = float(row.get("low",   0)) or None,
                fechamento    = float(row.get("close", 0)) or None,
                fechamento_aj = float(row.get("adj_close", row.get("close", 0))) or None,
                volume        = int(row.get("volume", 0)) or None,
            )
            registros.append(rec)
        except ValidationError as exc:
            logger.warning(f"Registro inválido ({ticker} {row.get('date')}): {exc}")

    logger.success(f"{ticker}: {len(registros)} registros válidos.")
    return registros


def fetch_precos(
    tickers: List[str] = None,
    inicio:  str       = None,
    fim:     str       = None,
) -> List[PrecoAcao]:
    """Busca preços de múltiplos tickers.

    Args:
        tickers: lista de tickers; usa TICKERS do config se None.
        inicio:  data inicial (YYYY-MM-DD); usa DATA_INICIO do config se None.
        fim:     data final (YYYY-MM-DD); usa hoje se None.
    """
    tickers = tickers or TICKERS
    inicio  = inicio  or DATA_INICIO
    fim     = fim     or date.today().isoformat()

    todos = []
    for ticker in tickers:
        try:
            todos.extend(_fetch_ticker(ticker, inicio, fim))
        except Exception as exc:
            logger.error(f"Falha ao buscar {ticker}: {exc}")

    logger.info(f"Total de registros de preços coletados: {len(todos)}")
    return todos


def fetch_ativos_meta() -> List[Ativo]:
    """Constrói a lista de metadados dos ativos a partir do config e do Yahoo."""
    ativos = []
    for ticker, meta in ATIVOS_META.items():
        try:
            t = yf.Ticker(ticker)
            info = t.info or {}
            ativo = Ativo(
                ticker   = ticker,
                nome     = meta.get("nome") or info.get("longName", ticker),
                setor    = meta.get("setor") or info.get("sector"),
                subsetor = info.get("industry"),
                tipo     = meta.get("tipo", "ACAO"),
                moeda    = info.get("currency", "BRL"),
            )
            ativos.append(ativo)
            logger.info(f"Metadados carregados: {ticker}")
        except Exception as exc:
            logger.warning(f"Não foi possível obter metadados de {ticker}: {exc}")
            # Fallback mínimo
            ativos.append(Ativo(ticker=ticker, **{k: v for k, v in meta.items()}))

    return ativos
