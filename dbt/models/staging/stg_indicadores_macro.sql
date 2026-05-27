{{
    config(
        materialized = 'view',
        description  = 'Indicadores macro padronizados com categorização.'
    )
}}

with source as (
    select * from {{ source('raw', 'indicadores_macro') }}
),

limpo as (
    select
        data::date          as data,
        lower(indicador)    as indicador,
        valor::numeric(18,6) as valor,
        unidade,
        fonte,

        -- Categoriza frequência
        case
            when indicador in ('selic_diaria', 'cdi', 'usd_brl', 'eur_brl')
                then 'diario'
            when indicador in ('ipca', 'igpm', 'pib_mensal')
                then 'mensal'
            else 'outro'
        end as frequencia,

        -- Grupo econômico
        case
            when indicador in ('selic_meta', 'selic_diaria', 'cdi')
                then 'juros'
            when indicador in ('ipca', 'igpm')
                then 'inflacao'
            when indicador in ('usd_brl', 'eur_brl')
                then 'cambio'
            when indicador = 'pib_mensal'
                then 'atividade'
            else 'outro'
        end as grupo

    from source
    where valor is not null
)

select * from limpo
