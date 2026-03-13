/* ============================================================
   Procédure : Synchronisation des taux ECB vers DEVISES_HISTO
   Objectif :
   - Charger ou mettre à jour les taux journaliers
   - Sur une plage de dates donnée (ou complète si NULL)
============================================================ */
CREATE PROCEDURE dbo.usp_Merge_DevisesHisto_FromEcbDaily
(
      @FromDate  date = NULL
    , @ToDate    date = NULL
)
AS
BEGIN
    -- Supprime les messages "(X rows affected)" inutiles
    -- Réduit le bruit dans les logs SSIS / SQL Agent
    SET NOCOUNT ON;
    -- Si une erreur survient, la transaction est automatiquement annulée
    -- Garantit la cohérence des données
    SET XACT_ABORT ON;
    
/* ========================================================
    Détermination dynamique de la plage de dates
======================================================== */
    DECLARE @MinDate date, @MaxDate date;
    -- On interroge directement la table source ECB
    -- via la variable SQLCMD définie dans SSDT
    --  On récupère min/max directement sur la table source
    SELECT
        @MinDate = MIN(s.time_period),
        @MaxDate = MAX(s.time_period)
    FROM [$(ExchangeRatesDB)].dbo.exchange_rates_daily s;

    -- Si l’utilisateur n’a pas fourni de dates,
    -- on charge toute la plage disponible
    SET @FromDate = COALESCE(@FromDate, @MinDate);
    SET @ToDate   = COALESCE(@ToDate,   @MaxDate);

/* ========================================================
    MERGE UPSERT
    - T = Target (table cible)
    - S = Source (dataset préparé via TVF)
======================================================== */
    MERGE dbo.DEVISES_HISTO AS T
    USING
    (
        -- La TVF encapsule :
        -- - le mapping devise
        -- - le calcul des dates de validité
        -- - le calcul du taux inverse
        SELECT
            DEVID,
            DVHDATEDEB,
            DVHDATEFIN,
            DVHCOURS,
            DVHCOURSINV,
            USRMODIF
        FROM dbo.fn_EcbDailyRates_Prepared(@FromDate, @ToDate)
    ) AS S
    -- Clé métier de synchronisation :
    -- Une ligne par devise et par date
    ON  T.DEVID      = S.DEVID
    AND T.DVHDATEDEB = S.DVHDATEDEB
    /* ========================================================
        CAS 1 : La ligne existe déjà → vérifier si modification
    ======================================================== */
    WHEN MATCHED AND
    (
        -- Comparaison DVHCOURS
        (T.DVHCOURS <> S.DVHCOURS)
        OR (T.DVHCOURS IS NULL AND S.DVHCOURS IS NOT NULL)
        OR (T.DVHCOURS IS NOT NULL AND S.DVHCOURS IS NULL)
        -- Comparaison DVHCOURSINV
        OR (T.DVHCOURSINV <> S.DVHCOURSINV)
        OR (T.DVHCOURSINV IS NULL AND S.DVHCOURSINV IS NOT NULL)
        OR (T.DVHCOURSINV IS NOT NULL AND S.DVHCOURSINV IS NULL)
        -- Comparaison DVHDATEFIN
        OR (T.DVHDATEFIN <> S.DVHDATEFIN)
        OR (T.DVHDATEFIN IS NULL AND S.DVHDATEFIN IS NOT NULL)
        OR (T.DVHDATEFIN IS NOT NULL AND S.DVHDATEFIN IS NULL)
    )
    THEN UPDATE SET
        -- Mise à jour uniquement si données réellement différentes
          T.DVHDATEFIN  = S.DVHDATEFIN
        , T.DVHCOURS    = S.DVHCOURS
        , T.DVHCOURSINV = S.DVHCOURSINV
        -- Traçabilité technique
        , T.USRMODIF    = S.USRMODIF
        -- Horodatage système de modification
        , T.DATEUPDATE  = SYSDATETIME()
    /* ========================================================
           CAS 2 : La ligne n’existe pas → insertion
    ======================================================== */
    WHEN NOT MATCHED BY TARGET
    THEN INSERT
    (
          DEVID
        , DVHDATEDEB
        , DVHDATEFIN
        , DVHCOURS
        , USRMODIF
        , DATECREATE
        , DATEUPDATE
        , DVHCOURSINV
    )
    VALUES
    (
          S.DEVID
        , S.DVHDATEDEB
        , S.DVHDATEFIN
        , S.DVHCOURS
        -- Traçabilité technique
        , S.USRMODIF
        -- Horodatage automatique
        , SYSDATETIME()
        , SYSDATETIME()
        , S.DVHCOURSINV
    );
/* ========================================================
       Fin du MERGE
======================================================== */
END
