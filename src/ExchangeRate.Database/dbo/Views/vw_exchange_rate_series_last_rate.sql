CREATE VIEW [dbo].[vw_exchange_rate_series_last_rate]
AS
/*
    Vue exposant la dernière observation valide disponible
    pour chaque série de taux de change active.
    Règles fonctionnelles :
    - Une seule ligne retournée par série
    - Seules les séries actives sont prises en compte
    - Les observations doivent être :
        • validées (obs_status = 'A')
        • non nulles (obs_value IS NOT NULL)
    - La dernière observation est déterminée par la date la plus récente (time_period)
*/
SELECT
    s.series_key,
    s.currency,
    d.time_period AS last_rate_date,
    d.obs_value   AS last_rate_value
FROM dbo.exchange_rate_series AS s
LEFT JOIN dbo.exchange_rates_daily AS d
    ON d.series_key = s.series_key
   AND d.obs_status = N'A'
   AND d.obs_value IS NOT NULL
   AND d.time_period =
   (
       SELECT MAX(d2.time_period)
       FROM dbo.exchange_rates_daily AS d2
       WHERE d2.series_key = s.series_key
         AND d2.obs_status = N'A'
         AND d2.obs_value IS NOT NULL
   )
WHERE s.is_active = 1;
