CREATE VIEW dbo.vw_devises_stable_rates
AS
/*
    Vue métier des taux de change stables (30/60/90 jours)
    Objectif :
    - Calculer des taux moyens "stables" à 30, 60 et 90 jours pour chaque devise active
    - Date d’ancrage = dernière DVHDATEDEB disponible
*/
WITH LastObs AS
(
    /*
        Détermination de la date de référence (as-of date)
        Pour chaque devise, on récupère la dernière date
        pour laquelle un taux valide existe.
    */
    SELECT
        h.DEVID,
        MAX(h.DVHDATEDEB) AS asof_date
    FROM dbo.DEVISES_HISTO h
    WHERE h.DVHCOURS IS NOT NULL
      AND h.DVHCOURS > 0
    GROUP BY h.DEVID
)
SELECT
    dev.DEVID,
    dev.DEVSYMBOLE,
    /*
        Date de référence du calcul
    */
    l.asof_date,
    /*
        Moyenne glissante 30 jours
    */
    AVG(
        CASE
            WHEN h.DVHDATEDEB > DATEADD(DAY, -30, l.asof_date)
            THEN h.DVHCOURS
        END
    ) AS stable_rate_30d,
    /*
        Moyenne glissante 60 jours
    */
    AVG(
        CASE
            WHEN h.DVHDATEDEB > DATEADD(DAY, -60, l.asof_date)
            THEN h.DVHCOURS
        END
    ) AS stable_rate_60d,
    /*
        Moyenne glissante 90 jours
    */
    AVG(
        CASE
            WHEN h.DVHDATEDEB > DATEADD(DAY, -90, l.asof_date)
            THEN h.DVHCOURS
        END
    ) AS stable_rate_90d,
    /*
        Nombre de points utilisés (contrôle qualité)
    */
    COUNT(
        CASE
            WHEN h.DVHDATEDEB > DATEADD(DAY, -30, l.asof_date)
            THEN 1
        END
    ) AS nb_points_30d,
    COUNT(
        CASE
            WHEN h.DVHDATEDEB > DATEADD(DAY, -60, l.asof_date)
            THEN 1
        END
    ) AS nb_points_60d,
    COUNT(
        CASE
            WHEN h.DVHDATEDEB > DATEADD(DAY, -90, l.asof_date)
            THEN 1
        END
    ) AS nb_points_90d
FROM LastObs l
JOIN dbo.DEVISES_HISTO h
    ON h.DEVID = l.DEVID
   AND h.DVHDATEDEB <= l.asof_date
   AND h.DVHCOURS IS NOT NULL
   AND h.DVHCOURS > 0
JOIN dbo.DEVISES dev
    ON dev.DEVID = l.DEVID
   AND dev.DEVISACTIVE = 'O'
   AND dev.DEVISREFERENCE = 'N'
GROUP BY
    dev.DEVID,
    dev.DEVSYMBOLE,
    l.asof_date;
