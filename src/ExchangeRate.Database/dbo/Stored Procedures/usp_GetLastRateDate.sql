CREATE PROCEDURE dbo.usp_GetLastRateDate
    @SeriesKey      NVARCHAR(30),   -- Clé fonctionnelle de la série de taux (ex : EXR.D.USD.EUR.SP00.A)
    @LastRateDate   DATE OUTPUT     -- Date de la dernière observation valide retournée au caller (SSIS, applicatif, etc.)
AS
BEGIN
    -- Désactive le message "n rows affected"
    -- Bonne pratique pour éviter le bruit dans les logs SSIS
    SET NOCOUNT ON;

    -- Récupération de la date la plus récente pour la série demandée
    -- Critères de validité métier :
    --  - obs_status = 'A'  : observation active / valide
    --  - obs_value IS NOT NULL : valeur effectivement présente
    SELECT TOP (1)
        @LastRateDate = d.time_period
    FROM dbo.exchange_rates_daily AS d
    WHERE d.series_key = @SeriesKey
      AND d.obs_status = N'A'
      AND d.obs_value IS NOT NULL
    -- Tri décroissant pour garantir la dernière date disponible
    ORDER BY d.time_period DESC;

    -- Si aucune ligne ne correspond aux critères,
    -- @LastRateDate reste à NULL (comportement attendu et contrôlable côté appelant)
END
