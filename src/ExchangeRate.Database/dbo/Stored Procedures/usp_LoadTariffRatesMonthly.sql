CREATE PROCEDURE dbo.usp_LoadTariffRatesMonthly
    @AsOfDate date = NULL,  -- Date de référence du snapshot mensuel (exécution ou valeur forcée)
    @Persist bit = 1        -- 1 = insère dans la table ; 0 = retourne seulement
AS
BEGIN
    SET NOCOUNT ON;         -- Évite les messages "X rows affected" (meilleure intégration SSIS)
    SET ANSI_WARNINGS OFF;  -- masque "NULL éliminée..."
    /*
        Initialisation de la date de snapshot
        - Si aucune date n’est fournie, on utilise la date du jour
        - Permet un comportement déterministe et testable (rejeu possible)
    */
    IF @AsOfDate IS NULL
        SET @AsOfDate = CONVERT(date, GETDATE());

    -- Mode "lecture seulement"
    IF @Persist = 0
    BEGIN
        SELECT
            v.currency,
            v.series_key,
            @AsOfDate AS asof_date,
            v.tariff_rate,
            v.tariff_rate_window_days
        FROM dbo.vw_exchange_rate_series_tariff_rates v
        WHERE v.is_tariff_rate_available = 1
        SET ANSI_WARNINGS ON;
        RETURN;
    END
    /*
        Idempotence du chargement
        - Supprime le snapshot existant pour la date donnée
        - Garantit qu’une relance du job ne crée pas de doublons
    */
    DELETE FROM dbo.exchange_rates_tariff_monthly
    WHERE asof_date = @AsOfDate;
	WITH src AS
    (
            SELECT
                v.currency,
                v.series_key,
                @AsOfDate AS asof_date,
                v.tariff_rate,
                v.tariff_rate_window_days
            FROM dbo.vw_exchange_rate_series_tariff_rates v
            /*
                Filtrage métier :
                - On ne conserve que les séries disposant d’un taux tarifaire exploitable
            */
            WHERE v.is_tariff_rate_available = 1
    )
    /*
        Insertion du snapshot tarifaire mensuel
        - Source : vue métier consolidée
        - Chaque ligne représente le taux tarifaire "valide et stable"
          pour une série donnée à la date de référence
    */
    INSERT INTO dbo.exchange_rates_tariff_monthly
    (
        currency,
        series_key,
        asof_date,
        tariff_rate,
        tariff_rate_window_days
    )
    OUTPUT inserted.currency, inserted.series_key, inserted.asof_date, inserted.tariff_rate, inserted.tariff_rate_window_days
    SELECT currency, series_key, asof_date, tariff_rate, tariff_rate_window_days
    FROM src

    SET ANSI_WARNINGS ON;   -- on réactive pour éviter des effets de bord
END
