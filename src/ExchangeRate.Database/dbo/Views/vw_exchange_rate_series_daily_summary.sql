CREATE VIEW dbo.vw_exchange_rate_series_daily_summary
AS
/*
    Vue de synthèse par série de taux de change.
    Objectifs :
    - Fournir une vision agrégée des données journalières par série
    - Exposer des indicateurs de volumétrie et de couverture temporelle
    - Identifier les séries actives sans données quotidiennes associées
    - Mesurer la fraîcheur des dernières observations disponibles
    Cette vue est destinée aux usages suivants :
    - Monitoring et contrôle qualité des chargements SSIS
    - Reporting de complétude et de fraîcheur des données
    - Aide au diagnostic des séries actives non alimentées
*/
WITH daily_stats AS
(
    -- Agrégation des données journalières par série
    SELECT
        d.series_key,
        COUNT_BIG(*)       AS daily_row_count,     -- Nombre total d'observations journalières
        MIN(d.time_period) AS start_time_period,   -- Date de début des données disponibles
        MAX(d.time_period) AS last_time_period     -- Date de la dernière observation disponible
    FROM dbo.exchange_rates_daily AS d
    GROUP BY d.series_key
)
SELECT
    -- Métadonnées de la série
    s.rate_series_id,
    s.series_key,
    s.currency,
    s.is_active,
    s.date_create,
    s.created_by,
    s.comment,
    -- Statistiques issues des données journalières
    ds.daily_row_count,
    ds.start_time_period,
    ds.last_time_period,
    -- Indicateurs de présence des données
    CASE
        WHEN ds.series_key IS NULL THEN 0
        ELSE 1
    END AS has_daily_data,

    CASE
        WHEN s.is_active = 1 AND ds.series_key IS NULL THEN 1
        ELSE 0
    END AS is_active_but_missing_daily,

    -- Indicateur de fraîcheur : nombre de jours écoulés depuis la dernière observation
    CASE
        WHEN ds.last_time_period IS NULL THEN NULL
        ELSE DATEDIFF(DAY, ds.last_time_period, CAST(GETDATE() AS date))
    END AS days_since_last_rate
FROM dbo.exchange_rate_series AS s
LEFT JOIN daily_stats AS ds
    ON ds.series_key = s.series_key;
