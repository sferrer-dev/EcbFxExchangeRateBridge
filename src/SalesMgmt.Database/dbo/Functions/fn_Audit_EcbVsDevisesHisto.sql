/* ============================================================
   Inline TVF : dataset tabulaire qui sert d’audit.
   - Compare les données de DEVISES_HISTO (cible) avec celles d’ExchangeRatesDB.dbo.exchange_rates_daily (source)
   - Ne doit prendre en compte que les devises actives référencées dans DEVISES
   - Il existe des taux de change dans la source qui n’ont pas de correspondant dans la cible
       car ils concernent des devises non référencées dans DEVISES (faux MISSING_IN_TARGET)
   - Status indiquant immédiatement ce qui est bon vs anomalie
       permet d’identifier les écarts (missing, extra, mismatch) et les lignes OK
   - Paramétrée (@FromDate, @ToDate)
   - Ne modifie aucune donnée
   ============================================================ */
CREATE FUNCTION dbo.fn_Audit_EcbVsDevisesHisto
(
    @FromDate date,
    @ToDate   date
)
RETURNS TABLE
AS
RETURN
(
    WITH Dev AS
    (
        SELECT DISTINCT DevSymbole = RTRIM(d.DEVSYMBOLE) 
        FROM dbo.DEVISES d 
        WHERE DEVISACTIVE = 'O' 
          AND DEVISREFERENCE = 'N'
    ),
    Src AS
    (
        SELECT
            Currency   = RTRIM(s.currency),  -- currency est NCHAR(3) => trim
            RateDateDt = CAST(s.time_period AS datetime), -- 00:00:00 en datetime
            SourceValue = s.obs_value
        FROM [$(ExchangeRatesDB)].dbo.exchange_rates_daily s
        INNER JOIN Dev -- filtrer la source pour ne prendre que les devises actives référencées dans DEVISES
            ON Dev.DevSymbole = RTRIM(s.currency)
        WHERE s.time_period >= @FromDate
          AND s.time_period <= @ToDate
          AND s.obs_value IS NOT NULL
    ),
    Tgt AS
    (
        SELECT
            dev.DEVSYMBOLE,
            d.DEVID,
            d.DVHID,
            d.DVHDATEDEB,      -- datetime à 00:00:00
            d.DVHCOURS
        FROM dbo.DEVISES_HISTO d
        INNER JOIN dbo.DEVISES dev
            ON dev.DEVID = d.DEVID
        WHERE d.DVHDATEDEB >= CAST(@FromDate AS datetime)
          AND d.DVHDATEDEB <  DATEADD(day, 1, CAST(@ToDate AS datetime)) -- borne haute exclusive
    )
    SELECT
    Status =
        CASE
            WHEN Tgt.DVHID IS NULL THEN 'MISSING_IN_TARGET'          -- ligne source absente en cible
            WHEN Src.Currency IS NULL THEN 'EXTRA_IN_TARGET'         -- ligne cible sans correspondant source
            WHEN Tgt.DVHCOURS <> Src.SourceValue THEN 'VALUE_MISMATCH'
            ELSE 'OK'
        END,
    Currency     = COALESCE(Tgt.DEVSYMBOLE, Src.Currency),
    RateDate     = COALESCE(Tgt.DVHDATEDEB, Src.RateDateDt),
    SourceValue  = Src.SourceValue,
    TargetValue  = Tgt.DVHCOURS,
    TargetId     = Tgt.DVHID
FROM Src
FULL OUTER JOIN Tgt
    ON  Tgt.DEVSYMBOLE = Src.Currency
    AND Tgt.DVHDATEDEB = Src.RateDateDt
);
