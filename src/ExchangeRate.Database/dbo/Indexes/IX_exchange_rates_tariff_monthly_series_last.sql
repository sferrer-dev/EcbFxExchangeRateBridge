/*
    Index destiné à optimiser l’accès
    au dernier taux tarifaire mensuel par série de devise.

    Objectifs :
    - Accélérer les requêtes recherchant le snapshot le plus récent (ORDER BY asof_date DESC)
      pour une series_key donnée
*/
CREATE INDEX IX_exchange_rates_tariff_monthly_series_last
ON dbo.exchange_rates_tariff_monthly
(
	[series_key],
	[asof_date] DESC
)
INCLUDE
(
	[tariff_rate],
	[tariff_rate_window_days]
);
