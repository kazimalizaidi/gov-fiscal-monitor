USE FiscalMonitor;
GO

CREATE TABLE dbo.rule_def (
    rule_code          VARCHAR(30)  PRIMARY KEY,
    description        VARCHAR(200) NOT NULL,
    direction          VARCHAR(5)   NOT NULL CHECK (direction IN ('BELOW','ABOVE')),
    warn_threshold     DECIMAL(10,2) NOT NULL,
    critical_threshold DECIMAL(10,2) NULL
);

INSERT INTO dbo.rule_def VALUES
('R1_REV_PACE',  'Federal tax as % of annual target phased by last year''s cumulative share', 'BELOW', 95, 90),
('R2_DEV_PACE',  'Cumulative development spending as % of same period last year',            'BELOW', 90, NULL),
('R3_INTEREST',  'Mark-up as % of revenue: change vs same period last year, in points',      'ABOVE',  5, NULL),
('R4_PRIM_BAL',  'Primary balance negative after positive in same period last year',         'BELOW',  0, NULL);
GO

CREATE VIEW dbo.vw_r1_pace AS
WITH fed AS (
    SELECT fiscal_year, period_end, MONTH(period_end) AS m, cumulative_pkr_mn AS v
    FROM dbo.vw_fiscal_quarterly WHERE line_code = 'TAX_FEDERAL'
)
SELECT cur.fiscal_year, cur.period_end, t.target_type, t.target_pkr_mn,
       cur.v AS actual_pkr_mn,
       CAST(100.0 * prv.v / NULLIF(prvfy.v, 0) AS DECIMAL(8,3)) AS prior_year_share_pct,
       CAST(100.0 * cur.v / NULLIF(CAST(t.target_pkr_mn AS FLOAT) * prv.v / NULLIF(prvfy.v, 0), 0)
            AS DECIMAL(8,2)) AS pct_of_phased_target
FROM fed cur
JOIN dbo.fiscal_target t ON t.fiscal_year = cur.fiscal_year AND t.compare_to_line = 'TAX_FEDERAL'
JOIN fed prv   ON prv.fiscal_year   = cur.fiscal_year - 1 AND prv.m   = cur.m
JOIN fed prvfy ON prvfy.fiscal_year = cur.fiscal_year - 1 AND prvfy.m = 6;
GO

CREATE VIEW dbo.vw_rule_metrics AS
WITH c AS (
    SELECT fiscal_year, period_end, MONTH(period_end) AS m, line_code, cumulative_pkr_mn AS v
    FROM dbo.vw_fiscal_quarterly
),
w AS (
    SELECT fiscal_year, period_end, m,
           MAX(CASE WHEN line_code = 'DEV_EXP_NET_LENDING' THEN v END) AS dev,
           MAX(CASE WHEN line_code = 'MARKUP_PAYMENTS'     THEN v END) AS markup,
           MAX(CASE WHEN line_code = 'TOTAL_REVENUE'       THEN v END) AS revenue,
           MAX(CASE WHEN line_code = 'PRIMARY_BALANCE'     THEN v END) AS prim
    FROM c GROUP BY fiscal_year, period_end, m
)
SELECT cur.fiscal_year, cur.period_end,
       CAST(100.0 * cur.dev / NULLIF(prv.dev, 0) AS DECIMAL(10,2)) AS r2_dev_pct_of_prior,
       CAST(100.0 * cur.markup / NULLIF(cur.revenue, 0)
          - 100.0 * prv.markup / NULLIF(prv.revenue, 0) AS DECIMAL(10,2)) AS r3_burden_change_pp,
       cur.prim AS r4_primary_balance,
       prv.prim AS r4_prior_primary_balance
FROM w cur
LEFT JOIN w prv ON prv.fiscal_year = cur.fiscal_year - 1 AND prv.m = cur.m;
GO

CREATE VIEW dbo.vw_fiscal_flags AS
WITH x AS (
    SELECT p.fiscal_year, p.period_end, 'R1_REV_PACE' AS rule_code,
           CAST(p.target_type AS VARCHAR(10)) AS variant,
           p.pct_of_phased_target AS metric_value, d.warn_threshold, d.critical_threshold,
           CASE WHEN d.critical_threshold IS NOT NULL AND p.pct_of_phased_target < d.critical_threshold THEN 'CRITICAL'
                WHEN p.pct_of_phased_target < d.warn_threshold THEN 'WARN' END AS severity
    FROM dbo.vw_r1_pace p JOIN dbo.rule_def d ON d.rule_code = 'R1_REV_PACE'
  UNION ALL
    SELECT m.fiscal_year, m.period_end, 'R2_DEV_PACE', CAST(NULL AS VARCHAR(10)),
           m.r2_dev_pct_of_prior, d.warn_threshold, d.critical_threshold,
           CASE WHEN d.critical_threshold IS NOT NULL AND m.r2_dev_pct_of_prior < d.critical_threshold THEN 'CRITICAL'
                WHEN m.r2_dev_pct_of_prior < d.warn_threshold THEN 'WARN' END
    FROM dbo.vw_rule_metrics m JOIN dbo.rule_def d ON d.rule_code = 'R2_DEV_PACE'
  UNION ALL
    SELECT m.fiscal_year, m.period_end, 'R3_INTEREST', CAST(NULL AS VARCHAR(10)),
           m.r3_burden_change_pp, d.warn_threshold, d.critical_threshold,
           CASE WHEN d.critical_threshold IS NOT NULL AND m.r3_burden_change_pp > d.critical_threshold THEN 'CRITICAL'
                WHEN m.r3_burden_change_pp > d.warn_threshold THEN 'WARN' END
    FROM dbo.vw_rule_metrics m JOIN dbo.rule_def d ON d.rule_code = 'R3_INTEREST'
  UNION ALL
    SELECT m.fiscal_year, m.period_end, 'R4_PRIM_BAL', CAST(NULL AS VARCHAR(10)),
           CAST(m.r4_primary_balance AS DECIMAL(18,2)), d.warn_threshold, d.critical_threshold,
           CASE WHEN m.r4_prior_primary_balance > 0 AND m.r4_primary_balance < d.warn_threshold THEN 'WARN' END
    FROM dbo.vw_rule_metrics m JOIN dbo.rule_def d ON d.rule_code = 'R4_PRIM_BAL'
)
SELECT * FROM x WHERE severity IS NOT NULL;
GO

SELECT fiscal_year, period_end, target_type, prior_year_share_pct, pct_of_phased_target
FROM dbo.vw_r1_pace ORDER BY target_type, period_end;

SELECT fiscal_year, period_end, rule_code, variant, metric_value, severity
FROM dbo.vw_fiscal_flags ORDER BY rule_code, period_end;