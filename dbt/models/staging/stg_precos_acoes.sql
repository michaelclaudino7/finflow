{{
    config(
        materialized = 'view',
        description  = 'Preços de ações limpos e padronizados.'
    )
}}

with source as (
    select * from {{ source('raw', 'precos_acoes') }}
),

limpo as (
    select
        ticker,
        data::date                                  as data,

        -- Preços: nulos quando <= 0
        nullif(abertura,      0)::numeric(18,6)     as preco_abertura,
        nullif(maxima,        0)::numeric(18,6)     as preco_maxima,
        nullif(minima,        0)::numeric(18,6)     as preco_minima,
        nullif(fechamento,    0)::numeric(18,6)     as preco_fechamento,
        nullif(fechamento_aj, 0)::numeric(18,6)     as preco_ajustado,

        coalesce(volume, 0)::bigint                 as volume,
        fonte,
        carregado_em

    from source
    where fechamento_aj is not null
      and fechamento_aj > 0
      and data is not null
)

select * from limpo
