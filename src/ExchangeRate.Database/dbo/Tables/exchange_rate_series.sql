CREATE TABLE [dbo].[exchange_rate_series] (
    [rate_series_id] INT            IDENTITY (1, 1) NOT NULL,
    [currency]       NCHAR(3)       NOT NULL,
    [series_key]     NVARCHAR(30)   NOT NULL,
    [is_active]      BIT            CONSTRAINT [DF_ref_exchange_rate_series_is_active] DEFAULT ((1)) NOT NULL,
    [date_create]    DATETIME2 (0)  CONSTRAINT [DF_ref_exchange_rate_series_date_create] DEFAULT (sysdatetime()) NOT NULL,
    [created_by]     [sysname]      NULL DEFAULT (SUSER_SNAME()),
    [comment]        NVARCHAR (200) NULL,
    CONSTRAINT [PK_exchange_rate_series] PRIMARY KEY CLUSTERED ([currency]),
    CONSTRAINT [UQ_exchange_rate_series] UNIQUE NONCLUSTERED ([currency] ASC, [series_key] ASC),
    CONSTRAINT [FK_exchange_rate_series_To_exchange_currency_series_ref] FOREIGN KEY ([currency]) REFERENCES [exchange_currency_series_ref]([currency])
);

