{#
  LTA gives scheduled frequency as messy text: "07-12" (every 7 to 12 min),
  "8" (every 8 min), "-" or "00-00" (not running). Turn it into a number.
  bound = 'min' or 'max'.
#}
{% macro freq_minutes(column, bound) %}
    {%- set cleaned = "nullif(nullif(nullif(" ~ column ~ ", ''), '-'), '00-00')" -%}
    {%- if bound == 'min' -%}
        nullif(split_part({{ cleaned }}, '-', 1), '')::int
    {%- else -%}
        coalesce(nullif(split_part({{ cleaned }}, '-', 2), ''), nullif(split_part({{ cleaned }}, '-', 1), ''))::int
    {%- endif -%}
{% endmacro %}
