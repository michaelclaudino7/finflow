{{
    config(
        materialized = 'table',
        description  = 'Matriz de correlação entre retornos dos ativos (janela anual).'
    )
}}

/*
  Correlação de Pearson entre os retornos diários de todos os pares de ativos.
  Útil para análise de diversificação de portfólio.
*/

with retornos as (
    select ticker, data, retorno_diario
    from {{ ref('fact_precos') }}
    where retorno_diario is not null
      and ticker != '^BVSP'
),

anos as (
    select distinct extract(year from data)::int as ano from retornos
),

pares as (
    select
        a.ticker as ticker_a,
        b.ticker as ticker_b,
        extract(year from a.data)::int as ano
    from retornos a
    join retornos b
        on a.data    = b.data
       and a.ticker != b.ticker
       and a.ticker  < b.ticker  -- evita duplicatas (A-B e B-A)
    group by 1, 2, 3
),

correlacoes as (
    select
        a.ticker                               as ticker_a,
        b.ticker                               as ticker_b,
        extract(year from a.data)::int         as ano,
        count(*)                               as n_observacoes,
        round(
            corr(a.retorno_diario, b.retorno_diario)::numeric,
            4
        )                                      as correlacao

    from retornos a
    join retornos b
        on a.data    = b.data
       and a.ticker != b.ticker
       and a.ticker  < b.ticker
    group by 1, 2, 3
    having count(*) >= 20  -- mínimo 20 observações comuns
)

select
    {{ dbt_utils.generate_surrogate_key(['ticker_a', 'ticker_b', 'ano::text']) }} as id,

    ticker_a,
    ticker_b,
    ano,
    n_observacoes,
    correlacao,

    -- Classificação da correlação
    case
        when correlacao >= 0.7   then 'alta_positiva'
        when correlacao >= 0.3   then 'moderada_positiva'
        when correlacao >= -0.3  then 'neutra'
        when correlacao >= -0.7  then 'moderada_negativa'
        else                          'alta_negativa'
    end as classificacao,

    -- Potencial de diversificação
    case
        when abs(correlacao) < 0.3 then 'alto'
        when abs(correlacao) < 0.6 then 'moderado'
        else                            'baixo'
    end as potencial_diversificacao,

    now() as atualizado_em

from correlacoes
