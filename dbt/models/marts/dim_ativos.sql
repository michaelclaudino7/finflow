{{
    config(
        materialized = 'table',
        description  = 'Dimensão de ativos com estatísticas enriquecidas.'
    )
}}

with ativos as (
    select * from {{ ref('stg_ativos') }}
),

stats as (
    select
        ticker,
        count(*)                                    as total_pregoes,
        min(data)                                   as primeira_data,
        max(data)                                   as ultima_data,
        round(avg(preco_ajustado)::numeric, 2)      as preco_medio,
        round(min(preco_ajustado)::numeric, 2)      as preco_minimo,
        round(max(preco_ajustado)::numeric, 2)      as preco_maximo,
        round(avg(volume)::numeric, 0)              as volume_medio_diario,
        round(
            sum(retorno_diario * retorno_diario) /
            nullif(count(retorno_diario) - 1, 0),
            8
        )                                           as variancia_diaria
    from {{ ref('fact_precos') }}
    group by 1
),

-- Preço mais recente
ultimo_preco as (
    select distinct on (ticker)
        ticker,
        data              as ultima_data_preco,
        preco_ajustado    as preco_atual,
        retorno_acumulado as retorno_acumulado_total,
        retorno_ytd,
        volatilidade_anual,
        beta_ibov
    from {{ ref('fact_precos') }}
    order by ticker, data desc
)

select
    {{ dbt_utils.generate_surrogate_key(['a.ticker']) }} as id,

    a.ticker,
    a.nome,
    a.setor,
    a.subsetor,
    a.tipo,
    a.pais,
    a.moeda,
    a.ativo,

    -- Estatísticas históricas
    s.total_pregoes,
    s.primeira_data,
    s.ultima_data,
    s.preco_medio,
    s.preco_minimo,
    s.preco_maximo,
    s.volume_medio_diario,

    -- Snapshot atual
    u.preco_atual,
    u.retorno_acumulado_total,
    u.retorno_ytd,
    u.volatilidade_anual  as volatilidade_atual,
    u.beta_ibov           as beta_atual,

    -- Classificação de risco
    case
        when u.volatilidade_anual < 0.20 then 'baixo'
        when u.volatilidade_anual < 0.40 then 'medio'
        else 'alto'
    end as perfil_risco,

    now() as atualizado_em

from ativos a
left join stats       s on s.ticker = a.ticker
left join ultimo_preco u on u.ticker = a.ticker
