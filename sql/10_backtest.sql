USE FiscalMonitor;
GO

-- A. R1 against the ORIGINAL budget: would each threshold have flagged each quarter?
SELECT fiscal_year, period_end, pct_of_phased_target,
       CASE WHEN pct_of_phased_target < 85 THEN 1 ELSE 0 END AS flag_at_85,
       CASE WHEN pct_of_phased_target < 90 THEN 1 ELSE 0 END AS flag_at_90,
       CASE WHEN pct_of_phased_target < 95 THEN 1 ELSE 0 END AS flag_at_95,
       CASE WHEN pct_of_phased_target < 97 THEN 1 ELSE 0 END AS flag_at_97
FROM dbo.vw_r1_pace
WHERE target_type = 'BUDGET'
ORDER BY fiscal_year, period_end;

-- B. R2 to R4: how close did each come to firing? (margin = distance from the threshold)
SELECT m.fiscal_year, m.period_end,
       m.r2_dev_pct_of_prior,
       m.r2_dev_pct_of_prior - (SELECT warn_threshold FROM dbo.rule_def WHERE rule_code = 'R2_DEV_PACE') AS r2_margin,
       m.r3_burden_change_pp,
       (SELECT warn_threshold FROM dbo.rule_def WHERE rule_code = 'R3_INTEREST') - m.r3_burden_change_pp AS r3_margin,
       m.r4_primary_balance
FROM dbo.vw_rule_metrics m
WHERE m.r2_dev_pct_of_prior IS NOT NULL
ORDER BY m.fiscal_year, m.period_end;