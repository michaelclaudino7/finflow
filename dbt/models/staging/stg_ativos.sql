{{
    config(
        materialized = 'view',
        description  = 'Metadados dos ativos padronizados.'
    )
}}

with source as (
    select * from {{ source('raw', 'ativos') }}
)

select
    ticker,
    coalesce(nome, ticker)          as nome,
    coalesce(setor, 'Não informado') as setor,
    subsetor,
    upper(tipo)                      as tipo,
    pais,
    upper(moeda)                     as moeda,
    ativo,
    carregado_em
from source
where ticker is not null
