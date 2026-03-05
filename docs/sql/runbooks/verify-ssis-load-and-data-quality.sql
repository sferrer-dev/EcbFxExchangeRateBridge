/*
===============================================================================
Runbook SQL – Contrôles post-exécution SSIS (ECB FX → ExchangeRatesDB → SalesMgmtDB)
Objectif :
- Vérifier la cohérence des données ingérées (ExchangeRatesDB)
- Comparer les valeurs exposées/ciblées (SalesMgmtDB)
- Détecter rapidement des anomalies (audit DEVISES_HISTO vs BCE)

Bonnes pratiques intégrées :
- Paramétrage des dates
- Résultats “actionnables” (TOP, ORDER BY, comptages)
- Messages de log (PRINT/RAISERROR)
- Regroupement logique par sections
===============================================================================
*/

SET NOCOUNT ON;

-------------------------------------------------------------------------------
-- 0) Paramètres d’exécution
-------------------------------------------------------------------------------
DECLARE @LookbackYears int  = 5;
DECLARE @FromDate      date = DATEADD(year, -@LookbackYears, CONVERT(date, GETDATE()));
DECLARE @ToDate        date = CONVERT(date, GETDATE());

PRINT '=== SSIS Post-Run Checks ===';
PRINT 'Date range for audit: ' + CONVERT(varchar(10), @FromDate, 120)
    + ' -> ' + CONVERT(varchar(10), @ToDate, 120);
PRINT 'LookbackYears: ' + CAST(@LookbackYears AS varchar(10));
PRINT 'Timestamp: ' + CONVERT(varchar(19), SYSDATETIME(), 120);

-------------------------------------------------------------------------------
-- 1) Synthèse : vues “monitoring” / “health”
-------------------------------------------------------------------------------
PRINT '--- [1] Daily summary (ExchangeRatesDB) ---';

SELECT *
FROM [ExchangeRatesDB].[dbo].[vw_exchange_rate_series_daily_summary]
ORDER BY currency;

-------------------------------------------------------------------------------
-- 2) Dernier taux par série : ExchangeRatesDB vs SalesMgmtDB
-------------------------------------------------------------------------------
PRINT '--- [2] Last rate comparison ---';

-- 2.1 Source technique (ExchangeRatesDB)
SELECT *
FROM [ExchangeRatesDB].[dbo].[vw_exchange_rate_series_last_rate]
ORDER BY currency;

-- 2.2 Cible métier (SalesMgmtDB)
SELECT *
FROM [SalesMgmtDB].[dbo].[vw_devises_last_rate]
ORDER BY DEVSYMBOLE ;

-------------------------------------------------------------------------------
-- 3) Taux stables (30/60/90j) : ExchangeRatesDB vs SalesMgmtDB
-------------------------------------------------------------------------------
PRINT '--- [3] Stable rates comparison ---';

SELECT *
FROM [ExchangeRatesDB].[dbo].[vw_exchange_rate_series_stable_rates]
ORDER BY currency;

SELECT *
FROM [SalesMgmtDB].[dbo].[vw_devises_stable_rates]
ORDER BY DEVSYMBOLE;

-------------------------------------------------------------------------------
-- 4) Taux tarifaires : ExchangeRatesDB vs SalesMgmtDB
-------------------------------------------------------------------------------
PRINT '--- [4] Tariff rates comparison ---';

SELECT *
FROM [ExchangeRatesDB].[dbo].[vw_exchange_rate_series_tariff_rates]
ORDER BY currency;

SELECT *
FROM [SalesMgmtDB].[dbo].[vw_devises_tariff_rates]
ORDER BY DEVSYMBOLE;

-------------------------------------------------------------------------------
-- 5) Audit : DEVISES_HISTO (SalesMgmtDB) vs taux BCE
-------------------------------------------------------------------------------
PRINT '--- [5] Audit DEVISES_HISTO vs ECB ---';

DECLARE @ErrorCount int;

SELECT @ErrorCount = COUNT_BIG(1)
FROM [SalesMgmtDB].[dbo].[fn_Audit_EcbVsDevisesHisto](@FromDate, @ToDate)
WHERE Status <> 'OK';

PRINT 'Audit anomalies (Status <> OK): ' + CAST(@ErrorCount AS varchar(20));

-- Vue synthèse par type d’anomalie + devise
SELECT
    Status,
    Currency,
    COUNT(1) AS anomaly_count,
    MIN(RateDate) AS first_rate_date,
    MAX(RateDate) AS last_rate_date
FROM [SalesMgmtDB].[dbo].[fn_Audit_EcbVsDevisesHisto](@FromDate, @ToDate)
WHERE Status <> 'OK'
GROUP BY Status, Currency
ORDER BY anomaly_count DESC, Currency;

-- Détails : top N anomalies les plus récentes
SELECT TOP (50) *
FROM [SalesMgmtDB].[dbo].[fn_Audit_EcbVsDevisesHisto](@FromDate, @ToDate)
WHERE Status <> 'OK'
ORDER BY RateDate DESC, Currency;

-- Signal fort dans le flux d’exécution
IF (@ErrorCount > 0)
BEGIN
    RAISERROR('WARNING: Audit detected %d anomalies (Status <> OK). Review the result sets above.', 10, 1, @ErrorCount);
END
ELSE
BEGIN
    PRINT 'OK: No anomalies detected by fn_Audit_EcbVsDevisesHisto for the selected period.';
END

PRINT '=== End of checks ===';