{#
  HRSA publishes every UDS value as text, with three markers instead of numbers:
    "-"    no data entered by the health center
    "--"   a patient count between 1 and 15, suppressed to protect privacy
    "---"  health center confidential data (e.g. most of Tables 5, 8A and 9D)
  uds_number() turns a cell into a number (NULL for any marker); uds_status() says why it's NULL.
#}
{% macro uds_number(col) -%}
    case when trim({{ col }}) in ('-', '--', '---', '') or {{ col }} is null then null
         else try_cast(replace(trim({{ col }}), ',', '') as double) end
{%- endmacro %}

{% macro uds_status(col) -%}
    case trim(coalesce({{ col }}, ''))
        when '---' then 'confidential'
        when '--'  then 'suppressed_1_to_15'
        when '-'   then 'not_reported'
        when ''    then 'not_reported'
        else 'reported'
    end
{%- endmacro %}
