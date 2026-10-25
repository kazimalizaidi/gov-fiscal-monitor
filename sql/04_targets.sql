USE FiscalMonitor;
GO

DROP TABLE dbo.fiscal_target;
GO

CREATE TABLE dbo.fiscal_target (
    fiscal_year     INT           NOT NULL,   -- 2026 = FY2025-26
    indicator       VARCHAR(40)   NOT NULL,   -- e.g. FBR_TAXES
    target_type     VARCHAR(10)   NOT NULL,   -- BUDGET / REVISED
    target_pkr_mn   DECIMAL(18,2) NOT NULL,
    scope           VARCHAR(20)   NOT NULL,   -- FEDERAL (the budget covers the federal government only)
    compare_to_line VARCHAR(40)   NOT NULL REFERENCES dbo.dim_fiscal_line(line_code),
    source_doc      VARCHAR(200)  NOT NULL,
    source_ref      VARCHAR(100)  NOT NULL,
    notes           VARCHAR(300)  NULL,
    CONSTRAINT PK_fiscal_target PRIMARY KEY (fiscal_year, indicator, target_type),
    CONSTRAINT CK_fiscal_target_type CHECK (target_type IN ('BUDGET', 'REVISED'))
);
GO

INSERT INTO dbo.fiscal_target
    (fiscal_year, indicator, target_type, target_pkr_mn, scope, compare_to_line, source_doc, source_ref, notes)
VALUES
(2026, 'FBR_TAXES', 'BUDGET',  14131000, 'FEDERAL', 'TAX_FEDERAL',
 'Budget_in_Brief.pdf (Federal Budget 2026-27)', 'Table 4, Budget 2025-26 column',
 'FBR taxes vs Table 1 federal tax: definitions not verified to be identical'),
(2026, 'FBR_TAXES', 'REVISED', 12983000, 'FEDERAL', 'TAX_FEDERAL',
 'Budget_in_Brief.pdf (Federal Budget 2026-27)', 'Table 4, Revised 2025-26 column',
 'Revised estimate based on actual projections, per the document');
GO

SELECT t.target_type, t.target_pkr_mn, c.cumulative_pkr_mn AS actual_pkr_mn,
       CAST(100.0 * c.cumulative_pkr_mn / t.target_pkr_mn AS DECIMAL(6,2)) AS pct_of_target
FROM dbo.fiscal_target t
JOIN dbo.vw_fiscal_quarterly c
  ON c.fiscal_year = t.fiscal_year AND c.line_code = t.compare_to_line
 AND c.period_end = '2026-06-30'
ORDER BY t.target_type;