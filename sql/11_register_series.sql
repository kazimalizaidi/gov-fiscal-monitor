USE FiscalMonitor;
GO
-- Registers the SBP overnight repo rate series. Safe to re-run.
INSERT INTO dbo.dim_series (series_code, series_name, source, unit, frequency)
SELECT 'TS_GP_IR_REPOMR_D.ORR', 'Weighted-average Overnight Repo Rate', 'SBP', 'PERCENT', 'DAILY'
WHERE NOT EXISTS (SELECT 1 FROM dbo.dim_series WHERE series_code = 'TS_GP_IR_REPOMR_D.ORR');
GO
