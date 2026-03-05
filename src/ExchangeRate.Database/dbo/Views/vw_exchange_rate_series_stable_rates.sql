CREATE VIEW dbo.vw_exchange_rate_series_stable_rates
AS
/*
    Vue métier : Taux de change stables par série de devise

    Objectif :
    - Calculer des taux de change "stables" à 30, 60 et 90 jours
    - Fournir une base fiable pour les taux tarifaires en gestion commerciale

    Principe :
    - Pour chaque devise currency et series_key, on identifie la dernière date disponible (as-of date)
    - On calcule des moyennes glissantes sur les N derniers jours calendaires
    - On expose également le nombre de points utilisés pour contrôle qualité
*/
WITH LastObs AS
(
    /*
        Identification de la date de référence (as-of date)
        ----------------------------------------------------
        Pour chaque devise currency et série de taux (series_key), on récupère
        la dernière date pour laquelle une valeur existe.
        Cette date sert de point d'ancrage temporel pour
        tous les calculs de taux stables.
    */
    SELECT
        currency,
        series_key,
        MAX(time_period) AS asof_date
    FROM dbo.exchange_rates_daily
    WHERE obs_value IS NOT NULL
    GROUP BY currency, series_key
)
SELECT
    /*
        Devise de la série de taux de change
        Exemple : EUR, USD, etc.
    */
    l.currency,
    /*
        Clé métier de la série de taux de change
        Exemple : EXR.D.USD.EUR.SP00.A
    */
    l.series_key,

    /*
        Date de référence du calcul (dernière observation connue)
        Tous les taux stables sont calculés "as of" cette date.
    */
    l.asof_date,

    /*
        Taux de change stable sur 30 jours
        ----------------------------------
        Moyenne des valeurs observées sur les 30 derniers jours
        précédant la as-of date.
    */
    AVG(
        CASE
            WHEN d.time_period > DATEADD(DAY, -30, l.asof_date)
            THEN d.obs_value
        END
    ) AS stable_rate_30d,

    /*
        Taux de change stable sur 60 jours
    */
    AVG(
        CASE
            WHEN d.time_period > DATEADD(DAY, -60, l.asof_date)
            THEN d.obs_value
        END
    ) AS stable_rate_60d,

    /*
        Taux de change stable sur 90 jours
    */
    AVG(
        CASE
            WHEN d.time_period > DATEADD(DAY, -90, l.asof_date)
            THEN d.obs_value
        END
    ) AS stable_rate_90d,

    /*
        Nombre de points utilisés pour le calcul 30 jours
        Permet de contrôler la qualité du taux (jours ouvrés,
        données manquantes, devise peu liquide, etc.).
    */
    COUNT(
        CASE
            WHEN d.time_period > DATEADD(DAY, -30, l.asof_date)
            THEN 1
        END
    ) AS nb_points_30d,

    /*
        Nombre de points utilisés pour le calcul 60 jours
    */
    COUNT(
        CASE
            WHEN d.time_period > DATEADD(DAY, -60, l.asof_date)
            THEN 1
        END
    ) AS nb_points_60d,

    /*
        Nombre de points utilisés pour le calcul 90 jours
    */
    COUNT(
        CASE
            WHEN d.time_period > DATEADD(DAY, -90, l.asof_date)
            THEN 1
        END
    ) AS nb_points_90d

FROM LastObs l
JOIN dbo.exchange_rates_daily d
    /*
        Jointure sur la même devise (et série de devise)
        + sécurisation temporelle (pas de données futures)
        + exclusion des valeurs nulles
    */
    ON d.currency = l.currency
   AND d.time_period <= l.asof_date
   AND d.obs_value IS NOT NULL

/*
    Agrégation finale par série et date de référence
*/
GROUP BY
    l.currency,
    l.series_key,
    l.asof_date;
