USE FiscalMonitor;
GO

ALTER VIEW dbo.vw_fiscal_flow_review AS
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
),
f AS (
    SELECT fiscal_year, period_end, line_code, flow AS quarter_flow_pkr_mn,
           CAST(mean_other AS DECIMAL(18,2)) AS mean_other_quarters,
           CAST(flow / NULLIF(mean_other, 0) AS DECIMAL(10,3)) AS ratio_to_others,
           CASE WHEN n_q = 4
                 AND (flow / NULLIF(mean_other, 0) > 2.0 OR flow / NULLIF(mean_other, 0) < 0.5)
                THEN 1 ELSE 0 END AS needs_review,
           CASE WHEN flow / NULLIF(mean_other, 0) > 1 THEN 'HIGH' ELSE 'LOW' END AS direction
    FROM r
)
SELECT f.*,
       CASE WHEN f.needs_review = 0 THEN NULL
            WHEN EXISTS (SELECT 1 FROM f g
                         WHERE g.line_code = f.line_code
                           AND MONTH(g.period_end) = MONTH(f.period_end)
                           AND g.fiscal_year <> f.fiscal_year
                           AND g.needs_review = 1
                           AND g.direction = f.direction) THEN 'RECURRING'
            ELSE 'ONE_OFF' END AS review_class
FROM f;
GO

SELECT fiscal_year, period_end, line_code, ratio_to_others, review_class
FROM dbo.vw_fiscal_flow_review
WHERE needs_review = 1
ORDER BY review_class DESC, line_code, period_end;