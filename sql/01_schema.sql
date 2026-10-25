USE FiscalMonitor;
GO

CREATE TABLE dbo.etl_run_log (
    run_id        INT IDENTITY(1,1) PRIMARY KEY,
    pipeline      VARCHAR(50)  NOT NULL,
    started_at    DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME(),
    finished_at   DATETIME2    NULL,
    status        VARCHAR(20)  NOT NULL DEFAULT 'RUNNING',  -- RUNNING / SUCCESS / FAILED
    rows_loaded   INT          NULL,
    error_message NVARCHAR(2000) NULL
);

CREATE TABLE dbo.dim_series (
    series_code VARCHAR(50)  PRIMARY KEY,
    series_name VARCHAR(200) NOT NULL,
    source      VARCHAR(50)  NOT NULL,   -- SBP / MoF / FBR
    unit        VARCHAR(30)  NOT NULL,   -- e.g. PKR_MN, PERCENT
    frequency   VARCHAR(10)  NOT NULL    -- DAILY / WEEKLY / MONTHLY
);

CREATE TABLE dbo.market_observation (
    series_code VARCHAR(50)    NOT NULL REFERENCES dbo.dim_series(series_code),
    obs_date    DATE           NOT NULL,
    value       DECIMAL(18,6)  NOT NULL,
    run_id      INT            NOT NULL REFERENCES dbo.etl_run_log(run_id),
    loaded_at   DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_market_observation PRIMARY KEY (series_code, obs_date, loaded_at)
);

CREATE TABLE dbo.fiscal_actual (
    period_month  DATE          NOT NULL,   -- first day of month
    indicator     VARCHAR(60)   NOT NULL,   -- e.g. FBR_COLLECTION, DEV_EXPENDITURE
    value_pkr_mn  DECIMAL(18,2) NOT NULL,
    source        VARCHAR(50)   NOT NULL,
    run_id        INT           NOT NULL REFERENCES dbo.etl_run_log(run_id),
    loaded_at     DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    is_current    BIT           NOT NULL DEFAULT 1,
    CONSTRAINT PK_fiscal_actual PRIMARY KEY (period_month, indicator, loaded_at)
);

CREATE TABLE dbo.fiscal_target (
    fiscal_year   INT           NOT NULL,   -- e.g. 2026 for FY2025-26
    indicator     VARCHAR(60)   NOT NULL,
    target_pkr_mn DECIMAL(18,2) NOT NULL,
    CONSTRAINT PK_fiscal_target PRIMARY KEY (fiscal_year, indicator)
);

CREATE TABLE dbo.flag (
    flag_id      INT IDENTITY(1,1) PRIMARY KEY,
    period_month DATE          NOT NULL,
    rule_code    VARCHAR(50)   NOT NULL,
    severity     VARCHAR(10)   NOT NULL,   -- WARN / CRITICAL
    metric_value DECIMAL(18,4) NOT NULL,
    threshold    DECIMAL(18,4) NOT NULL,
    raised_at    DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES ORDER BY TABLE_NAME;