-- A commute leg is only valid if the bus actually serves both stops,
-- and reaches the alighting stop after the boarding stop.
-- dbt treats any row returned here as a failure.
select *
from {{ ref('commute_legs') }}
where board_sequence is null
   or alight_sequence is null
   or alight_sequence <= board_sequence
