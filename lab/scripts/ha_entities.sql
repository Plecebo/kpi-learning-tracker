-- ha_entities.sql — the Home Assistant recorder allowlist.
--
-- The lab does NOT dump all 1,152 `statistics_meta` entities. This file is the curated
-- scope: a short list of `statistic_id` patterns, each annotated with the roadmap week(s)
-- it serves (`docs/kpi-learning-roadmap.md`). The extractor (`fetch_ha.py`) matches each
-- pattern against `statistics_meta.statistic_id` with SQL `LIKE` (underscores escaped), so
-- a renamed or added entity in the same family is picked up without editing this file.
--
-- `%` is the only wildcard; `_` is a literal underscore. The second column (`use_week`)
-- is a comma-separated list of week tags copied verbatim into `ha_entity_catalog.use_week`.
--
-- Why these and not the other 1,100: they are the series the exercises actually reason
-- about — the whole-home lagging outcome, its weather normaliser, the crawlspace guardrail
-- and dehumidifier load, the heat-pump intervention (a deliberate null result), the water
-- heater (including the `_2` rename defect), and one sparse carport series (the "not every
-- series deserves a chart" case).
SELECT * FROM (VALUES
    ('opower:pse_elec_%_energy_consumption',              'w1,w2,w3,w4,w6,w8,w9,w10,w11'),
    ('opower:pse_elec_%_energy_return',                   'w3,w4,w6'),
    ('sensor.sheffield_deux_outdoor_temperature',         'w1,w4,w6,w8,w9'),
    ('sensor.crawlspace_dehumidifier%consumption',        'w1,w2,w5,w6,w7,w8'),
    ('sensor.crawlspace_sensor%',                         'w1,w3,w5,w6'),
    ('sensor.heat_pump%',                                 'w4,w6,w9'),
    ('sensor.electric_water_heater%',                     'w6,w7'),
    ('sensor.carport_exterior_shelly_1pm_switch_0_energy','w8')
) AS t(pattern, use_week);
