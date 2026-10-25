USE FiscalMonitor;
GO

CREATE VIEW dbo.vw_fiscal_flow_review AS
WITH q AS (
    SELECT fiscal_year, period_end, line_code, quarter_flow_pkr_mn AS flow
    FROM dbo.vw_fiscal_quarterly
    WHERE line_code IN ('TOTAL_REVENUE','TAX_REVENUE','TAX_FEDERAL','NONTAX_REVENUE',
                        'TOTAL_EXPENDITURE','CURRENT_EXPENDITURE','MARKUP_PAYMENTS',
                        'DEFENCE','DEV_EXP_NET_LENDING')
),
s AS (
    SELECT *,
           COUNT(flow) OVER (PARTITION BY fiscal_year, line_code) AS n_q,
           SUM(flow)   OVER (PARTITION BY fiscal_year, line_code) AS total_flow
    FROM q
),
r AS (
    SELECT *, (total_flow - flow) / NULLIF(n_q - 1, 0) AS mean_other
    FROM s
)
SELECT fiscal_year, period_end, line_code, flow AS quarter_flow_pkr_mn,
       CAST(mean_other AS DECIMAL(18,2)) AS mean_other_quarters,
       CAST(flow / NULLIF(mean_other, 0) AS DECIMAL(10,3)) AS ratio_to_others,
       CASE WHEN n_q = 4
             AND (flow / NULLIF(mean_other, 0) > 2.0 OR flow / NULLIF(mean_other, 0) < 0.5)
            THEN 1 ELSE 0 END AS needs_review
FROM r;
GO

SELECT fiscal_year, period_end, line_code, quarter_flow_pkr_mn, ratio_to_others
FROM dbo.vw_fiscal_flow_review
WHERE needs_review = 1
ORDER BY fiscal_year, line_code, period_end;