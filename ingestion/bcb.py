"""Ingestão de indicadores macroeconômicos via API do Banco Central e IBGE."""

from datetime import date
from typing import List

import requests
from loguru import logger
from pydantic import ValidationError
from tenacity import retry, stop_after_attempt, wait_exponential

from ingestion.config import BCB_BASE_URL, BCB_SERIES, DATA_INICIO
from ingestion.models import IndicadorMacro


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
def _get_serie_bcb(codigo: int, inicio: str, fim: str) -> list:
    """Busca uma série temporal do BCB."""
    url = BCB_BASE_URL.format(codigo=codigo)
    params = {
        "formato":       "json",
        "dataInicial":   _to_bcb_date(inicio),
        "dataFinal":     _to_bcb_date(fim),
    }
    resp = requests.get(url, params=params, timeout=30)
    resp.raise_for_status()
    return resp.json()


def _to_bcb_date(d: str) -> str:
    """Converte YYYY-MM-DD para DD/MM/YYYY (formato BCB)."""
    parts = d.split("-")
    return f"{parts[2]}/{parts[1]}/{parts[0]}"


def _parse_bcb_date(d: str) -> date:
    """Converte DD/MM/YYYY para date."""
    parts = d.split("/")
    return date(int(parts[2]), int(parts[1]), int(parts[0]))


def fetch_indicadores(
    inicio: str = None,
    fim:    str = None,
) -> List[IndicadorMacro]:
    """Busca todos os indicadores macro configurados.

    Args:
        inicio: data inicial YYYY-MM-DD.
        fim:    data final YYYY-MM-DD (hoje se None).
    """
    inicio = inicio or DATA_INICIO
    fim    = fim    or date.today().isoformat()

    unidades = {
        "selic_meta":   "% a.a.",
        "selic_diaria": "% a.d.",
        "usd_brl":      "BRL",
        "eur_brl":      "BRL",
        "igpm":         "% mês",
        "cdi":          "% a.d.",
        "pib_mensal":   "índice",
    }

    todos: List[IndicadorMacro] = []

    for nome, codigo in BCB_SERIES.items():
        logger.info(f"Buscando série BCB: {nome} (código {codigo})...")
        try:
            dados = _get_serie_bcb(codigo, inicio, fim)
            for item in dados:
                try:
                    rec = IndicadorMacro(
                        data      = _parse_bcb_date(item["data"]),
                        indicador = nome,
                        valor     = float(item["valor"].replace(",", ".")) if isinstance(item["valor"], str) else float(item["valor"]),
                        unidade   = unidades.get(nome, "%"),
                        fonte     = "bcb",
                    )
                    todos.append(rec)
                except (ValidationError, ValueError, KeyError) as exc:
                    logger.warning(f"Registro inválido ({nome}): {exc}")

            logger.success(f"{nome}: {len(dados)} registros coletados.")
        except Exception as exc:
            logger.error(f"Falha ao buscar série {nome} ({codigo}): {exc}")

    # IPCA via IBGE
    todos.extend(_fetch_ipca(inicio, fim))

    logger.info(f"Total de indicadores macro coletados: {len(todos)}")
    return todos


def _fetch_ipca(inicio: str, fim: str) -> List[IndicadorMacro]:
    """Busca IPCA mensal via IBGE."""
    # Converte datas para o formato YYYYMM
    ano_ini, mes_ini, _ = inicio.split("-")
    ano_fim, mes_fim, _ = fim.split("-")
    periodo = f"{ano_ini}{mes_ini}|{ano_fim}{mes_fim}"

    url = f"https://servicodados.ibge.gov.br/api/v3/agregados/1737/periodos/{periodo}/variaveis/2266"
    params = {"localidades": "N1[all]"}

    registros = []
    try:
        resp = requests.get(url, params=params, timeout=30)
        resp.raise_for_status()
        data = resp.json()

        for var in data:
            for resultado in var.get("resultados", []):
                for periodo_str, valor in resultado.get("series", [{}])[0].get("serie", {}).items():
                    try:
                        ano  = int(periodo_str[:4])
                        mes  = int(periodo_str[4:])
                        rec  = IndicadorMacro(
                            data      = date(ano, mes, 1),
                            indicador = "ipca",
                            valor     = float(valor),
                            unidade   = "% mês",
                            fonte     = "ibge",
                        )
                        registros.append(rec)
                    except Exception as exc:
                        logger.warning(f"IPCA registro inválido ({periodo_str}): {exc}")

        logger.success(f"IPCA: {len(registros)} registros coletados.")
    except Exception as exc:
        logger.error(f"Falha ao buscar IPCA: {exc}")

    return registros
