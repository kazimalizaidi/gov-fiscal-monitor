USE FiscalMonitor;
GO

CREATE VIEW dbo.vw_fiscal_quarterly AS
WITH ranked AS (
    SELECT fiscal_year, period_end, line_code, value_pkr_mn, pub_status,
           ROW_NUMBER() OVER (PARTITION BY fiscal_year, period_end, line_code
                              ORDER BY loaded_at DESC) AS rn
    FROM dbo.fiscal_cumulative
),
c AS (SELECT * FROM ranked WHERE rn = 1),
j AS (
    SELECT c.fiscal_year, c.period_end, c.line_code, c.pub_status,
           c.value_pkr_mn AS cumulative_pkr_mn,
           p.value_pkr_mn AS prev_cumulative_pkr_mn
    FROM c
    LEFT JOIN c p
      ON p.fiscal_year = c.fiscal_year
     AND p.line_code   = c.line_code
     AND p.period_end  = EOMONTH(c.period_end, -3)
)
SELECT fiscal_year, period_end, line_code, pub_status, cumulative_pkr_mn,
       CASE WHEN MONTH(period_end) = 9 THEN cumulative_pkr_mn
            WHEN prev_cumulative_pkr_mn IS NOT NULL
                 THEN cumulative_pkr_mn - prev_cumulative_pkr_mn
       END AS quarter_flow_pkr_mn
FROM j;
GO

SELECT period_end, line_code, cumulative_pkr_mn, quarter_flow_pkr_mn
FROM dbo.vw_fiscal_quarterly
WHERE line_code IN ('TOTAL_REVENUE', 'DEV_EXP_NET_LENDING')
ORDER BY line_code, period_end;