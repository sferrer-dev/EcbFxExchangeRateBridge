CREATE TABLE dbo.currency_ref
(
    currency_code  nchar(3)       NOT NULL,
    [currency_name] nvarchar(200)  NULL
    CONSTRAINT PK_currency_ref PRIMARY KEY (currency_code)
);
