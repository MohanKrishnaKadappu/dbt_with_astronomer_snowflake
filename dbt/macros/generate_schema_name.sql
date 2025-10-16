{% macro generate_schema_name(custom_schema, node) -%}
  
  {%- if custom_schema is not none and custom_schema != '' -%}
    {{ return(custom_schema) }}
  {%- endif -%}

  {%- set node_config_schema = (node.get('config') or {}).get('schema') -%}
  {%- if node_config_schema -%}
    {{ return(node_config_schema) }}
  {%- endif -%}

  {{ return(target.schema) }}
{%- endmacro %}
 