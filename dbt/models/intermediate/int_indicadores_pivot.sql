{{
    config(
        materialized = 'ephemeral',
        description  = 'Indicadores macro pivotados — uma coluna por indicador por data.'
    )
}}

/*
  Agrupa por data e pivotar os principais indicadores diários.
  Para indicadores mensais (IPCA, IGP-M), propaga o valor para
  todos os dias do mês via forward-fill com window function.
*/

with diarios as (
    select data, indicador, valor
    from {{ ref('stg_indicadores_macro') }}
    where frequencia = 'diario'
),

mensais as (
    select data, indicador, valor
    from {{ ref('stg_indicadores_macro') }}
    where frequencia = 'mensal'
),

-- Datas com pelo menos um indicador
datas as (
    select distinct data from {{ ref('stg_indicadores_macro') }}
),

-- Pivot de indicadores diários
pivot_diario as (
    select
        data,
        max(case when indicador = 'selic_diaria' then valor end) as selic_diaria,
        max(case when indicador = 'cdi'          then valor end) as cdi_diario,
        max(case when indicador = 'usd_brl'      then valor end) as usd_brl,
        max(case when indicador = 'eur_brl'      then valor end) as eur_brl
    from diarios
    group by 1
),

-- Pivot de indicadores mensais
pivot_mensal as (
    select
        date_trunc('month', data)::date            as mes,
        max(case when indicador = 'ipca'     then valor end) as ipca_mensal,
        max(case when indicador = 'igpm'     then valor end) as igpm_mensal,
        max(case when indicador = 'selic_meta' then valor end) as selic_meta
    from mensais
    group by 1
)

select
    d.data,
    pd.selic_diaria,
    pd.cdi_diario,
    pd.usd_brl,
    pd.eur_brl,
    pm.ipca_mensal,
    pm.igpm_mensal,
    pm.selic_meta,

    -- CDI acumulado no mês (soma cumulativa de CDI diário no mês)
    sum(pd.cdi_diario) over (
        partition by date_trunc('month', d.data)
        order by d.data
        rows between unbounded preceding and current row
    ) as cdi_acumulado_mes

from datas d
left join pivot_diario pd on pd.data = d.data
left join pivot_mensal pm on pm.mes  = date_trunc('month', d.data)::date
