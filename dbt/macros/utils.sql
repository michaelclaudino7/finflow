{% macro test_sem_gaps_excessivos(model, column_name, ticker_column, max_dias=10) %}
/*
  Verifica se existem gaps de mais de `max_dias` dias corridos
  entre pregões consecutivos de um mesmo ticker.
  Exclui fins de semana e feriados prolongados (Carnaval, fim de ano).
*/

select
    {{ ticker_column }},
    {{ column_name }} as data_atual,
    lag({{ column_name }}) over (
        partition by {{ ticker_column }}
        order by {{ column_name }}
    ) as data_anterior,
    {{ column_name }} - lag({{ column_name }}) over (
        partition by {{ ticker_column }}
        order by {{ column_name }}
    ) as gap_dias
from {{ model }}
having gap_dias > {{ max_dias }}
   and extract(dow from data_anterior) not in (5, 6)  -- não é sexta

{% endmacro %}


{% macro calcular_retorno_acumulado(ticker, data_inicio, data_fim) %}
/*
  Calcula o retorno acumulado de um ticker entre duas datas.
  Uso: {{ calcular_retorno_acumulado('PETR4.SA', '2023-01-01', '2023-12-31') }}
*/
select
    exp(sum(retorno_log)) - 1 as retorno_acumulado
from {{ ref('fact_precos') }}
where ticker = '{{ ticker }}'
  and data between '{{ data_inicio }}' and '{{ data_fim }}'
  and retorno_log is not null

{% endmacro %}
