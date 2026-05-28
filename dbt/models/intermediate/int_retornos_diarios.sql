{{
    config(
        materialized = 'ephemeral',
        description  = 'Retornos diários calculados por ticker com lag.'
    )
}}

with precos as (
    select * from {{ ref('stg_precos_acoes') }}
),

com_lag as (
    select
        ticker,
        data,
        preco_ajustado,
        volume,

        -- Preço do dia anterior (dentro do mesmo ticker)
        lag(preco_ajustado) over (
            partition by ticker
            order by data
        ) as preco_anterior,

        -- Número de dias corridos desde o pregão anterior (gap check)
        data - lag(data) over (
            partition by ticker
            order by data
        ) as dias_desde_anterior

    from precos
),

retornos as (
    select
        ticker,
        data,
        preco_ajustado,
        preco_anterior,
        volume,
        dias_desde_anterior,

        -- Retorno simples diário
        case
            when preco_anterior > 0
            then round(
                (preco_ajustado - preco_anterior) / preco_anterior,
                8
            )
        end as retorno_diario,

        -- Retorno logarítmico (melhor para séries longas)
        case
            when preco_anterior > 0
            then round(
                ln(preco_ajustado / preco_anterior),
                8
            )
        end as retorno_log

    from com_lag
    -- Remove o primeiro registro de cada série (sem preço anterior)
    where preco_anterior is not null
)

select * from retornos
