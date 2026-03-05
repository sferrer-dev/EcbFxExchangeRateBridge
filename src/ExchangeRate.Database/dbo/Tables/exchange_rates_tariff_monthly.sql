CREATE TABLE dbo.exchange_rates_tariff_monthly
(
    [rate_tariff_monthly_id]   INT           IDENTITY (1, 1) NOT NULL,
    [currency]                 NCHAR (3)     NOT NULL,
    [asof_date]                DATE          NOT NULL,  -- date du snapshot (ex: 2026-03-01)
    [series_key]               NVARCHAR(30)  NOT NULL,
    [tariff_rate]              DECIMAL(18,6) NULL,
    [tariff_rate_window_days]  INT           NULL,
    CONSTRAINT [PK_exchange_rates_tariff_monthly] PRIMARY KEY CLUSTERED ([asof_date], [currency]),
    CONSTRAINT [UQ_exchange_rate_tarrif] UNIQUE NONCLUSTERED ([currency] ASC, [series_key] ASC, [asof_date] ASC),
    CONSTRAINT [FK_exchange_rates_tariff_monthly_To_exchange_rates_series] FOREIGN KEY ([currency]) REFERENCES [exchange_rate_series]([currency])
);
