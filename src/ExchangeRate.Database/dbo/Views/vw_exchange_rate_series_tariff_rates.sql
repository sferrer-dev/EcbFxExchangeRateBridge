CREATE VIEW [dbo].[vw_exchange_rate_series_tariff_rates]
AS 
/*
    Vue métier : Taux de change tarifaire (fallback 90 → 60 → 30 → dernier taux connu)

    Objectif :
    - Produire un taux utilisable pour la tarification (ERP)
    - Privilégier la stabilité (fenêtre longue) plutôt que la réactivité
    - Assurer un fallback final sur le dernier taux connu si les fenêtres ne sont pas fiables

    Sources :
    - dbo.vw_exchange_rate_series_stable_rates : taux stables + nb de points
    - dbo.exchange_rates_daily : dernier taux observé (asof_date)
*/
WITH LastKnown AS
(
    /*
        Dernier taux de change connu par devise pour une série (à la as-of date).
        On le récupère explicitement pour servir de fallback final.
    */
    SELECT
        s.currency,
        s.series_key,
        s.asof_date,
        d.obs_value AS last_rate_value
    FROM dbo.vw_exchange_rate_series_stable_rates s
    LEFT JOIN dbo.exchange_rates_daily d
        ON d.currency  = s.currency
       AND d.time_period  = s.asof_date
       AND d.obs_value IS NOT NULL
)
SELECT
    s.currency,
    s.series_key,
    s.asof_date,

    /*
        Taux tarifaire retenu :
        - 90j si suffisamment de points
        - sinon 60j
        - sinon 30j
        - sinon dernier taux connu (obs_value à asof_date)
    */
    COALESCE(
        CASE WHEN s.nb_points_90d >= 60 THEN s.stable_rate_90d END,
        CASE WHEN s.nb_points_60d >= 39 THEN s.stable_rate_60d END,
        CASE WHEN s.nb_points_30d >= 20 THEN s.stable_rate_30d END,
        lk.last_rate_value
    ) AS tariff_rate,

    /*
        Fenêtre réellement utilisée (audit / support métier)
        - 90 / 60 / 30 si une moyenne stable est retenue
        - 0 si fallback sur le dernier taux connu
    */
    CASE
        WHEN s.nb_points_90d >= 60 THEN 90
        WHEN s.nb_points_60d >= 39 THEN 60
        WHEN s.nb_points_30d >= 20 THEN 30
        WHEN lk.last_rate_value IS NOT NULL THEN 0
        ELSE NULL
    END AS tariff_rate_window_days,

    /*
        Source du taux retenu (traçabilité explicite)
    */
    CASE
        WHEN s.nb_points_90d >= 60 THEN N'STABLE_90D'
        WHEN s.nb_points_60d >= 39 THEN N'STABLE_60D'
        WHEN s.nb_points_30d >= 20 THEN N'STABLE_30D'
        WHEN lk.last_rate_value IS NOT NULL THEN N'LAST_KNOWN'
        ELSE N'UNAVAILABLE'
    END AS tariff_rate_source,

    /*
        Indicateur de disponibilité
    */
    CASE
        WHEN COALESCE(
                CASE WHEN s.nb_points_90d >= 60 THEN s.stable_rate_90d END,
                CASE WHEN s.nb_points_60d >= 39 THEN s.stable_rate_60d END,
                CASE WHEN s.nb_points_30d >= 20 THEN s.stable_rate_30d END,
                lk.last_rate_value
             ) IS NOT NULL
        THEN 1 ELSE 0
    END AS is_tariff_rate_available,

    /*
        Exposition des métriques pour contrôle / debug
    */
    s.stable_rate_30d,
    s.stable_rate_60d,
    s.stable_rate_90d,
    lk.last_rate_value AS last_known_rate,

    s.nb_points_30d,
    s.nb_points_60d,
    s.nb_points_90d

FROM dbo.vw_exchange_rate_series_stable_rates s
LEFT JOIN LastKnown lk
    ON lk.currency = s.currency
   AND lk.asof_date  = s.asof_date;
