/*
    Initialisation (seed) des séries de taux de change dans
    la table de paramétrage dbo.exchange_rate_series.

    Cette procédure insère ou met à jour un ensemble prédéfini
    de séries ECB utilisées par le système.

    Elle est idempotente :
    - Si une série n'existe pas → INSERT
    - Si une série existe déjà → UPDATE de l’état is_active
    - Elle peut être exécutée plusieurs fois sans créer de doublons.
    - Clé logique : (series_key, currency)
*/
CREATE PROCEDURE dbo.usp_SeedExchangeRateSeries
AS
BEGIN

    SET NOCOUNT ON;

    PRINT 'Seeding dbo.exchange_rate_series...';

    /*
        Synchronisation des données via MERGE (UPSERT set-based)
        target = table cible persistée
        source = jeu de valeurs statique défini inline
        Logique :
            - Si correspondance trouvée → UPDATE
            - Sinon → INSERT
    */
    MERGE dbo.exchange_rate_series AS target
    -- Définition du jeu de données source (table virtuelle)
    USING (VALUES
        (N'EXR.D.CNY.EUR.SP00.A', N'CNY', 1),
        (N'EXR.D.GBP.EUR.SP00.A', N'GBP', 0),
        (N'EXR.D.USD.EUR.SP00.A', N'USD', 1)
    ) AS source (series_key, currency, is_active)
    /*
        Condition de correspondance métier :
        Une ligne est considérée identique si
        - même series_key
        - même currency
    */
    ON target.series_key = source.series_key
        AND target.currency = source.currency
    -- Cas 1 : aucune ligne correspondante → insertion
    WHEN NOT MATCHED THEN
        INSERT (series_key, currency, is_active, comment)
        VALUES (source.series_key, source.currency, source.is_active, 'Default configuration')
    -- Cas 2 : ligne existante → mise à jour de l’état
    WHEN MATCHED THEN
        UPDATE SET
            is_active = target.is_active; -- Ne pas écraser l’état existant (is_active = is_active)

    PRINT 'Seed completed.';

END;