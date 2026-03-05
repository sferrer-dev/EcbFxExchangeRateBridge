/*
    Index non clusterisé destiné à optimiser l’accès
    à la dernière observation valide par série de taux de change.
    Objectif :
    - Accélérer les requêtes recherchant la valeur la plus récente par series_key
    - Optimiser l’évaluation des vues métier de type "dernier taux connu"
*/
CREATE INDEX [IX_exchange_rates_daily_last_rate]
ON [dbo].[exchange_rates_daily]
(
    [series_key],
    [time_period] DESC
)
INCLUDE
(
    [obs_value],
    [obs_status]
);
