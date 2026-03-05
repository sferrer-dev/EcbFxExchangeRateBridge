CREATE VIEW dbo.vw_devises_last_rate
AS
/*
    Trouver le dernier taux de change valide
    pour chaque devise active (hors devise de référence).
    Règles métier :
    - Une seule ligne retournée par devise
    - Seules les devises actives sont prises en compte (DEVISACTIVE = 'O')
    - La devise de référence (Euro) est exclue (DEVISREFERENCE = 'N')
    - Un taux valide est défini comme :
          DVHCOURS IS NOT NULL
          DVHCOURS > 0
    - La dernière observation est déterminée par :
          1) La date la plus récente (DVHDATEDEB)
          2) En cas d’égalité sur la date, le plus grand identifiant (DVHID)
*/
WITH max_date AS
(
    /*
        Étape 1 : Détermination de la dernière date valide par devise
        ----------------------------------------------------------------
        On filtre les cours valides puis on récupère la date maximale
        par clé métier (DEVID).
    */
    SELECT
        h.DEVID,
        MAX(h.DVHDATEDEB) AS max_dvhdatedeb
    FROM dbo.DEVISES_HISTO AS h
    WHERE h.DVHCOURS IS NOT NULL      -- Exclusion des taux NULL
      AND h.DVHCOURS > 0              -- Exclusion des taux invalides (<= 0)
    GROUP BY h.DEVID
),
max_id AS
(
    /*
        Étape 2 : Détermination de l'enregistrement exact à retenir
        ----------------------------------------------------------------
        Pour chaque devise et pour la date maximale trouvée précédemment,
        on sélectionne le plus grand DVHID afin de garantir :
        - Une seule ligne par devise
        - Une sélection déterministe en cas de doublon sur la date
    */
    SELECT
        h.DEVID,
        MAX(h.DVHID) AS max_dvhid
    FROM dbo.DEVISES_HISTO AS h
    INNER JOIN max_date AS d
        ON d.DEVID = h.DEVID
       AND d.max_dvhdatedeb = h.DVHDATEDEB
    WHERE h.DVHCOURS IS NOT NULL
      AND h.DVHCOURS > 0
    GROUP BY h.DEVID
)
/*
    Étape 3 : Projection finale
    ----------------------------------------------------------------
    On joint :
    - Le référentiel des devises
    - L’identifiant de l’observation retenue
    - L’historique pour récupérer la date et la valeur du taux
    On applique ensuite les filtres métier sur les devises.
*/
SELECT
    dev.DEVID,
    dev.DEVSYMBOLE,
    h.DVHDATEDEB AS last_rate_date,
    h.DVHCOURS   AS last_rate_value
FROM dbo.DEVISES AS dev
INNER JOIN max_id AS m
    ON m.DEVID = dev.DEVID
INNER JOIN dbo.DEVISES_HISTO AS h
    ON h.DVHID = m.max_dvhid
WHERE dev.DEVISACTIVE = 'O'          -- Devise active uniquement
  AND dev.DEVISREFERENCE = 'N';      -- Exclusion de la devise de référence (Euro)
