CREATE TABLE [dbo].[exchange_currency_series_ref]
(
    [currency] NCHAR(3)         NOT NULL,
    [series_key] NVARCHAR(30)   NOT NULL,
    [title] NVARCHAR(200)       NOT NULL,
    [title_compl] NVARCHAR(300) NOT NULL,
    CONSTRAINT [PK_exchange_currency_series_ref] PRIMARY KEY ([currency]),
    CONSTRAINT [CK_exchange_currency_series_ref_currency] CHECK ([currency] LIKE N'[A-Z][A-Z][A-Z]'),
    CONSTRAINT [UQ_exchange_currency_series_ref] UNIQUE NONCLUSTERED ([currency] ASC, [series_key] ASC)
);
