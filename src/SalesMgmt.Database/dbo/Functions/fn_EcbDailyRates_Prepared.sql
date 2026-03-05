/* ============================================================
   Inline TVF : dataset préparatoire ECB -> SalesMgmt
   - Paramétrée (@FromDate, @ToDate)
   - Optimisable par l’optimiseur (inline = pas de table intermédiaire)
   - Réutilisable dans une SP MERGE/UPSERT ou en debug
   ============================================================ */
CREATE  FUNCTION dbo.fn_EcbDailyRates_Prepared
(
      @FromDate date
    , @ToDate   date
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        -- Clé interne SalesMgmt (référentiel devises)
        d.DEVID,
        -- Début de validité (conversion DATE -> DATETIME à 00:00:00)
        DVHDATEDEB = CAST(s.time_period AS datetime),
         -- Fin de validité : fin de journée (23:59:59.997) pour datetime
        DVHDATEFIN = DATEADD(millisecond, -3, DATEADD(day, 1, CAST(s.time_period AS datetime))),
         -- Taux (précision maîtrisée)
        DVHCOURS = CAST(s.obs_value AS numeric(18,12)),
        -- Taux inverse (sécurisé contre division par 0)
        DVHCOURSINV =
            CASE
                WHEN s.obs_value IS NULL OR s.obs_value = 0 THEN NULL
                ELSE CAST(1.0 / s.obs_value AS numeric(18,12))
            END,
         -- Traçabilité
        USRMODIF = SUSER_SNAME(),
       /* Champs “techniques” utiles pour contrôle/diagnostic (optionnel) */
        SourceCurrency   = RTRIM(s.currency),
        SourceTimePeriod = s.time_period
    FROM [$(ExchangeRatesDB)].dbo.exchange_rates_daily s
    INNER JOIN dbo.DEVISES d
        ON d.DEVSYMBOLE = RTRIM(s.currency)   -- currency est NCHAR(3) -> trim
    WHERE s.time_period >= @FromDate
      AND s.time_period <= @ToDate
      AND s.obs_value IS NOT NULL
);
