-- FinFlow: inicialização dos schemas
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS intermediate;
CREATE SCHEMA IF NOT EXISTS marts;

-- Tabela de preços brutos
CREATE TABLE IF NOT EXISTS raw.precos_acoes (
    id            SERIAL PRIMARY KEY,
    ticker        VARCHAR(20)    NOT NULL,
    data          DATE           NOT NULL,
    abertura      NUMERIC(18, 6),
    maxima        NUMERIC(18, 6),
    minima        NUMERIC(18, 6),
    fechamento    NUMERIC(18, 6),
    fechamento_aj NUMERIC(18, 6),
    volume        BIGINT,
    fonte         VARCHAR(50)    DEFAULT 'yahoo_finance',
    carregado_em  TIMESTAMP      DEFAULT NOW(),
    UNIQUE (ticker, data)
);

-- Tabela de indicadores macroeconômicos
CREATE TABLE IF NOT EXISTS raw.indicadores_macro (
    id           SERIAL PRIMARY KEY,
    data         DATE           NOT NULL,
    indicador    VARCHAR(50)    NOT NULL,
    valor        NUMERIC(18, 6) NOT NULL,
    unidade      VARCHAR(20),
    fonte        VARCHAR(50),
    carregado_em TIMESTAMP      DEFAULT NOW(),
    UNIQUE (data, indicador)
);

-- Tabela de metadados dos ativos
CREATE TABLE IF NOT EXISTS raw.ativos (
    id           SERIAL PRIMARY KEY,
    ticker       VARCHAR(20)    NOT NULL UNIQUE,
    nome         VARCHAR(200),
    setor        VARCHAR(100),
    subsetor     VARCHAR(100),
    tipo         VARCHAR(30),   -- ACAO, FII, ETF, INDICE
    pais         VARCHAR(50)    DEFAULT 'Brasil',
    moeda        VARCHAR(10)    DEFAULT 'BRL',
    ativo        BOOLEAN        DEFAULT TRUE,
    carregado_em TIMESTAMP      DEFAULT NOW()
);

-- Índices de performance
CREATE INDEX IF NOT EXISTS idx_precos_ticker_data ON raw.precos_acoes (ticker, data);
CREATE INDEX IF NOT EXISTS idx_indicadores_data ON raw.indicadores_macro (data, indicador);

-- Conceder permissões ao usuário finflow
GRANT ALL PRIVILEGES ON SCHEMA raw        TO finflow;
GRANT ALL PRIVILEGES ON SCHEMA staging    TO finflow;
GRANT ALL PRIVILEGES ON SCHEMA intermediate TO finflow;
GRANT ALL PRIVILEGES ON SCHEMA marts      TO finflow;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA raw TO finflow;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA raw TO finflow;
