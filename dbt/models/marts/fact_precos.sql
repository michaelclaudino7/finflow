{{
    config(
        materialized = 'table',
        description  = 'Fato principal: preços ajustados + retornos + indicadores macro por dia.',
        indexes = [
            {'columns': ['ticker', 'data'], 'unique': true},
            {'columns': ['data']},
            {'columns': ['ticker']},
        ]
    )
}}

with retornos as (
    select * from {{ ref('int_retornos_diarios') }}
),

macro as (
    select * from {{ ref('int_indicadores_pivot') }}
),

-- Benchmark (IBOVESPA) para cálculo de beta
benchmark as (
    select
        data,
        retorno_diario  as retorno_ibov,
        preco_ajustado  as ibov_pontos
    from {{ ref('int_retornos_diarios') }}
    where ticker = '^BVSP'
),

-- Volatilidade rolling (janela configurável via vars)
volatilidade as (
    select
        ticker,
        data,
        round(
            (stddev(retorno_diario) over (
                partition by ticker
                order by data
                rows between {{ var('janela_volatilidade') - 1 }} preceding and current row
            ) * sqrt(252))::numeric,
            6
        ) as volatilidade_anual,

        round(
            (avg(retorno_diario) over (
                partition by ticker
                order by data
                rows between {{ var('janela_volatilidade') - 1 }} preceding and current row
            ))::numeric,
            8
        ) as retorno_medio_janela
    from retornos
),

-- Beta rolling (~1 ano)
beta as (
    select
        r.ticker,
        r.data,
        round(
            (covar_pop(r.retorno_diario, b.retorno_ibov) over (
                partition by r.ticker
                order by r.data
                rows between {{ var('janela_beta') - 1 }} preceding and current row
            )
            /
            nullif(
                var_pop(b.retorno_ibov) over (
                    order by b.data
                    rows between {{ var('janela_beta') - 1 }} preceding and current row
                ),
                0
            ))::numeric,
            4
        ) as beta_ibov
    from retornos r
    join benchmark b on b.data = r.data
    where r.ticker != '^BVSP'
),

final as (
    select
        -- Chave surrogate
        {{ dbt_utils.generate_surrogate_key(['r.ticker', 'r.data']) }} as id,

        r.ticker,
        r.data,

        -- Preços
        r.preco_ajustado,
        r.preco_anterior,
        r.volume,

        -- Retornos
        r.retorno_diario,
        r.retorno_log,
        round((r.retorno_diario * 100)::numeric, 4) as retorno_diario_pct,

        -- Retorno acumulado desde o primeiro registro
        round(
            (exp(
                sum(r.retorno_log) over (
                    partition by r.ticker
                    order by r.data
                    rows between unbounded preceding and current row
                )
            ) - 1)::numeric,
            6
        ) as retorno_acumulado,

        -- Retorno YTD (início do ano)
        round(
            (exp(
                sum(r.retorno_log) over (
                    partition by r.ticker, extract(year from r.data)
                    order by r.data
                    rows between unbounded preceding and current row
                )
            ) - 1)::numeric,
            6
        ) as retorno_ytd,

        -- Métricas de risco
        v.volatilidade_anual,
        b.beta_ibov,

        -- Macro do dia
        m.selic_diaria,
        m.cdi_diario,
        m.usd_brl,
        m.ipca_mensal,
        m.selic_meta,

        -- Retorno real (descontando IPCA — aproximação mensal)
        case
            when m.ipca_mensal is not null and m.ipca_mensal != 0
            then round(
                ((1 + r.retorno_diario) / (1 + m.ipca_mensal / 100) - 1)::numeric,
                8
            )
        end as retorno_real_aprox,

        -- Excesso de retorno sobre o CDI
        case
            when m.cdi_diario is not null
            then round((r.retorno_diario - (m.cdi_diario / 100))::numeric, 8)
        end as excesso_retorno_cdi,

        -- Benchmarks
        bm.retorno_ibov,
        bm.ibov_pontos,

        r.dias_desde_anterior,
        now() as atualizado_em

    from retornos r
    left join volatilidade v on v.ticker = r.ticker and v.data = r.data
    left join beta         b on b.ticker = r.ticker and b.data = r.data
    left join macro        m on m.data   = r.data
    left join benchmark    bm on bm.data = r.data
)

select * from final
