{{
    config(
        materialized = 'table',
        description  = 'Métricas de risco consolidadas por ativo: Sharpe, Sortino, VaR, drawdown.'
    )
}}

with fact as (
    select * from {{ ref('fact_precos') }}
    where ticker != '^BVSP'
),

drawdown as (
    select
        ticker,
        data,
        preco_ajustado,
        retorno_acumulado,
        max(preco_ajustado) over (
            partition by ticker
            order by data
            rows between unbounded preceding and current row
        ) as pico_historico,
        round(
            ((preco_ajustado - max(preco_ajustado) over (
                partition by ticker
                order by data
                rows between unbounded preceding and current row
            )) / nullif(max(preco_ajustado) over (
                partition by ticker
                order by data
                rows between unbounded preceding and current row
            ), 0))::numeric,
            6
        ) as drawdown_corrente
    from fact
),

retornos_negativos as (
    select
        ticker,
        data,
        retorno_diario,
        case when retorno_diario < 0 then retorno_diario else 0 end as retorno_negativo
    from fact
),

metricas_anuais as (
    select
        ticker,
        extract(year from data)::int                               as ano,
        count(*)                                                   as pregoes,
        round(sum(retorno_diario)::numeric, 6)                     as retorno_anual,
        round((exp(sum(retorno_log)) - 1)::numeric, 6)             as retorno_anual_comp,
        round((stddev(retorno_diario) * sqrt(252))::numeric, 6)    as volatilidade_anual,
        round((avg(retorno_diario) * 252)::numeric, 6)             as retorno_medio_anual,
        round(
            ((avg(retorno_diario) * 252 - avg(coalesce(cdi_diario, 0) / 100) * 252)
            / nullif(stddev(retorno_diario) * sqrt(252), 0))::numeric,
            4
        ) as sharpe_ratio,
        round(
            (percentile_cont(0.05) within group (order by retorno_diario))::numeric,
            6
        ) as var_95,
        round(
            (percentile_cont(0.01) within group (order by retorno_diario))::numeric,
            6
        ) as var_99,
        sum(case when retorno_diario > 0 then 1 else 0 end)        as dias_positivos,
        sum(case when retorno_diario < 0 then 1 else 0 end)        as dias_negativos,
        round(avg(beta_ibov)::numeric, 4)                          as beta_medio
    from fact
    group by 1, 2
),

sortino as (
    select
        r.ticker,
        extract(year from r.data)::int as ano,
        round(
            ((avg(r.retorno_diario) * 252)
            / nullif(sqrt(sum(r.retorno_negativo ^ 2) / nullif(count(*) - 1, 0)) * sqrt(252), 0))::numeric,
            4
        ) as sortino_ratio
    from retornos_negativos r
    group by 1, 2
),

max_drawdown as (
    select
        ticker,
        extract(year from data)::int as ano,
        round(min(drawdown_corrente)::numeric, 6) as max_drawdown
    from drawdown
    group by 1, 2
)

select
    {{ dbt_utils.generate_surrogate_key(['m.ticker', 'm.ano::text']) }} as id,
    m.ticker,
    m.ano,
    m.pregoes,
    round((m.retorno_anual_comp * 100)::numeric, 2)   as retorno_anual_pct,
    round((m.volatilidade_anual * 100)::numeric, 2)   as volatilidade_pct,
    m.sharpe_ratio,
    s.sortino_ratio,
    m.beta_medio,
    round((m.var_95 * 100)::numeric, 4)               as var_95_pct,
    round((m.var_99 * 100)::numeric, 4)               as var_99_pct,
    round((md.max_drawdown * 100)::numeric, 4)        as max_drawdown_pct,
    m.dias_positivos,
    m.dias_negativos,
    m.pregoes                                         as total_pregoes,
    round(
        m.dias_positivos::numeric / nullif(m.pregoes, 0) * 100, 2
    )                                                 as win_rate_pct,
    case
        when m.sharpe_ratio >= 1   then 'excelente'
        when m.sharpe_ratio >= 0.5 then 'bom'
        when m.sharpe_ratio >= 0   then 'neutro'
        else 'negativo'
    end as classificacao_sharpe,
    now() as atualizado_em
from metricas_anuais m
left join sortino      s  on s.ticker  = m.ticker  and s.ano  = m.ano
left join max_drawdown md on md.ticker = m.ticker  and md.ano = m.ano
