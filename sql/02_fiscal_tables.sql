USE FiscalMonitor;
GO

DROP TABLE dbo.fiscal_actual;
GO

CREATE TABLE dbo.dim_fiscal_line (
    line_code   VARCHAR(40)  PRIMARY KEY,
    line_label  VARCHAR(120) NOT NULL,
    parent_code VARCHAR(40)  NULL REFERENCES dbo.dim_fiscal_line(line_code),
    section     VARCHAR(20)  NOT NULL   -- REVENUE / EXPENDITURE / BALANCE / FINANCING
);

CREATE TABLE dbo.fiscal_cumulative (
    fiscal_year  INT           NOT NULL,   -- 2026 = FY2025-26
    period_end   DATE          NOT NULL,   -- 2025-09-30, 2025-12-31, ...
    line_code    VARCHAR(40)   NOT NULL REFERENCES dbo.dim_fiscal_line(line_code),
    value_pkr_mn DECIMAL(18,2) NOT NULL,   -- cumulative from 1 July, as published
    pub_status   VARCHAR(15)   NOT NULL,   -- PROVISIONAL / FINAL
    source_file  VARCHAR(200)  NOT NULL,
    run_id       INT           NOT NULL REFERENCES dbo.etl_run_log(run_id),
    loaded_at    DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_fiscal_cumulative PRIMARY KEY (fiscal_year, period_end, line_code, loaded_at)
);
GO

INSERT INTO dbo.dim_fiscal_line (line_code, line_label, parent_code, section) VALUES
('TOTAL_REVENUE',      'Total Revenue',                       NULL,                  'REVENUE'),
('TAX_REVENUE',        'Tax Revenue',                         'TOTAL_REVENUE',       'REVENUE'),
('TAX_FEDERAL',        'Tax Revenue - Federal',               'TAX_REVENUE',         'REVENUE'),
('TAX_PROVINCIAL',     'Tax Revenue - Provincial',            'TAX_REVENUE',         'REVENUE'),
('NONTAX_REVENUE',     'Non-Tax Revenue',                     'TOTAL_REVENUE',       'REVENUE'),
('NONTAX_FEDERAL',     'Non-Tax Revenue - Federal',           'NONTAX_REVENUE',      'REVENUE'),
('NONTAX_PROVINCIAL',  'Non-Tax Revenue - Provincial',        'NONTAX_REVENUE',      'REVENUE'),
('TOTAL_EXPENDITURE',  'Total Expenditure',                   NULL,                  'EXPENDITURE'),
('CURRENT_EXPENDITURE','Current Expenditure',                 'TOTAL_EXPENDITURE',   'EXPENDITURE'),
('MARKUP_PAYMENTS',    'Of which: Mark-up Payments',          'CURRENT_EXPENDITURE', 'EXPENDITURE'),
('DEFENCE',            'Of which: Defence',                   'CURRENT_EXPENDITURE', 'EXPENDITURE'),
('DEV_EXP_NET_LENDING','Development Expenditure & net lending','TOTAL_EXPENDITURE',  'EXPENDITURE'),
('STAT_DISCREPANCY',   'Statistical Discrepancy',             'TOTAL_EXPENDITURE',   'EXPENDITURE'),
('OVERALL_BALANCE',    'Overall Budget Balance',              NULL,                  'BALANCE'),
('PRIMARY_BALANCE',    'Primary Balance',                     NULL,                  'BALANCE'),
('FINANCING_TOTAL',    'Financing',                           NULL,                  'FINANCING'),
('FIN_EXTERNAL',       'Financing - External (Net)',          'FINANCING_TOTAL',     'FINANCING'),
('FIN_DOMESTIC',       'Financing - Domestic (Net)',          'FINANCING_TOTAL',     'FINANCING'),
('FIN_NONBANK',        'Domestic - Non-Bank',                 'FIN_DOMESTIC',        'FINANCING'),
('FIN_BANK',           'Domestic - Bank',                     'FIN_DOMESTIC',        'FINANCING'),
('FIN_PRIVATIZATION',  'Domestic - Privatization Proceeds',   'FIN_DOMESTIC',        'FINANCING');
GO

SELECT COUNT(*) AS lines FROM dbo.dim_fiscal_line;