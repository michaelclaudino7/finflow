"""Modelos Pydantic para validação dos dados antes da carga."""

from datetime import date
from typing import Optional
from pydantic import BaseModel, Field, field_validator, model_validator


class PrecoAcao(BaseModel):
    """Representa um registro diário de preço de ação."""

    ticker:        str
    data:          date
    abertura:      Optional[float] = None
    maxima:        Optional[float] = None
    minima:        Optional[float] = None
    fechamento:    Optional[float] = None
    fechamento_aj: Optional[float] = None
    volume:        Optional[int]   = None
    fonte:         str = "yahoo_finance"

    @field_validator("ticker")
    @classmethod
    def ticker_nao_vazio(cls, v: str) -> str:
        v = v.strip().upper()
        if not v:
            raise ValueError("Ticker não pode ser vazio")
        return v

    @field_validator("fechamento", "fechamento_aj", "abertura", "maxima", "minima")
    @classmethod
    def preco_positivo(cls, v: Optional[float]) -> Optional[float]:
        if v is not None and v <= 0:
            raise ValueError("Preço deve ser positivo")
        return v

    @model_validator(mode="after")
    def maxima_maior_que_minima(self) -> "PrecoAcao":
        if self.maxima is not None and self.minima is not None:
            if self.maxima < self.minima:
                raise ValueError(f"Máxima ({self.maxima}) menor que mínima ({self.minima})")
        return self


class IndicadorMacro(BaseModel):
    """Representa um indicador macroeconômico diário ou mensal."""

    data:       date
    indicador:  str
    valor:      float
    unidade:    str   = "%"
    fonte:      str   = "bcb"

    @field_validator("indicador")
    @classmethod
    def indicador_valido(cls, v: str) -> str:
        v = v.strip().lower()
        if not v:
            raise ValueError("Indicador não pode ser vazio")
        return v


class Ativo(BaseModel):
    """Metadados de um ativo financeiro."""

    ticker:   str
    nome:     Optional[str] = None
    setor:    Optional[str] = None
    subsetor: Optional[str] = None
    tipo:     str = Field(pattern="^(ACAO|FII|ETF|INDICE)$")
    pais:     str = "Brasil"
    moeda:    str = "BRL"
    ativo:    bool = True

    @field_validator("ticker")
    @classmethod
    def normaliza_ticker(cls, v: str) -> str:
        return v.strip().upper()
