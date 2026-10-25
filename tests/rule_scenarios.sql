USE FiscalMonitor;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;

INSERT INTO dbo.etl_run_log (pipeline) VALUES ('TEST:rule_scenarios');
DECLARE @run INT = SCOPE_IDENTITY();

INSERT INTO dbo.fiscal_cumulative
    (fiscal_year, period_end, line_code, value_pkr_mn, pub_status, source_file, run_id)
VALUES
-- "prior year" (2098): healthy baseline
(2098, '2097-09-30', 'DEV_EXP_NET_LENDING', 100, 'TEST', 'scenario', @run),
(2098, '2097-09-30', 'MARKUP_PAYMENTS',      30, 'TEST', 'scenario', @run),
(2098, '2097-09-30', 'TOTAL_REVENUE',       300, 'TEST', 'scenario', @run),
(2098, '2097-09-30', 'PRIMARY_BALANCE',      50, 'TEST', 'scenario', @run),
(2098, '2097-09-30', 'TAX_FEDERAL',          20, 'TEST', 'scenario', @run),
(2098, '2098-06-30', 'TAX_FEDERAL',         100, 'TEST', 'scenario', @run),
-- "current year" (2099): stressed
(2099, '2098-09-30', 'DEV_EXP_NET_LENDING',  80, 'TEST', 'scenario', @run),
(2099, '2098-09-30', 'MARKUP_PAYMENTS',      60, 'TEST', 'scenario', @run),
(2099, '2098-09-30', 'TOTAL_REVENUE',       300, 'TEST', 'scenario', @run),
(2099, '2098-09-30', 'PRIMARY_BALANCE',     -10, 'TEST', 'scenario', @run),
(2099, '2098-09-30', 'TAX_FEDERAL',         150, 'TEST', 'scenario', @run);

INSERT INTO dbo.fiscal_target
    (fiscal_year, indicator, target_type, target_pkr_mn, scope, compare_to_line, source_doc, source_ref)
VALUES (2099, 'TEST', 'BUDGET', 1000, 'FEDERAL', 'TAX_FEDERAL', 'scenario', 'scenario');

SELECT rule_code, variant, metric_value, severity
FROM dbo.vw_fiscal_flags
WHERE fiscal_year = 2099
ORDER BY rule_code;

ROLLBACK TRANSACTION;
GO

SELECT (SELECT COUNT(*) FROM dbo.fiscal_cumulative WHERE fiscal_year >= 2098) AS leftover_facts,
       (SELECT COUNT(*) FROM dbo.fiscal_target     WHERE fiscal_year >= 2098) AS leftover_targets;