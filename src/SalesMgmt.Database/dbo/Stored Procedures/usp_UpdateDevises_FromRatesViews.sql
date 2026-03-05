/* =====================================================================
   Procédure : Mise à ajour et synchro des taux de change dans 
   la table dbo.DEVISES  à partir des vues calculées :
   - dbo.vw_devises_last_rate       (taux spot)
   - dbo.vw_devises_tariff_rates    (taux tarif / stable)

   Objectif : Mettre à jour les colonnes de cours de la table DEVISES.
   - DEVCOURS        : dernier taux spot connu
   - DEVCOURSTARIF   : taux tarif (stable 30/60/90 jours si disponible)
   - DEVCOURSINV     : inverse du taux spot
   - USRMODIF        : utilisateur ayant déclenché la mise à jour
   - DATEUPDATE      : horodatage de mise à jour

   Paramètre :
     @ModifiedBy (optionnel) : permet d’imposer un utilisateur technique

   Retour :
   - Nombre de lignes mises à jour
   - Utilisateur ayant effectué la modification
   - Date d’exécution
===================================================================== */
CREATE PROCEDURE dbo.usp_UpdateDevises_FromRatesViews
(
    @ModifiedBy sysname = NULL  -- optionnel : permet à SSIS d’imposer un "service account"
)
AS
BEGIN
    -- Supprime les messages "(n rows affected)" pour éviter le bruit côté SSIS
    SET NOCOUNT ON;

    -- Force le rollback automatique si une erreur runtime survient
    SET XACT_ABORT ON;

     -- Horodatage unique pour toute l’opération (cohérence temporelle)
    DECLARE @Now datetime2(0) = SYSDATETIME();

    -- Détermination de l’utilisateur technique ou interactif
    DECLARE @Usr sysname = COALESCE(@ModifiedBy, ORIGINAL_LOGIN(), SUSER_SNAME(), N'dbo');

    BEGIN TRY
        -- Début de la transaction explicite
        BEGIN TRAN;

        /**************************************************************************
         CTE : RateInput
         Prépare le jeu de données source pour l’UPDATE
         - Jointure avec les vues de calcul des taux
         - Application des règles métier de sélection
        **************************************************************************/
        WITH RateInput AS
        (
            SELECT
                d.DEVID,
                
                -- Dernier taux spot issu de la vue
                lr.last_rate_value AS last_rate_value,

            -- Sélection du taux tarif :
            -- Si un taux stable est disponible et valide → on l’utilise
            -- Sinon → fallback sur le taux spot
            CASE
                WHEN tr.is_tariff_rate_available = 1 AND tr.tariff_rate IS NOT NULL AND tr.tariff_rate > 0
                THEN tr.tariff_rate
                ELSE lr.last_rate_value
            END AS tariff_rate_value
            FROM dbo.DEVISES d
            -- Jointure sur la vue du dernier taux spot
            LEFT JOIN dbo.vw_devises_last_rate lr
                ON lr.DEVID = d.DEVID
            -- Jointure sur la vue des taux tarif/stables
            LEFT JOIN dbo.vw_devises_tariff_rates tr
                ON tr.DEVID = d.DEVID
            -- Filtrage métier
            WHERE d.DEVISACTIVE = 'O' 
                AND d.DEVISREFERENCE = 'N'
        )
        /**************************************************************************
         UPDATE set-based : Mise à jour en masse
        **************************************************************************/
        UPDATE d
        SET
            -- Taux spot
            d.DEVCOURS      = ri.last_rate_value,

            -- Taux tarif (stable ou fallback)
            d.DEVCOURSTARIF = ri.tariff_rate_value,

            -- Calcul de l’inverse du taux spot
            -- NULLIF évite la division par zéro
            -- CAST impose une précision financière
            d.DEVCOURSINV   = CAST(1.0 / NULLIF(ri.last_rate_value, 0) AS decimal(18,12)),

            -- Traçabilité
            d.USRMODIF      = @Usr,
            d.DATEUPDATE    = @Now
        FROM dbo.DEVISES d
        INNER JOIN RateInput ri
                ON ri.DEVID = d.DEVID
        WHERE
            -- on met à jour seulement si on a un cours spot valide
            ri.last_rate_value IS NOT NULL
            AND ri.last_rate_value > 0
            -- On met à jour uniquement si au moins une valeur diffère
            AND (
                   ISNULL(d.DEVCOURS,      -1) <> ri.last_rate_value
                OR ISNULL(d.DEVCOURSTARIF, -1) <> ri.tariff_rate_value
                OR ISNULL(d.DEVCOURSINV,   -1) <> CAST(1.0 / NULLIF(ri.last_rate_value, 0) AS decimal(18,12))
            );
    
    -- Capture du nombre réel de lignes impactées
    DECLARE @Rows int = @@ROWCOUNT;
    
    -- Validation définitive de la transaction
    COMMIT;

    -- Retour d’information exploitable côté SSIS / monitoring
    SELECT
            @Rows AS rows_updated,
            @Usr  AS usrmodif,
            @Now  AS dateupdate;
    END TRY
    BEGIN CATCH
        -- Si une transaction est ouverte, on annule tout
        IF @@TRANCOUNT > 0 
            ROLLBACK;
        -- Relance l’erreur originale pour propagation correcte
        THROW;
    END CATCH
END
