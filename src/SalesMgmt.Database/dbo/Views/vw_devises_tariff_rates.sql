CREATE VIEW dbo.vw_devises_tariff_rates
AS
/*
    Vue métier : Taux de change tarifaire (fallback 90 → 60 → 30 → dernier taux connu)
    Objectif :
    - Produire un taux exploitable pour la tarification (ERP / gestion commerciale)
    - Assurer un fallback final sur le dernier taux connu (à la as-of date)
*/
WITH LastKnown AS
(
    /*
        Dernier taux connu à la as-of date (fallback final)
        Pour chaque devise (DEVID) et sa as-of date calculée par vw_devise_stable_rates,
        on récupère explicitement la valeur DVHCOURS à cette date.
    */
    SELECT
        s.DEVID,
        s.DEVSYMBOLE,
        s.asof_date,
        h.DVHCOURS AS last_rate_value
    FROM dbo.vw_devises_stable_rates AS s
    LEFT JOIN dbo.DEVISES_HISTO AS h
        ON h.DEVID      = s.DEVID
       AND h.DVHDATEDEB = s.asof_date
       AND h.DVHCOURS IS NOT NULL
       AND h.DVHCOURS > 0
)
SELECT
    s.DEVID,
    s.DEVSYMBOLE,
    s.asof_date,
    /*
        Taux tarifaire retenu :
        - 90j si suffisamment de points
        - sinon 60j
        - sinon 30j
        - sinon dernier taux connu (DVHCOURS à asof_date)
    */
    COALESCE(
        CASE WHEN s.nb_points_90d >= 60 THEN s.stable_rate_90d END,
        CASE WHEN s.nb_points_60d >= 39 THEN s.stable_rate_60d END,
        CASE WHEN s.nb_points_30d >= 20 THEN s.stable_rate_30d END,
        lk.last_rate_value
    ) AS tariff_rate,
    /*
        Fenêtre réellement utilisée (audit)
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
        Source du taux retenu (traçabilité)
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
        Exposition des métriques (contrôle / debug)
    */
    s.stable_rate_30d,
    s.stable_rate_60d,
    s.stable_rate_90d,
    lk.last_rate_value AS last_known_rate,
    s.nb_points_30d,
    s.nb_points_60d,
    s.nb_points_90d
FROM dbo.vw_devises_stable_rates AS s
LEFT JOIN LastKnown AS lk
    ON lk.DEVID     = s.DEVID
   AND lk.asof_date = s.asof_date;
