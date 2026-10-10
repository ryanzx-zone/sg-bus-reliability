-- One row per service per direction, with LTA's scheduled frequencies as numbers.
-- These are the "promised" gaps between buses that we'll compare against reality.
select
    payload->>'ServiceNo'                  as service_no,
    (payload->>'Direction')::int           as direction,
    payload->>'Operator'                   as operator,
    payload->>'Category'                   as category,
    payload->>'OriginCode'                 as origin_code,
    payload->>'DestinationCode'            as destination_code,
    {{ freq_minutes("payload->>'AM_Peak_Freq'", 'min') }}    as am_peak_freq_min,
    {{ freq_minutes("payload->>'AM_Peak_Freq'", 'max') }}    as am_peak_freq_max,
    {{ freq_minutes("payload->>'AM_Offpeak_Freq'", 'min') }} as am_offpeak_freq_min,
    {{ freq_minutes("payload->>'AM_Offpeak_Freq'", 'max') }} as am_offpeak_freq_max,
    {{ freq_minutes("payload->>'PM_Peak_Freq'", 'min') }}    as pm_peak_freq_min,
    {{ freq_minutes("payload->>'PM_Peak_Freq'", 'max') }}    as pm_peak_freq_max,
    {{ freq_minutes("payload->>'PM_Offpeak_Freq'", 'min') }} as pm_offpeak_freq_min,
    {{ freq_minutes("payload->>'PM_Offpeak_Freq'", 'max') }} as pm_offpeak_freq_max,
    loaded_at
from {{ source('raw', 'raw_reference') }}
where dataset = 'BusServices'
